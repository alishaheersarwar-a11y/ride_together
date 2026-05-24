import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_together/driver/driverprofile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/driver/rating_screen.dart';
import 'package:ride_together/driver/security_screen.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/passenger/PProfile.dart';
import 'package:ride_together/passenger/available_rides_screen.dart';
import 'package:ride_together/passenger/my_ride_status.dart';
import 'package:ride_together/passenger/notification.dart';
import 'package:ride_together/passenger/passenger-history.dart';
import 'package:ride_together/passenger/search_ride_screen.dart';
import 'package:ride_together/passenger/ride_details_screen.dart';
import 'package:ride_together/passenger/setting_passenger.dart';
import 'package:ride_together/passenger/support_help.dart';
import 'package:ride_together/passenger/wallet_passenger.dart';
import 'package:ride_together/services/location_share_service.dart';
import 'package:ride_together/services/route_service.dart';
import 'package:ride_together/side_bar/legal.dart';
import 'package:ride_together/splash_screen.dart';
import 'package:ride_together/widgets/offline_banner.dart';
import 'package:ride_together/widgets/animated_live_marker.dart';
import 'package:ride_together/widgets/marker_icons.dart';

const Color kNavy     = Color(0xFF1A1A2E);
const Color kCardNavy = Color(0xFF16213E);
const Color kDeep     = Color(0xFF0F3460);
const Color kCyan     = Color(0xFF00FFB3);
const Color kSkyBlue  = Color(0xFF00D4FF);

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> googleMapCompleterController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  Position? currentPosition;
  int _selectedIndex = 0;

  // Variables to track active requests for navigation
  String requestId = "temp_id";
  String driverName = "Driver";
  Map currentRideData = {
    'fare': 0,
    'driverName': 'No Active Ride',
    'pickup': 'N/A',
    'destination': 'N/A',
    'rideId': 'default'
  };

  // --- LOCATION TRACKING UPGRADES ---
  Set<Marker> markersSet = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _rideSubscription;
  StreamSubscription<Position>? _selfPositionSubscription;

  AnimatedLiveMarker? _driverMarker;
  Marker? _driverMarkerSnapshot;
  final RouteService _routeService = RouteService();
  String? _trackedDriverId;
  String? _trackedRequestId;
  LatLng? _lastSelfPos;
  String? _etaText;

  // Driver-side freshness — last RTDB-stamped update (millisSinceEpoch). The
  // periodic ticker uses this to decide whether to show the offline banner
  // and/or hide a stale marker, even when no new RTDB events are arriving.
  int? _driverLastUpdatedMs;
  bool _driverOffline = false;
  Timer? _freshnessTicker;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(34.0151, 71.5249),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _loadActiveRide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showLocationPermissionSnackbarIfDenied(context);
    });
  }

  @override
  void dispose() {
    _freshnessTicker?.cancel();
    _driverLocationSubscription?.cancel();
    _rideSubscription?.cancel();
    _selfPositionSubscription?.cancel();
    _driverMarker?.dispose();
    LocationShareService.stop();
    super.dispose();
  }

  // UPDATED: Now triggers driver location tracking once a ride is found
  void _loadActiveRide() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _rideSubscription = FirebaseDatabase.instance.ref().child('ride_requests')
        .orderByChild('passengerId').equalTo(uid).limitToLast(1)
        .onValue.listen((event) {
      try {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final key = data.keys.first;
        final rideInfo = Map<String, dynamic>.from(data[key] as Map);

        setState(() {
          requestId = key;
          currentRideData = rideInfo;
          driverName = rideInfo['driverName'] ?? "Driver";
        });

        final String? activeDriverId = rideInfo['driverId']?.toString();
        final String status = rideInfo['status']?.toString() ?? '';
        if (activeDriverId != null && activeDriverId.isNotEmpty && status == 'accepted') {
          _startTrackingDriver(key, activeDriverId);
        } else {
          final terminal = status == 'completed' ||
              status == 'cancelled' ||
              status == 'rejected';
          _stopTrackingAndClear(rideEnded: terminal);
        }
      } else {
        // Ride node disappeared from RTDB — treat as terminal.
        _stopTrackingAndClear(rideEnded: true);
      }
      } catch (e, stack) {
        debugPrint('Ride listener error: $e\n$stack');
      }
    }, onError: (e, stack) {
      debugPrint('Ride subscription stream error: $e\n$stack');
    });
  }

  Future<void> _startTrackingDriver(String requestId, String driverId) async {
    try {
      await _startTrackingDriverInner(requestId, driverId);
    } catch (e, stack) {
      debugPrint('Tracking start failed: $e\n$stack');
    }
  }

  Future<void> _startTrackingDriverInner(String requestId, String driverId) async {
    if (_trackedRequestId == requestId && _trackedDriverId == driverId) return;
    _trackedRequestId = requestId;
    _trackedDriverId = driverId;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await LocationShareService.start(
        uid: uid,
        role: SharingRole.passenger,
        requestId: requestId,
      );
    }

    // Self-position stream — drives polyline refresh AND (since the
    // foreground service is disabled to avoid Android 13+ notification
    // crashes) publishes the passenger's GPS to RTDB so the driver's view
    // gets live updates. Throttled to 3s. Live tracking now requires the
    // passenger to keep the app foregrounded during a ride.
    _selfPositionSubscription?.cancel();
    DateTime lastRtdbWrite = DateTime.fromMillisecondsSinceEpoch(0);
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      _selfPositionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((p) {
        if (!mounted) return;
        _lastSelfPos = LatLng(p.latitude, p.longitude);

        final now = DateTime.now();
        if (now.difference(lastRtdbWrite).inMilliseconds >= 3000 &&
            LocationShareService.shouldPublish) {
          lastRtdbWrite = now;
          final node = LocationShareService.activeNode;
          final selfUid = FirebaseAuth.instance.currentUser?.uid;
          if (node != null && selfUid != null) {
            FirebaseDatabase.instance.ref(node).child(selfUid).update({
              'latitude': p.latitude,
              'longitude': p.longitude,
              'lastUpdated': ServerValue.timestamp,
            }).catchError((_) {});
          }
        }

        _maybeRefreshRoute();
      });
    }

    _driverMarker?.dispose();
    final carIcon = await MarkerIcons.car();
    if (!mounted) return;
    _driverMarker = AnimatedLiveMarker(
      markerId: const MarkerId('driver_marker'),
      icon: carIcon,
      vsync: this,
      onUpdate: (m) {
        if (!mounted) return;
        setState(() {
          _driverMarkerSnapshot = m;
          markersSet
            ..removeWhere((mk) => mk.markerId.value == 'driver_marker')
            ..add(m);
        });
        _maybeRefreshRoute();
      },
    );

    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = FirebaseDatabase.instance
        .ref('drivers_location')
        .child(driverId)
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) {
        if (!mounted) return;
        setState(() {
          _driverMarkerSnapshot = null;
          _driverLastUpdatedMs = null;
          markersSet.removeWhere((m) => m.markerId.value == 'driver_marker');
          _polylines.clear();
          _etaText = null;
        });
        return;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      final lastUpdated = (data['lastUpdated'] as num?)?.toInt();
      if (lastUpdated != null) _driverLastUpdatedMs = lastUpdated;
      _driverMarker?.pushPoint(LatLng(lat, lng));
      // Fresh ping → ensure offline state is cleared.
      if (_driverOffline && mounted) {
        setState(() => _driverOffline = false);
      }
    });

    // Re-evaluate driver freshness every 10s. Without this, the marker would
    // stay visible forever if the driver's RTDB writes silently stop (revoked
    // permission, OS killed foreground service, network drop), because no
    // event arrives to trigger a re-check.
    _freshnessTicker?.cancel();
    _freshnessTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final last = _driverLastUpdatedMs;
      final shouldWarn = OfflineThresholds.isWarning(last);
      final shouldHide = OfflineThresholds.shouldHideMarker(last);
      if (shouldWarn != _driverOffline || shouldHide) {
        setState(() {
          _driverOffline = shouldWarn;
          if (shouldHide) {
            _driverMarkerSnapshot = null;
            markersSet.removeWhere((m) => m.markerId.value == 'driver_marker');
            _polylines.clear();
            _etaText = null;
          }
        });
      }
    });
  }

  Future<void> _maybeRefreshRoute() async {
    final self = _lastSelfPos;
    final driver = _driverMarker?.currentPosition;
    if (self == null || driver == null) return;
    final route = await _routeService.getRoute(
      origin: driver,        // driver → passenger
      destination: self,
      googleApiKey: directionsApiKey,
    );
    if (!mounted || route == null) return;
    setState(() {
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('driver_to_passenger'),
          points: route.points,
          width: 5,
          color: kCyan,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      _etaText = route.durationText;
    });
  }

  /// Tears down all tracking. When the ride reached a terminal state
  /// ([rideEnded] = true), also removes BOTH parties' location nodes so a
  /// crashed counterparty doesn't leave a phantom marker for the next ride.
  void _stopTrackingAndClear({bool rideEnded = false}) {
    final driverUid = _trackedDriverId;
    final selfUid = FirebaseAuth.instance.currentUser?.uid;

    _freshnessTicker?.cancel();
    _freshnessTicker = null;
    _driverLastUpdatedMs = null;
    _driverOffline = false;

    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _selfPositionSubscription?.cancel();
    _selfPositionSubscription = null;
    _driverMarker?.dispose();
    _driverMarker = null;
    _trackedDriverId = null;
    _trackedRequestId = null;
    _lastSelfPos = null;
    _routeService.clear();

    if (rideEnded) {
      LocationShareService.stopAndCleanupBoth(
        driverUid: driverUid,
        passengerUid: selfUid,
      );
    } else {
      LocationShareService.stop();
    }

    if (mounted) {
      setState(() {
        _driverMarkerSnapshot = null;
        markersSet.removeWhere((m) => m.markerId.value == 'driver_marker');
        _polylines.clear();
        _etaText = null;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() => currentPosition = position);
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);
    controllerGoogleMap?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: currentLatLng, zoom: 15)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kNavy,
      drawer: const PassengerSidebar(),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: _kGooglePlex,
            markers: markersSet,
            polylines: _polylines,
            onMapCreated: (mapController) {
              controllerGoogleMap = mapController;
              _getCurrentLocation();
            },
          ),

          if (_driverOffline)
            const Align(
              alignment: Alignment.topCenter,
              child: OfflineBanner(label: 'Driver'),
            ),

          if (_etaText != null && _driverMarkerSnapshot != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      const Icon(Icons.directions_car, color: kCyan, size: 16),
                      const SizedBox(width: 6),
                      Text('Driver ~$_etaText away',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 48,
                  height: 48,
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

                _quickAction(Icons.history, 'Available', kSkyBlue, () {
                  RideSearchData dummySearch = RideSearchData(
                    passengerName: userName,
                    pickupAddress: "Current Location",
                    destAddress: "Anywhere",
                    pickupLatLng: const LatLng(0, 0),
                    destLatLng: const LatLng(0, 0),
                    seatsRequired: 1,
                    luggage: "Small",
                    genderPref: "All",
                  );
                  Navigator.push(context, MaterialPageRoute(builder: (c) => AvailableRidesScreen(searchData: dummySearch)));
                }),

                const SizedBox(width: 8),

                _quickAction(Icons.search, 'Enter Ride', kCyan, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => SearchRideScreen()));
                }),

                const SizedBox(width: 8),

                _quickAction(Icons.info_outline, 'Ride Detail', Colors.orangeAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => RideDetailScreen(
                    ride: currentRideData,
                    pickup: currentRideData['pickup']?.toString() ?? 'N/A',
                    destination: currentRideData['destination']?.toString() ?? 'N/A',
                    date: currentRideData['date']?.toString() ?? 'Today',
                    time: currentRideData['time']?.toString() ?? 'Now',
                    passengers: '1',
                    // --- ADD THESE TWO LINES BELOW ---
                    passengerName: currentRideData['passengerName']?.toString() ?? 'Passenger',
                    genderPref: currentRideData['genderPreference']?.toString() ?? 'Both',
                  )));
                }),

                const SizedBox(width: 8),

                _quickAction(Icons.track_changes_rounded, 'Status', const Color(0xFFFF6B6B), () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => MyRideStatusScreen(
                    requestId: requestId,
                    driverName: driverName,
                  )));
                }),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _buildMainCTA(),
        ],
      ),
    );
  }

  Widget _buildMainCTA() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SearchRideScreen())),
        child: Container(
          width: double.infinity, height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [kCyan, Color(0xFF00B4D8)]),
            boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, color: Colors.black, size: 24),
                SizedBox(width: 12),
                Text('ENTER A RIDE NOW', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
            MaterialPageRoute(builder: (_) => const WalletPassenger()),
          ).then((_) => setState(() => _selectedIndex = 0));
        } else if (index == 2) {
          setState(() => _selectedIndex = 2);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PProfileScreen()),
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

