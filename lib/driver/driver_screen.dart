import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/driver/DProfile.dart';
import 'package:ride_together/driver/myrides_history.dart';
import 'package:ride_together/driver/offer_ride.dart';
import 'package:ride_together/driver/rating_screen.dart';
import 'package:ride_together/driver/ride_request_screen.dart';
import 'package:ride_together/driver/security_screen.dart';
import 'package:ride_together/driver/settings.dart';
import 'package:ride_together/driver/support_screen.dart';
import 'package:ride_together/driver/wallet_driver.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/passenger/notification.dart';
import 'package:ride_together/passenger/passenger_profile.dart';
import 'package:ride_together/services/location_share_service.dart';
import 'package:ride_together/services/ride_freshness.dart';
import 'package:ride_together/services/route_service.dart';
import 'package:ride_together/side_bar/legal.dart';
import 'package:ride_together/splash_screen.dart';
import 'package:ride_together/widgets/offline_banner.dart';
import 'package:ride_together/widgets/animated_live_marker.dart';
import 'package:ride_together/widgets/marker_icons.dart';

// ── Theme Colors ─────────────────────────────────────
const Color kNavy     = Color(0xFF1A1A2E);
const Color kCardNavy = Color(0xFF16213E);
const Color kDeep     = Color(0xFF0F3460);
const Color kCyan     = Color(0xFF00FFB3);
const Color kSkyBlue  = Color(0xFF00D4FF);

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> googleMapCompleterController = Completer<GoogleMapController>();

  GoogleMapController? controllerGoogleMap;
  Position? currentPosition;
  int _selectedIndex = 0;

  StreamSubscription<DatabaseEvent>? _rideSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;

  // ── Per-request tracking state (multi-passenger) ──────────────
  // Every map below is keyed by the booking's `ride_requests` key
  // (a.k.a. requestId / chat key). Each passenger that's currently
  // accepted by this driver has one entry across all of these maps.
  final Map<String, Map<String, dynamic>> _activeBookings = {};
  final Map<String, AnimatedLiveMarker> _passengerMarkers = {};
  final Map<String, Marker> _passengerMarkerSnapshots = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _passengerLocationSubs = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _unreadSubs = {};
  final Map<String, bool> _unreadByRequest = {};
  final Map<String, int?> _passengerLastUpdatedMs = {};
  final Map<String, bool> _passengerOfflineFlags = {};
  final Map<String, Polyline> _polylineByRequest = {};
  final Map<String, String?> _etaByRequest = {};

  final RouteService _routeService = RouteService();
  LatLng? _lastSelfPos;
  Timer? _freshnessTicker;

  bool get _hasUnreadMessage =>
      _unreadByRequest.values.any((v) => v == true);

  Iterable<String> get _trackedRequestIds => _passengerMarkers.keys;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(34.0151, 71.5249),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _listenForRideAcceptance();
    _loadActiveBooking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showLocationPermissionSnackbarIfDenied(context);
    });
  }

  @override
  void dispose() {
    _freshnessTicker?.cancel();
    _rideSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    for (final s in _unreadSubs.values) {
      s.cancel();
    }
    for (final s in _passengerLocationSubs.values) {
      s.cancel();
    }
    for (final m in _passengerMarkers.values) {
      m.dispose();
    }
    LocationShareService.stop();
    super.dispose();
  }

  // ── Load Active Booking ───────────────────────────
  Future<void> _loadActiveBooking() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseDatabase.instance
          .ref()
          .child('ride_requests')
          .orderByChild('driverId')
          .equalTo(uid)
          .get();

      if (!snap.exists) return;

      final data = Map<String, dynamic>.from(snap.value as Map);

      bool flushedStale = false;
      data.forEach((key, value) {
        final booking = Map<String, dynamic>.from(value as Map);
        final status = booking['status']?.toString();
        if (status == 'pending' || status == 'accepted') {
          if (isRideStaleAndCleanup(key, booking)) {
            flushedStale = true;
            // Stale booking — clear ONLY this passenger's location node.
            // We must NOT call stopAndCleanupBoth here because that also
            // wipes the driver's drivers_location node, which would break
            // any other passenger that's still actively being tracked.
            final passengerUid = booking['passengerId']?.toString();
            if (passengerUid != null && passengerUid.isNotEmpty) {
              FirebaseDatabase.instance
                  .ref('passengers_location')
                  .child(passengerUid)
                  .remove()
                  .catchError((_) {});
            }
            return;
          }
          if (mounted) {
            setState(() {
              _activeBookings[key] = {...booking, 'key': key};
            });
            _initUnreadMessageListener(key);
            if (status == 'accepted') {
              _startTrackingForBooking(key, booking);
            }
          }
        }
      });

      if (flushedStale && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A previous ride expired and was cleared.'),
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Load booking error: $e');
    }
  }

  void _initUnreadMessageListener(String chatId) {
    _unreadSubs[chatId]?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    _unreadSubs[chatId] = FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child(chatId)
        .child('messages')
        .onValue
        .listen((event) {
      bool foundUnread = false;
      if (event.snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final msg = Map<String, dynamic>.from(value as Map);
          if (msg['senderId'] != uid && msg['isRead'] == false) {
            foundUnread = true;
          }
        });
      }
      if (mounted) {
        setState(() => _unreadByRequest[chatId] = foundUnread);
      }
    });
  }

  // ── Live Tracking ─────────────────────────────────
  /// Start publishing the driver's location, listening to the passenger's
  /// location, drawing the polyline, and recording self-position frames so
  /// the route is recomputed as the driver moves.
  Future<void> _startTrackingForBooking(
    String requestId,
    Map<String, dynamic> booking,
  ) async {
    try {
      await _startTrackingForBookingInner(requestId, booking);
    } catch (e, stack) {
      debugPrint('Tracking start failed: $e\n$stack');
    }
  }

  Future<void> _startTrackingForBookingInner(
    String requestId,
    Map<String, dynamic> booking,
  ) async {
    final passengerUid = booking['passengerId']?.toString();
    if (passengerUid == null || passengerUid.isEmpty) return;
    if (_passengerMarkers.containsKey(requestId)) {
      return; // already tracking this booking
    }

    // Driver's own location publishing is a singleton — start it once
    // when we transition from 0→1 active passengers. Subsequent passengers
    // simply read the same drivers_location/{driverId} node.
    await _ensureSelfStreamRunning(requestId);

    // Per-passenger animated marker.
    final personIcon = await MarkerIcons.person();
    if (!mounted) return;
    final marker = AnimatedLiveMarker(
      markerId: MarkerId('passenger_marker_$requestId'),
      icon: personIcon,
      vsync: this,
      onUpdate: (m) {
        if (!mounted) return;
        setState(() => _passengerMarkerSnapshots[requestId] = m);
        _refreshRouteFor(requestId);
      },
    );
    _passengerMarkers[requestId] = marker;

    _passengerLocationSubs[requestId]?.cancel();
    _passengerLocationSubs[requestId] = FirebaseDatabase.instance
        .ref('passengers_location')
        .child(passengerUid)
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) {
        if (mounted) {
          setState(() {
            _passengerMarkerSnapshots.remove(requestId);
            _passengerLastUpdatedMs[requestId] = null;
            _polylineByRequest.remove(requestId);
            _etaByRequest.remove(requestId);
          });
        }
        return;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      final lastUpdated = (data['lastUpdated'] as num?)?.toInt();
      if (lastUpdated != null) {
        _passengerLastUpdatedMs[requestId] = lastUpdated;
      }
      _passengerMarkers[requestId]?.pushPoint(LatLng(lat, lng));
      if ((_passengerOfflineFlags[requestId] ?? false) && mounted) {
        setState(() => _passengerOfflineFlags[requestId] = false);
      }
    });

    _ensureFreshnessTickerRunning();
  }

  /// Idempotent — starts the driver's own GPS publishing exactly once,
  /// no matter how many passengers later attach.
  Future<void> _ensureSelfStreamRunning(String firstRequestId) async {
    if (_positionStreamSubscription != null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await LocationShareService.start(
        uid: uid,
        role: SharingRole.driver,
        requestId: firstRequestId,
      );
    }

    DateTime lastRtdbWrite = DateTime.fromMillisecondsSinceEpoch(0);
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        currentPosition = position;
        _lastSelfPos = LatLng(position.latitude, position.longitude);
      });

      final now = DateTime.now();
      if (now.difference(lastRtdbWrite).inMilliseconds >= 3000 &&
          LocationShareService.shouldPublish) {
        lastRtdbWrite = now;
        final node = LocationShareService.activeNode;
        final selfUid = FirebaseAuth.instance.currentUser?.uid;
        if (node != null && selfUid != null) {
          FirebaseDatabase.instance.ref(node).child(selfUid).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'lastUpdated': ServerValue.timestamp,
          }).catchError((_) {});
        }
      }

      // Self moved → recompute route to every active passenger.
      for (final id in _trackedRequestIds.toList()) {
        _refreshRouteFor(id);
      }
    });
  }

  void _ensureFreshnessTickerRunning() {
    if (_freshnessTicker != null) return;
    // Re-evaluate passenger freshness every 10s. See passenger_screen.dart
    // equivalent for the rationale — silent stream death is invisible
    // without a periodic re-check.
    _freshnessTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      bool changed = false;
      for (final id in _trackedRequestIds.toList()) {
        final last = _passengerLastUpdatedMs[id];
        final shouldWarn = OfflineThresholds.isWarning(last);
        final shouldHide = OfflineThresholds.shouldHideMarker(last);
        if (shouldWarn != (_passengerOfflineFlags[id] ?? false) || shouldHide) {
          _passengerOfflineFlags[id] = shouldWarn;
          if (shouldHide) {
            _passengerMarkerSnapshots.remove(id);
            _polylineByRequest.remove(id);
            _etaByRequest.remove(id);
          }
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  Future<void> _refreshRouteFor(String requestId) async {
    final self = _lastSelfPos;
    final passenger = _passengerMarkers[requestId]?.currentPosition;
    if (self == null || passenger == null) return;
    final route = await _routeService.getRoute(
      origin: self,
      destination: passenger,
      googleApiKey: directionsApiKey,
    );
    if (!mounted || route == null) return;
    if (!_passengerMarkers.containsKey(requestId)) return; // ride ended mid-fetch
    setState(() {
      _polylineByRequest[requestId] = Polyline(
        polylineId: PolylineId('driver_to_passenger_$requestId'),
        points: route.points,
        width: 5,
        color: kCyan,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      );
      _etaByRequest[requestId] = route.durationText;
    });
  }

  /// Tears down tracking for a single ride. When [rideEnded] is true (the
  /// ride reached a terminal state) also removes the passenger's location
  /// node so a crashed counterparty doesn't leave a phantom marker.
  ///
  /// If this was the LAST tracked ride, also stops the driver's own GPS
  /// publishing and clears `drivers_location/{driverUid}`.
  void _stopTrackingForRequest(String requestId, {bool rideEnded = false}) {
    final booking = _activeBookings[requestId];
    final passengerUid = booking?['passengerId']?.toString();

    _passengerLocationSubs.remove(requestId)?.cancel();
    _unreadSubs.remove(requestId)?.cancel();
    _passengerMarkers.remove(requestId)?.dispose();
    _passengerMarkerSnapshots.remove(requestId);
    _polylineByRequest.remove(requestId);
    _etaByRequest.remove(requestId);
    _passengerLastUpdatedMs.remove(requestId);
    _passengerOfflineFlags.remove(requestId);
    _unreadByRequest.remove(requestId);
    _activeBookings.remove(requestId);

    if (rideEnded &&
        passengerUid != null &&
        passengerUid.isNotEmpty) {
      FirebaseDatabase.instance
          .ref('passengers_location')
          .child(passengerUid)
          .remove()
          .catchError((_) {});
    }

    final lastRideEnded = _passengerMarkers.isEmpty;
    if (lastRideEnded) {
      _freshnessTicker?.cancel();
      _freshnessTicker = null;
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
      _lastSelfPos = null;
      _routeService.clear();
      // Final cleanup — releases drivers_location/{driverUid}.
      LocationShareService.stop();
    }

    if (mounted) setState(() {});
  }

  Future<void> _endRide(String requestId) async {
    if (requestId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End this ride?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Live tracking will stop and the ride will move to history.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan,
              foregroundColor: Colors.black,
            ),
            child: const Text('END RIDE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseDatabase.instance
          .ref('ride_requests')
          .child(requestId)
          .update({
        'status': 'completed',
        'endedAt': ServerValue.timestamp,
        'endedBy': 'driver',
      });
      // Listener on `ride_requests` will pick up the change and call
      // _stopTrackingForRequest via the status branch — call it here too so
      // teardown is instant rather than waiting for the round-trip.
      _stopTrackingForRequest(requestId, rideEnded: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end ride: $e')),
      );
    }
  }

  void _listenForRideAcceptance() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _rideSubscription = FirebaseDatabase.instance
        .ref()
        .child("ride_requests")
        .orderByChild("driverId")
        .equalTo(uid)
        .onChildChanged
        .listen((event) {
      // Wrap the entire callback so a malformed Firebase row (missing field,
      // unexpected type) can't propagate as an uncaught exception and bring
      // the app down. Errors are logged via the FlutterError pipeline.
      try {
        if (event.snapshot.value == null) return;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final status = data['status']?.toString();
        final key = event.snapshot.key;
        if (key == null) return;

        if (status == 'accepted') {
          if (mounted) {
            setState(() {
              _activeBookings[key] = {...data, 'key': key};
            });
          }
          _initUnreadMessageListener(key);
          _startTrackingForBooking(key, data);
          _showAcceptanceDialog(
            data['passengerName'] ?? "A Passenger",
            data['pickup'] ?? "Location",
            data,
            key,
          );
        } else if (status == 'completed' ||
            status == 'rejected' ||
            status == 'cancelled') {
          // Only react if this is a booking we're tracking on this screen.
          if (_activeBookings.containsKey(key)) {
            _stopTrackingForRequest(key, rideEnded: true);
          }
        }
      } catch (e, stack) {
        debugPrint('Ride listener error: $e\n$stack');
      }
    }, onError: (e, stack) {
      debugPrint('Ride subscription stream error: $e\n$stack');
    });
  }

  void _showAcceptanceDialog(String name, String location, Map data, String rideKey) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: kCardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: kCyan, size: 70),
              const SizedBox(height: 20),
              const Text("New Ride Request!",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  children: [
                    TextSpan(text: name, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold)),
                    const TextSpan(text: " wants a ride at "),
                    TextSpan(text: location, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCyan,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("VIEW DETAILS",
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => currentPosition = position);
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      controllerGoogleMap?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: currentLatLng, zoom: 15)),
      );
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final offlineCount =
        _passengerOfflineFlags.values.where((v) => v == true).length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kNavy,
      drawer: const DriverSidebar(),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: _kGooglePlex,
            markers: _passengerMarkerSnapshots.values.toSet(),
            polylines: _polylineByRequest.values.toSet(),
            onMapCreated: (mapController) => controllerGoogleMap = mapController,
          ),

          if (offlineCount > 0)
            Align(
              alignment: Alignment.topCenter,
              child: OfflineBanner(
                label: offlineCount == 1
                    ? 'Passenger'
                    : '$offlineCount passengers',
              ),
            ),

          if (_etaByRequest.isNotEmpty)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildEtaPills(),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kNavy,
                    border: Border.all(color: kCyan, width: 2),
                    boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.menu, color: kCyan, size: 26),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 16),
                  child: FloatingActionButton(
                    backgroundColor: kNavy,
                    shape: const CircleBorder(side: BorderSide(color: kCyan, width: 2)),
                    onPressed: _getCurrentLocation,
                    child: const Icon(Icons.my_location, color: kCyan),
                  ),
                ),
                _buildBottomPanel(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  List<Widget> _buildEtaPills() {
    final widgets = <Widget>[];
    final entries = _activeBookings.entries
        .where((e) =>
            _etaByRequest[e.key] != null &&
            _passengerMarkerSnapshots.containsKey(e.key))
        .toList();
    for (final entry in entries) {
      final name = entry.value['passengerName']?.toString() ?? 'Passenger';
      final eta = _etaByRequest[entry.key];
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kCardNavy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kCyan.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_filled, color: kCyan, size: 14),
                const SizedBox(width: 6),
                Text('$name ~$eta away',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: const BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _quickAction(Icons.add_circle_outline_rounded, 'Offer Ride', kCyan,
                        () => Navigator.push(context, MaterialPageRoute(builder: (c) => const OfferRideScreen()))),
                const SizedBox(width: 10),
                _quickAction(Icons.history, 'Request', const Color(0xFFFF6B6B),
                        () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RideRequestsScreen()))),
                const SizedBox(width: 10),

              ],
            ),
          ),
          const SizedBox(height: 25),
          _buildMainCTA(),
          if (_activeBookings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._activeBookings.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildActiveBookingBanner(e.key, e.value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveBookingBanner(
      String requestId, Map<String, dynamic> booking) {
    final isAccepted = booking['status'] == 'accepted';
    final hasUnread = _unreadByRequest[requestId] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (hasUnread ? Colors.red : kSkyBlue).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (hasUnread ? Colors.red : kSkyBlue).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: kDeep, child: Icon(Icons.person, color: kSkyBlue, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking['passengerName'] ?? 'Passenger', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(isAccepted ? '✅ Active Ride' : '⏳ Pending', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            if (isAccepted)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  onPressed: () => _endRide(requestId),
                  icon: const Icon(Icons.stop_circle, size: 16, color: Color(0xFFFF4B2B)),
                  label: const Text('END',
                      style: TextStyle(
                          color: Color(0xFFFF4B2B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4B2B).withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCTA() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const OfferRideScreen())),
        child: Container(
          width: double.infinity, height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [kCyan, Color(0xFF00B4D8)]),
            boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 10)],
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, color: Colors.black, size: 24),
                SizedBox(width: 12),
                Text('OFFER A RIDE NOW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == 0) {
          setState(() => _selectedIndex = 0);
        } else if (index == 1) {
          setState(() => _selectedIndex = 1);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalletDriver()),
          ).then((_) => setState(() => _selectedIndex = 0));
        } else if (index == 2) {
          setState(() => _selectedIndex = 2);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DProfileScreen()),
          ).then((_) => setState(() => _selectedIndex = 0));
        }
      },
      backgroundColor: kNavy,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.white38,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  DRIVER SIDEBAR (Preserved)
