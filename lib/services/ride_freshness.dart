import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Rides older than this — measured from the most recent of `acceptedAt` or
/// `timestamp` — are treated as stale and auto-cancelled on read. Prevents a
/// crashed/abandoned trip from haunting every subsequent app launch.
const Duration kRideStaleAfter = Duration(hours: 12);

/// Returns true if the ride is stale (older than [kRideStaleAfter]) OR has a
/// terminal status. The caller should skip rendering / tracking it.
///
/// Side effect: when a non-terminal ride is found to be stale, fires a
/// best-effort write to mark it `cancelled` in Firebase so neither side will
/// load it again. Errors are swallowed — staleness detection must never
/// itself crash the app, that's the entire point of this module.
bool isRideStaleAndCleanup(String rideKey, Map<String, dynamic> ride) {
  final status = ride['status']?.toString();
  if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
    return true;
  }

  final mostRecent = _mostRecentTimestampMs(ride);
  if (mostRecent == null) {
    // No timestamp at all — legacy data. Treat as stale to flush it out.
    _markCancelled(rideKey, reason: 'no_timestamp');
    return true;
  }

  final age = DateTime.now().millisecondsSinceEpoch - mostRecent;
  if (age > kRideStaleAfter.inMilliseconds) {
    _markCancelled(rideKey, reason: 'expired');
    return true;
  }
  return false;
}

int? _mostRecentTimestampMs(Map<String, dynamic> ride) {
  int? best;
  for (final key in const ['acceptedAt', 'timestamp']) {
    final v = ride[key];
    if (v is int && (best == null || v > best)) best = v;
    if (v is num && (best == null || v.toInt() > best)) best = v.toInt();
  }
  return best;
}

void _markCancelled(String rideKey, {required String reason}) {
  FirebaseDatabase.instance
      .ref('ride_requests')
      .child(rideKey)
      .update({
    'status': 'cancelled',
    'cancelReason': 'auto_$reason',
    'cancelledAt': DateTime.now().millisecondsSinceEpoch,
  }).catchError((e) {
    debugPrint('Stale ride cleanup write failed for $rideKey: $e');
  });
}