// Side bar and menu tile widgets remain as in your original file...
class PassengerSidebar extends StatefulWidget {
  const PassengerSidebar({super.key});
  @override
  State<PassengerSidebar> createState() => _PassengerSidebarState();
}

class _PassengerSidebarState extends State<PassengerSidebar> {
  String _userName = '';
  String _userImageUrl = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseDatabase.instance.ref().child('users').child(uid).get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _userName = data['name'] ?? "User";
          _userImageUrl = data['imageUrl'] ?? '';
          _isLoading = false;
        });
      }
    } catch (_) {
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
                  const SizedBox(height: 28),
                  _buildSwitchButton(),
                  const SizedBox(height: 28),
                  _menuTile(icon: Icons.directions_car, label: 'My Rides', subtitle: 'Your previous rides History', color: const Color(0xFF00C853), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PassengerHistory()))),
                  _menuTile(icon: Icons.shield_outlined, label: 'Safety Center', subtitle: 'SOS & trusted contacts', color: const Color(0xFFFF4444), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SecurityScreen()))),
                  _menuTile(icon: Icons.star_outline_rounded, label: 'Rate Our App', subtitle: 'Share your feedback', color: const Color(0xFFFFD700), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AppRatingScreen()))),
                  _menuTile(icon: Icons.headset_mic_outlined, label: 'Support & Help', subtitle: 'Get help anytime', color: kSkyBlue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SupportHelp()))),
                  _menuTile(icon: Icons.settings_outlined, label: 'Settings', subtitle: 'Account & preferences', color: Colors.white54, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen()))),
                  _menuTile(icon: Icons.notifications_active, label: 'Notification', subtitle: 'Messages and booking status', color: const Color(0xFFFF4444), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const NotificationsScreen()))),
                  _menuTile(icon: Icons.policy, label: 'legal and Terms', subtitle: 'Privacy policy and terms of service', color: const Color(0xFF00C853), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LegalTerms()))),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 55, bottom: 24, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kDeep, kCardNavy]),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(30)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kCyan, strokeWidth: 2))
          : Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: kDeep,
            backgroundImage: _userImageUrl.isNotEmpty ? NetworkImage(_userImageUrl) : null,
            child: _userImageUrl.isEmpty ? const Icon(Icons.person, color: kCyan, size: 34) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PASSENGER', style: TextStyle(color: kCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverProfileScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [kCyan, kSkyBlue])),
        child: const Center(child: Text('SWITCH TO DRIVER MODE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13))),
      ),
    );
  }

  Widget _menuTile({required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
