import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ride_together/passenger/search_ride_screen.dart';

// ════════════════════════════════════════════════════════════════════
// DATA MODEL
// ════════════════════════════════════════════════════════════════════
class RideSearchData {
  final String passengerName;
  final String pickupAddress;
  final String destAddress;
  final LatLng pickupLatLng;
  final LatLng destLatLng;
  final DateTime? date;
  final TimeOfDay? time;
  final int seatsRequired;
  final String luggage;
  final String genderPref;

  const RideSearchData({
    required this.passengerName,
    required this.pickupAddress,
    required this.destAddress,
    required this.pickupLatLng,
    required this.destLatLng,
    this.date,
    this.time,
    required this.seatsRequired,
    required this.luggage,
    required this.genderPref,
  });
}

// ════════════════════════════════════════════════════════════════════
// DRIVER PROFILE MODEL
// ════════════════════════════════════════════════════════════════════
class DriverProfile {
  final String name;
  final String? photoUrl;

  const DriverProfile({required this.name, this.photoUrl});
}

// ════════════════════════════════════════════════════════════════════
// AVAILABLE RIDES SCREEN
// ════════════════════════════════════════════════════════════════════
class AvailableRidesScreen extends StatefulWidget {
  final RideSearchData searchData;

  const AvailableRidesScreen({super.key, required this.searchData});

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen>
    with SingleTickerProviderStateMixin {
  static const Color kNavy     = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kCyan     = Color(0xFF00FFB3);
  static const Color kDark     = Color(0xFF0F0F1A);

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<DriverProfile>> _driverProfileCache = {};

  Position? _currentPosition;
  String _searchKeyword = "";
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<DriverProfile> _fetchDriverProfile(String driverId) {
    return _driverProfileCache.putIfAbsent(driverId, () async {
      if (driverId.isEmpty) return const DriverProfile(name: 'Driver');

      final nodesToTry = ['users', 'drivers', 'Drivers', 'Users'];
      for (final node in nodesToTry) {
        try {
          final snap = await FirebaseDatabase.instance
              .ref()
              .child('$node/$driverId')
              .get();

          if (snap.exists && snap.value != null) {
            final data = Map<String, dynamic>.from(snap.value as Map);
            final String name = data['name']?.toString() ??
                data['fullName']?.toString() ??
                data['displayName']?.toString() ??
                data['userName']?.toString() ??
                data['driverName']?.toString() ??
                'Driver';
            final String? photoUrl = data['photoUrl']?.toString() ??
                data['profileImage']?.toString() ??
                data['imageUrl']?.toString() ??
                data['photo']?.toString() ??
                data['profilePhoto']?.toString() ??
                data['driverImage']?.toString();
            return DriverProfile(
              name: name,
              photoUrl:
              (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
            );
          }
        } catch (_) {
          continue;
        }
      }
      return const DriverProfile(name: 'Driver');
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final position = await Geolocator.getCurrentPosition();
    if (mounted) setState(() => _currentPosition = position);
  }

  double _calculateDistance(dynamic lat, dynamic lng) {
    if (_currentPosition == null) return 0.0;
    final double? dLat =
    lat is double ? lat : double.tryParse(lat?.toString() ?? '');
    final double? dLng =
    lng is double ? lng : double.tryParse(lng?.toString() ?? '');
    if (dLat == null || dLng == null) return 0.0;
    return Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        dLat, dLng) /
        1000;
  }

  String _shortAddr(String full) {
    final parts = full.split(',');
    return parts.length >= 2
        ? '${parts[0].trim()}, ${parts[1].trim()}'
        : parts[0].trim();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.searchData;
    return Scaffold(
      backgroundColor: kNavy,
      body: Column(
        children: [
          FadeTransition(opacity: _fadeAnim, child: _buildRouteHeader(d)),
          _buildSearchBar(),
          Expanded(child: _buildRideList()),
        ],
      ),
    );
  }

  Widget _buildRouteHeader(RideSearchData d) {
    final String dateStr = d.date != null
        ? DateFormat('EEE, dd MMM yyyy').format(d.date!)
        : "Any Date";
    final String timeStr =
    d.time != null ? d.time!.format(context) : "Any Time";

    return Container(
      decoration: const BoxDecoration(
        color: kDark,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black54, blurRadius: 20, offset: Offset(0, 6))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kCardNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white70, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AVAILABLE RIDES",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5),
                        ),
                        Text(
                          "Hello, ${d.passengerName}  •  "
                              "${d.seatsRequired} seat${d.seatsRequired > 1 ? 's' : ''}",
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kCyan.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_seat, color: kCyan, size: 13),
                      const SizedBox(width: 4),
                      Text("${d.seatsRequired}",
                          style: const TextStyle(
                              color: kCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCardNavy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kCyan.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Column(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: kCyan, shape: BoxShape.circle)),
                      Container(
                        width: 2,
                        height: 32,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kCyan, Colors.redAccent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("PICKUP",
                              style: TextStyle(
                                  color: kCyan.withOpacity(0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 2),
                          Text(_shortAddr(d.pickupAddress),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 10),
                          Text("DROPOFF",
                              style: TextStyle(
                                  color: Colors.redAccent.withOpacity(0.7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 2),
                          Text(_shortAddr(d.destAddress),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _metaChip(Icons.calendar_month, dateStr),
                  const SizedBox(width: 8),
                  _metaChip(Icons.access_time, timeStr),
                  const SizedBox(width: 8),
                  _metaChip(Icons.luggage, d.luggage),
                  const SizedBox(width: 8),
                  _metaChip(Icons.wc,
                      d.genderPref == "All" ? "Everyone" : d.genderPref),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: kCyan, size: 12),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: kCardNavy,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white12)),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (val) =>
            setState(() => _searchKeyword = val.toLowerCase()),
        decoration: const InputDecoration(
            hintText: "Search Destination or Driver",
            hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
            icon: Icon(Icons.search, color: kCyan, size: 20),
            border: InputBorder.none),
      ),
    );
  }

  Widget _buildRideList() {
    return StreamBuilder(
      stream:
      FirebaseDatabase.instance.ref().child("available_rides").onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: kCyan));
        }
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _emptyState(
              "No rides available", "Be the first to post a ride!");
        }

        final Map rawValues = snapshot.data!.snapshot.value as Map;
        final List<Map> rides = [];

        rawValues.forEach((firebaseKey, value) {
          if (value == null) return;
          final Map ride = Map.from(value);
          ride['rideId'] = ride['rideId'] ?? firebaseKey;

          final String driverId = ride['driverId']?.toString() ??
              ride['driver_id']?.toString() ??
              ride['driverUid']?.toString() ??
              ride['uid']?.toString() ??
              ride['userId']?.toString() ??
              '';
          ride['driverId'] = driverId;

          final String status = ride['status']?.toString() ?? 'active';
          if (status != 'active') return;

          final String dest =
              ride['destination']?.toString().toLowerCase() ?? '';
          final String driver =
              ride['driverName']?.toString().toLowerCase() ?? '';
          if (_searchKeyword.isNotEmpty &&
              !dest.contains(_searchKeyword) &&
              !driver.contains(_searchKeyword)) return;

          rides.add(ride);
        });

        if (rides.isEmpty) {
          return _emptyState("No rides found", "Try a different destination");
        }

        rides.sort((a, b) {
          final int tA =
              int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
          final int tB =
              int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: rides.length,
          itemBuilder: (context, index) => _rideCard(rides[index], index),
        );
      },
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: kCyan.withOpacity(0.3), size: 60),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _rideCard(Map ride, int index) {
    final double dist =
    _calculateDistance(ride['pickupLat'], ride['pickupLng']);
    final String fare = ride['fare']?.toString() ?? '0';
    final String seats = ride['seats']?.toString() ?? '0';
    final bool hasAC = ride['ac'] == true;
    final bool hasMusic = ride['music'] == true;
    final String driverId = ride['driverId']?.toString() ?? '';
    final String fallbackName = ride['driverName']?.toString() ?? 'Driver';
    final String? fallbackImg = ride['driverImage']?.toString();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOut,
      builder: (context, val, child) => Opacity(
        opacity: val,
        child:
        Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardNavy,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kCyan.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Driver Profile & Price ──────────────────────────────
            FutureBuilder<DriverProfile>(
              future: _fetchDriverProfile(driverId),
              builder: (context, snap) {
                final String driverName = snap.data?.name ?? fallbackName;
                final String? imgUrl = snap.data?.photoUrl ?? fallbackImg;

                return Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kCyan, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: kCyan.withOpacity(0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child:
                        _buildDriverAvatar(imgUrl, snap.connectionState),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          snap.connectionState == ConnectionState.waiting
                              ? _shimmerName()
                              : Text(
                            driverName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(
                              5,
                                  (i) => const Icon(Icons.star,
                                  color: Colors.amber, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("PKR $fare",
                            style: const TextStyle(
                                color: kCyan,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const Text("per seat",
                            style: TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                );
              },
            ),

            const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Divider(color: Colors.white12)),

            // ── Vehicle Details ──────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _detailBadge(Icons.directions_car,
                    ride['vehicleName']?.toString() ?? "Car"),
                _detailBadge(Icons.numbers,
                    ride['plateNumber']?.toString() ?? "---"),
                _detailBadge(Icons.palette,
                    ride['vehicleColor']?.toString() ?? "Color"),
              ],
            ),

            const SizedBox(height: 15),

            // ── Route & Distance ─────────────────────────────────────
            Row(
              children: [
                Column(children: [
                  const Icon(Icons.radio_button_checked,
                      color: kCyan, size: 14),
                  Container(width: 1, height: 20, color: Colors.white10),
                  const Icon(Icons.location_on,
                      color: Colors.redAccent, size: 14),
                ]),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride['pickup']?.toString() ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Text(ride['destination']?.toString() ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text("${dist.toStringAsFixed(1)} KM away",
                    style: const TextStyle(
                        color: kCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(height: 20),

            // ── Amenities & Preferences ──────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                    Icons.calendar_month, ride['date']?.toString() ?? "Date"),
                _infoChip(
                    Icons.access_time, ride['time']?.toString() ?? "Time"),
                _infoChip(
                    Icons.wc, "Pref: ${ride['preference'] ?? 'All'}"),
                _infoChip(Icons.luggage,
                    "Luggage: ${ride['luggage'] ?? 'Medium'}"),
                if (hasAC) _infoChip(Icons.ac_unit, "AC"),
                if (hasMusic) _infoChip(Icons.music_note, "Music"),
              ],
            ),

            const SizedBox(height: 25),

            // ── Bottom Action ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AVAILABILITY",
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    Text("$seats SEATS LEFT",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ],
                ),

                // ✅ FIX: Pass driverId and driverName to SearchRideScreen
                FutureBuilder<DriverProfile>(
                  future: _fetchDriverProfile(driverId),
                  builder: (context, snap) {
                    final String resolvedName =
                        snap.data?.name ?? ride['driverName']?.toString() ?? 'Driver';
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => SearchRideScreen(
                              selectedDriverId:   driverId,
                              selectedDriverName: resolvedName,
                              selectedRideId:     ride['rideId']?.toString() ?? '',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kCyan,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12)),
                      child: const Text("SELECT RIDE",
                          style: TextStyle(
                              color: kNavy, fontWeight: FontWeight.w900)),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverAvatar(String? imgUrl, ConnectionState state) {
    if (state == ConnectionState.waiting && imgUrl == null) {
      return Container(
        color: kCardNavy,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: kCyan),
          ),
        ),
      );
    }
    if (imgUrl != null && imgUrl.isNotEmpty) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        width: 58,
        height: 58,
        loadingBuilder: (ctx, child, prog) => prog == null
            ? child
            : Container(
          color: kCardNavy,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kCyan),
            ),
          ),
        ),
        errorBuilder: (ctx, e, s) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      color: kCardNavy,
      child: const Icon(Icons.person_rounded, color: kCyan, size: 32),
    );
  }

  Widget _shimmerName() {
    return Container(
      height: 14,
      width: 100,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _detailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: kCyan.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kCyan.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, color: kCyan, size: 11),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: kCyan, fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: kCyan.withOpacity(0.7), size: 12),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]),
    );
  }
}
