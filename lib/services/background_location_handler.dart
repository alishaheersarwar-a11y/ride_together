import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

/// Channel-name constants shared between the UI isolate and the background
/// isolate. Using identical strings on both sides is critical — the background
/// service uses string-keyed message passing, so a typo here would silently
/// break configure/stop.
class LocationShareChannels {
  static const configure = 'location_share.configure';
  static const stop = 'location_share.stop';
  static const stopForeground = 'location_share.stopForeground';
}

/// Initialises the background service at app start. Safe to call multiple
/// times — `configure` is idempotent. Android-only registration; on other
/// platforms this is a no-op so existing iOS builds keep compiling.
Future<void> initializeLocationShareBackgroundService() async {
  if (kIsWeb) return;
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false,
      isForegroundMode: true,
      autoStartOnBoot: false,
      notificationChannelId: 'ride_together_location',
      initialNotificationTitle: 'Ride Together',
      initialNotificationContent: 'Sharing your location with your ride partner',
      foregroundServiceNotificationId: 7142,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    // iOS support is intentionally minimal — feature is Android-only.
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

/// Foreground-service entry point. Runs in a separate isolate from the UI,
/// so Firebase must be initialised here independently.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  // Required before any plugin call inside a background isolate.
  DartPluginRegistrant.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // If Firebase init fails we still want the service to live — it'll
    // simply no-op on writes. The UI isolate will surface errors.
  }

  String? uid;
  String? node;
  String? requestId;
  StreamSubscription<Position>? posSub;
  DateTime lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> stopTracking() async {
    await posSub?.cancel();
    posSub = null;
    if (uid != null && node != null) {
      try {
        await FirebaseDatabase.instance.ref(node!).child(uid!).remove();
      } catch (_) {}
    }
    uid = null;
    node = null;
    requestId = null;
  }

  // Serialize configure messages so a rapid second `configure` (e.g., a
  // back-to-back ride accept) waits for the first stopTracking() to finish
  // before reading uid/node. Without this chain, two configures arriving
  // within ~100ms would interleave and leak the old position stream.
  Future<void> configureChain = Future.value();

  service.on(LocationShareChannels.configure).listen((event) {
    configureChain = configureChain.then((_) async {
      if (event == null) return;
      final newUid = event['uid']?.toString();
      final newNode = event['node']?.toString();
      final newRequestId = event['requestId']?.toString();
      if (newUid == null || newNode == null) return;

      // Same configuration: no-op.
      if (uid == newUid &&
          node == newNode &&
          requestId == newRequestId &&
          posSub != null) {
        return;
      }

      await stopTracking();
    uid = newUid;
    node = newNode;
    requestId = newRequestId;

    if (service is AndroidServiceInstance) {
      try {
        await service.setForegroundNotificationInfo(
          title: 'Ride Together',
          content: 'Sharing your location with your ride partner',
        );
      } catch (_) {}
    }

    posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) {
      final now = DateTime.now();
      if (now.difference(lastWrite).inMilliseconds < 3000) return;
      lastWrite = now;
      final currentUid = uid;
      final currentNode = node;
      if (currentUid == null || currentNode == null) return;
      FirebaseDatabase.instance.ref(currentNode).child(currentUid).update({
        'latitude': p.latitude,
        'longitude': p.longitude,
        'lastUpdated': ServerValue.timestamp,
      }).catchError((_) {});

      // Throttled heartbeat: bump acceptedAt on the active ride so a
      // long-running trip never trips isRideStaleAndCleanup's 12h cutoff.
      // Independent throttle (5 min) keeps RTDB cost low while giving a
      // 144x safety margin against the staleness window.
      final rid = requestId;
      if (rid != null && now.difference(lastHeartbeat).inMinutes >= 5) {
        lastHeartbeat = now;
        FirebaseDatabase.instance
            .ref('ride_requests')
            .child(rid)
            .update({'acceptedAt': DateTime.now().millisecondsSinceEpoch})
            .catchError((_) {});
      }
    }, onError: (e, stack) {
      // Don't swallow stream errors silently — without this, a revoked
      // location permission or disabled GPS during a ride would just stop
      // updates with no signal anywhere. The log is captured by the
      // FlutterError pipeline in main.dart, and the absence of further
      // position writes makes lastUpdated go stale, which the offline
      // detector on the receiving side will surface to the other party.
      debugPrint('BG_POS_STREAM_ERROR: $e\n$stack');
    });
    });
  });

  service.on(LocationShareChannels.stop).listen((_) async {
    await stopTracking();
  });

  service.on(LocationShareChannels.stopForeground).listen((_) async {
    await stopTracking();
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });
}
