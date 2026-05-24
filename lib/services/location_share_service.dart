import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import 'background_location_handler.dart';

enum SharingRole { driver, passenger }

/// UI-side controller for the foreground location-sharing service.
///
/// All work is delegated to the background isolate spawned by
/// `flutter_background_service` so location keeps streaming when the app is
/// minimised or the screen is locked. From the UI's perspective this class
/// is just `start()` / `stop()`.
class LocationShareService {
  LocationShareService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static String? _activeUid;
  static SharingRole? _activeRole;
  static String? _activeRequestId;

  static String? get activeUid => _activeUid;
  static SharingRole? get activeRole => _activeRole;
  static String? get activeRequestId => _activeRequestId;

  /// Returns true if a location stream is currently being published.
  static bool get isSharing => _activeUid != null;

  /// Begin publishing this user's location to RTDB. Idempotent — calling with
  /// the same (uid, role) twice is a no-op.
  ///
  /// Returns true if sharing started (or was already running), false if the
  /// user denied permission. Never throws.
  static Future<bool> start({
    required String uid,
    required SharingRole role,
    String? requestId,
  }) async {
    if (kIsWeb) return false;
    if (_activeUid == uid &&
        _activeRole == role &&
        _activeRequestId == requestId) {
      return true;
    }

    final granted = await _ensureForegroundPermission();
    if (!granted) return false;

    // Permissions (notification + background location) are intentionally NOT
    // requested here. They're requested upfront from the splash screen so
    // the ride-confirm flow never triggers a system dialog — re-prompting
    // here caused crashes on Android 14 due to stale Activity context.

    _activeUid = uid;
    _activeRole = role;
    _activeRequestId = requestId;

    // The foreground-service path was permanently disabled because the
    // CannotPostForegroundServiceNotificationException ("Bad notification
    // for startForeground") on Android 13+ is a system-level kill that
    // cannot be caught in Dart, and reliably reproducing a clean
    // notification icon across all OEMs proved fragile. Live location now
    // flows through UI-isolate position streams in driver_screen.dart and
    // passenger_screen.dart, which write directly to RTDB while the app is
    // foregrounded. Background tracking (app minimised / screen off) is
    // gone as a tradeoff — fine for active-use ride flows.
    //
    // We still mark _active* so the UI-side knows what node + ride to
    // publish to. The actual RTDB writes are the caller's responsibility.
    return true;
  }

  /// True when the UI side should be publishing GPS to RTDB. Read by the
  /// position-stream listeners in driver_screen / passenger_screen.
  static bool get shouldPublish => _activeUid != null && _activeRole != null;

  /// RTDB node for the current active sharing session, or null.
  static String? get activeNode {
    if (_activeRole == null) return null;
    return _activeRole == SharingRole.driver
        ? 'drivers_location'
        : 'passengers_location';
  }

  /// Like [stop], but also removes the *other* party's location node — used
  /// when a ride reaches a terminal state so a force-killed counterparty
  /// doesn't leave a phantom marker visible to the next ride. Both removes
  /// are best-effort; one side will succeed even if the other fails.
  static Future<void> stopAndCleanupBoth({
    String? driverUid,
    String? passengerUid,
  }) async {
    await stop();
    final db = FirebaseDatabase.instance;
    if (driverUid != null && driverUid.isNotEmpty) {
      try {
        await db.ref('drivers_location').child(driverUid).remove();
      } catch (_) {}
    }
    if (passengerUid != null && passengerUid.isNotEmpty) {
      try {
        await db.ref('passengers_location').child(passengerUid).remove();
      } catch (_) {}
    }
  }

  /// Stop publishing. Removes the user's RTDB location node so the other
  /// party's marker disappears, then stops the foreground service.
  static Future<void> stop() async {
    final uid = _activeUid;
    final role = _activeRole;
    _activeUid = null;
    _activeRole = null;
    _activeRequestId = null;

    _service.invoke(LocationShareChannels.stopForeground);

    if (uid != null) {
      // Belt-and-braces cleanup from the UI isolate as well — the background
      // isolate also tries this on `stop`, but it may already have been
      // killed by the OS.
      try {
        if (role != null) {
          final node = role == SharingRole.driver
              ? 'drivers_location'
              : 'passengers_location';
          await FirebaseDatabase.instance.ref(node).child(uid).remove();
        } else {
          await FirebaseDatabase.instance
              .ref('drivers_location')
              .child(uid)
              .remove();
          await FirebaseDatabase.instance
              .ref('passengers_location')
              .child(uid)
              .remove();
        }
      } catch (_) {}
    }
  }

  // ── Permissions ──────────────────────────────────────────

  static Future<bool> _ensureForegroundPermission() async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }
}
