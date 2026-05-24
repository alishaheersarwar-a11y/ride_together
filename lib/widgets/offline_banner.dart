import 'package:flutter/material.dart';

/// Thresholds for treating the OTHER party's last GPS update as stale. The
/// receiving side reads `lastUpdated` (server-set timestamp) from RTDB and
/// compares against now() — if no fresh ping in [warningAfter], we show a
/// "<role> offline" banner. After [hideMarkerAfter] the marker should be
/// removed from the map so the user doesn't act on a 5-minute-old position.
class OfflineThresholds {
  static const Duration warningAfter = Duration(seconds: 60);
  static const Duration hideMarkerAfter = Duration(minutes: 5);

  static bool isWarning(int? lastUpdatedMs) {
    if (lastUpdatedMs == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - lastUpdatedMs;
    return age >= warningAfter.inMilliseconds;
  }

  static bool shouldHideMarker(int? lastUpdatedMs) {
    if (lastUpdatedMs == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - lastUpdatedMs;
    return age >= hideMarkerAfter.inMilliseconds;
  }
}

/// Small banner shown at the top of the map when the tracked party hasn't
/// pinged in [OfflineThresholds.warningAfter]. Designed to be Stack'd over
/// the GoogleMap widget at the top of the screen.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.label,
  });

  /// The user-facing role of the offline party, e.g., "Driver" or "Passenger".
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB347).withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 18, color: Colors.black87),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$label is offline — last seen a moment ago',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
