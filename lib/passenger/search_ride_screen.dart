import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:ride_together/passenger/ride_details_screen.dart';

class SearchRideScreen extends StatefulWidget {
  // ✅ All three passed from AvailableRidesScreen
  final String? selectedDriverId;
  final String? selectedDriverName;
  final String? selectedRideId;

  const SearchRideScreen({
    super.key,
    this.selectedDriverId,
    this.selectedDriverName,
    this.selectedRideId,
  });

  @override
  State<SearchRideScreen> createState() => _SearchRideScreenState();
}

class _SearchRideScreenState extends State<SearchRideScreen> {
  static const Color kNavy     = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kCyan     = Color(0xFF00FFB3);

  final _passengerNameController = TextEditingController();
  final _searchBarController     = TextEditingController();
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  GoogleMapController? _mapController;
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  String _pickupAddress = "Tap map to set pickup";
  String _destAddress   = "Tap map to set destination";
  bool _isSelectingPickup = true;
  final Set<Marker> _markers = {};
  double _currentSheetSize = 0.45;

  int    _seatsRequired = 1;
  String _genderPref    = "Both";

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _sheetController.addListener(() {
      if (mounted) setState(() => _currentSheetSize = _sheetController.size);
    });
  }

  @override
  void dispose() {
    _passengerNameController.dispose();
    _searchBarController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // FIND RIDES — builds rideData and navigates to RideDetailScreen
  // ════════════════════════════════════════════════════════════════════
  void _onFindRides() {
    if (_pickupLatLng == null || _destLatLng == null) {
      _showErrorSnackBar("Please select both locations on the map.");
      return;
    }
    if (_passengerNameController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter your name.");
      return;
    }

    // ── Fare calculation ──────────────────────────────────────────────
    final double distanceInMeters = Geolocator.distanceBetween(
      _pickupLatLng!.latitude, _pickupLatLng!.longitude,
      _destLatLng!.latitude,   _destLatLng!.longitude,
    );
    double calculatedFare =
    ((distanceInMeters / 1000) * 60).roundToDouble();

    // ── Validate driver ID ────────────────────────────────────────────
    final String driverId = widget.selectedDriverId ?? '';
    if (driverId.isEmpty) {
      _showErrorSnackBar(
          "No driver selected. Please go back and pick a ride.");
      return;
    }

    // ✅ rideData now carries rideId so RideDetailScreen can pass it on
    final Map<String, dynamic> rideData = {
      'rideId':      widget.selectedRideId ?? '',
      'driverId':    driverId,
      'driverName':  widget.selectedDriverName ?? 'Driver',
      'fare':        calculatedFare,
      'pickupLat':   _pickupLatLng!.latitude,
      'pickupLng':   _pickupLatLng!.longitude,
      'destLat':     _destLatLng!.latitude,
      'destLng':     _destLatLng!.longitude,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => RideDetailScreen(
          ride:          rideData,
          pickup:        _pickupAddress,
          destination:   _destAddress,
          date:          DateFormat('dd MMM yyyy').format(DateTime.now()),
          time:          DateFormat('hh:mm a').format(DateTime.now()),
          passengers:    _seatsRequired.toString(),
          passengerName: _passengerNameController.text.trim(),
          genderPref:    _genderPref,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final current = LatLng(pos.latitude, pos.longitude);
      _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(current, 15));
      _onMapTap(current);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _onMapTap(LatLng pos) async {
    try {
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String addr = "Unnamed Location";
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        addr = "${p.street}, ${p.subLocality}, ${p.locality}";
      }
      setState(() {
        if (_isSelectingPickup) {
          _pickupLatLng   = pos;
          _pickupAddress  = addr;
          _isSelectingPickup = false;
        } else {
          _destLatLng    = pos;
          _destAddress   = addr;
          _zoomToFit();
        }
        _updateMarkers();
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _zoomToFit() {
    if (_mapController == null ||
        _pickupLatLng == null ||
        _destLatLng == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickupLatLng!.latitude < _destLatLng!.latitude
            ? _pickupLatLng!.latitude
            : _destLatLng!.latitude,
        _pickupLatLng!.longitude < _destLatLng!.longitude
            ? _pickupLatLng!.longitude
            : _destLatLng!.longitude,
      ),
      northeast: LatLng(
        _pickupLatLng!.latitude > _destLatLng!.latitude
            ? _pickupLatLng!.latitude
            : _destLatLng!.latitude,
        _pickupLatLng!.longitude > _destLatLng!.longitude
            ? _pickupLatLng!.longitude
            : _destLatLng!.longitude,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  void _updateMarkers() {
    _markers.clear();
    if (_pickupLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('p'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan),
      ));
    }
    if (_destLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('d'),
        position: _destLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: kNavy,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
                target: LatLng(30.3753, 69.3451), zoom: 5),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onTap: _onMapTap,
            zoomControlsEnabled: false,
          ),

          // ── Top Search Bar ───────────────────────────────────────────
          Positioned(
            top: 50, left: 15, right: 15,
            child: Row(children: [
              CircleAvatar(
                backgroundColor: kNavy,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: kNavy,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10)
                    ],
                  ),
                  child: TextField(
                    controller: _searchBarController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isSelectingPickup
                          ? "Set Pickup on map..."
                          : "Set Destination on map...",
                      hintStyle: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // ── Driver banner (shows who was selected) ───────────────────
          if (widget.selectedDriverName != null)
            Positioned(
              top: 110, left: 15, right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCyan.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.person_pin_circle,
                      color: kCyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Booking with: ${widget.selectedDriverName}",
                      style: const TextStyle(
                          color: kCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),

          // ── My Location button ───────────────────────────────────────
          Positioned(
            bottom: (h * _currentSheetSize) + 15,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: kNavy,
              child:
              const Icon(Icons.my_location, color: kCyan),
              onPressed: _getCurrentLocation,
            ),
          ),

          // ── Bottom Sheet Form ────────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.90,
            builder: (ctx, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: kNavy,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 20)
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLocationCard(),
                    _divider(),
                    _sectionHeader("PASSENGER NAME", Icons.badge),
                    const SizedBox(height: 10),
                    _buildNameInput(),
                    _divider(),
                    _sectionHeader("PREFERENCES", Icons.tune),
                    const SizedBox(height: 15),
                    _buildGenderSelector(),
                    const SizedBox(height: 15),
                    _buildSeatCounter(),
                    const SizedBox(height: 30),
                    _buildConfirmButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: kCardNavy, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        _addrRow(kCyan, "PICKUP", _pickupAddress, _isSelectingPickup,
                () => setState(() => _isSelectingPickup = true)),
        const Divider(color: Colors.white10, height: 20),
        _addrRow(Colors.redAccent, "DROP-OFF", _destAddress,
            !_isSelectingPickup,
                () => setState(() => _isSelectingPickup = false)),
      ]),
    );
  }

  Widget _addrRow(Color col, String label, String val, bool active,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Icon(
            active
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: col,
            size: 16),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: active ? col : Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                Text(val,
                    style: TextStyle(
                        color: active ? Colors.white : Colors.white38,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
      ]),
    );
  }

  Widget _buildNameInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
          color: kCardNavy, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _passengerNameController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
            hintText: "Enter your name",
            hintStyle:
            TextStyle(color: Colors.white24, fontSize: 13),
            border: InputBorder.none),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Row(children: [
      _genderChip("Both"),
      const SizedBox(width: 10),
      _genderChip("Male"),
      const SizedBox(width: 10),
      _genderChip("Female"),
    ]);
  }

  Widget _genderChip(String label) {
    final bool isSel = _genderPref == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _genderPref = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
            isSel ? kCyan.withOpacity(0.1) : kCardNavy,
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: isSel ? kCyan : Colors.white10),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isSel ? kCyan : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSeatCounter() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Seats Required",
              style:
              TextStyle(color: Colors.white70, fontSize: 14)),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: kCyan),
              onPressed: () => setState(() {
                if (_seatsRequired > 1) _seatsRequired--;
              }),
            ),
            Text("$_seatsRequired",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: kCyan),
              onPressed: () => setState(() {
                if (_seatsRequired < 4) _seatsRequired++;
              }),
            ),
          ])
        ]);
  }

  Widget _buildConfirmButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: kCyan,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: _onFindRides,
      child: const Text("YOUR RIDE DETAILS",
          style: TextStyle(
              color: kNavy, fontWeight: FontWeight.w900)),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: kCyan, size: 16),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color: kCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _divider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 15),
      child: Divider(color: Colors.white10));
}