// ─────────────────────────────────────────────
class DriverSidebar extends StatefulWidget {
  const DriverSidebar({super.key});
  @override
  State<DriverSidebar> createState() => _DriverSidebarState();
}

class _DriverSidebarState extends State<DriverSidebar> {
  String _userName = '';
  String _userImageUrl = '';
  String _rating = '0.0';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseDatabase.instance.ref().child('users').child(uid).get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _userName = data['name'] ?? 'Driver';
          _userImageUrl = data['imageUrl'] ?? '';
          _rating = (data['rating'] ?? '0.0').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kNavy,
      width: MediaQuery.of(context).size.width * 0.82,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildSwitchButton(),
                  const SizedBox(height: 20),
                  _menuTile(icon: Icons.directions_car, label: 'My Rides', subtitle: 'Your previous rides history', color: const Color(0xFF00C853), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverHistory()))),
                  _menuTile(icon: Icons.shield_outlined, label: 'Safety Center', subtitle: 'SOS & trusted contacts', color: const Color(0xFFFF4444), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                  _menuTile(icon: Icons.star_outline_rounded, label: 'Rate Our App', subtitle: 'Share your feedback', color: const Color(0xFFFFD700), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppRatingScreen()))),
                  _menuTile(icon: Icons.headset_mic_outlined, label: 'Support & Help', subtitle: 'Get help anytime', color: kSkyBlue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
                  _menuTile(icon: Icons.settings_outlined, label: 'Settings', subtitle: 'Account & preferences', color: Colors.white54, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSettings()))),
                  _menuTile(icon: Icons.notifications_active, label: 'Notifications', subtitle: 'Messages and booking status', color: const Color(0xFFFF4444), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                  _menuTile(icon: Icons.policy, label: 'Legal & Terms', subtitle: 'Privacy policy and terms', color: const Color(0xFF00C853), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalTerms()))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 55, bottom: 24, left: 20, right: 20),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [kDeep, kCardNavy])),
      child: _isLoading ? const Center(child: CircularProgressIndicator(color: kCyan)) : Row(
        children: [
          CircleAvatar(radius: 35, backgroundImage: _userImageUrl.isNotEmpty ? NetworkImage(_userImageUrl) : null, child: _userImageUrl.isEmpty ? const Icon(Icons.person, color: kCyan) : null),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DRIVER', style: TextStyle(color: kCyan, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('⭐ $_rating Rating', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
          ])),
        ],
      ),
    );
  }

  Widget _buildSwitchButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerProfileScreen())),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [kCyan, kSkyBlue])),
        child: const Center(child: Text('SWITCH TO PASSENGER MODE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _menuTile({required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white12),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: InkWell(
        onTap: () async {
          // Make sure live tracking stops cleanly when the driver logs out.
          await LocationShareService.stop();
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        },
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
