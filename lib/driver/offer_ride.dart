import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/global/global_var.dart';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  static const Color kNavy     = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kCyan     = Color(0xFF00FFB3);
  static const Color kAccent   = Color(0xFF00D4FF);
  static const Color kError    = Color(0xFFFF4B2B);

  // ── Controllers ───────────────────────────────────
  final _vecNameController   = TextEditingController();
  final _vecPlateController  = TextEditingController();
  final _vecColorController  = TextEditingController();
  final _searchBarController = TextEditingController();
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  // ── Map State ─────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  String _pickupAddress    = "Tap map to set pickup";
  String _destAddress      = "Tap map to set destination";
  bool   _isSelectingPickup = true;
  final Set<Marker> _markers = {};
  double _currentSheetSize   = 0.50;

  // ── Form State ────────────────────────────────────
  DateTime?  _selectedDate;
  TimeOfDay? _selectedTime;
  int    _seats        = 1;
  double _fare         = 0.0;
  bool   _hasAC        = true;
  bool   _hasMusic     = true;
  String _selectedLuggage = "Medium";
  String _selectedPref    = "All";
  bool   _isPosting       = false;

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
    _vecNameController.dispose();
    _vecPlateController.dispose();
    _vecColorController.dispose();
    _searchBarController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ── Zoom to fit both markers ──────────────────────
  void _zoomToFit() {
    if (_mapController == null ||
        _pickupLatLng == null ||
        _destLatLng == null) return;

    LatLngBounds bounds;
    final p = _pickupLatLng!;
    final d = _destLatLng!;

    if (p.latitude > d.latitude && p.longitude > d.longitude) {
      bounds = LatLngBounds(southwest: d, northeast: p);
    } else if (p.longitude > d.longitude) {
      bounds = LatLngBounds(
        southwest: LatLng(p.latitude, d.longitude),
        northeast: LatLng(d.latitude, p.longitude),
      );
    } else if (p.latitude > d.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(d.latitude, p.longitude),
        northeast: LatLng(p.latitude, d.longitude),
      );
    } else {
      bounds = LatLngBounds(southwest: p, northeast: d);
    }
    _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // ── Location ──────────────────────────────────────
  Future<void> _requestLocationPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
              LatLng(pos.latitude, pos.longitude), 15));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _onMapTap(LatLng pos) async {
    try {
      final List<Placemark> placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isEmpty) return;

      final Placemark p  = placemarks.first;
      final String name  =
      (p.name != null && !p.name!.contains('+')) ? p.name! : "";
      final String street = p.thoroughfare ?? "";
      final String area   = p.subLocality  ?? "";
      final String city   = p.locality     ?? "";

      final List<String> parts = [
        if (name.isNotEmpty) name,
        if (street.isNotEmpty && street != name) street,
        if (area.isNotEmpty) area,
        if (city.isNotEmpty) city,
      ];
      final String addr =
      parts.isNotEmpty ? parts.join(", ") : "Unknown Location";

      setState(() {
        if (_isSelectingPickup) {
          _pickupLatLng    = pos;
          _pickupAddress   = addr;
          _isSelectingPickup = false;
        } else {
          _destLatLng    = pos;
          _destAddress   = addr;
          _calculateFare();
          _zoomToFit();
        }
        _updateMarkers();
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _updateMarkers() {
    _markers.clear();
    if (_pickupLatLng != null)
      _markers.add(Marker(
          markerId: const MarkerId('p'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueCyan)));
    if (_destLatLng != null)
      _markers.add(Marker(
          markerId: const MarkerId('d'),
          position: _destLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed)));
  }

  void _calculateFare() {
    if (_pickupLatLng != null && _destLatLng != null) {
      final double distanceMeters = Geolocator.distanceBetween(
          _pickupLatLng!.latitude,
          _pickupLatLng!.longitude,
          _destLatLng!.latitude,
          _destLatLng!.longitude);
      setState(() => _fare = (distanceMeters / 1000) * 45);
    }
  }

  // ════════════════════════════════════════════════════
  // ✅ FIXED SUBMIT RIDE — now saves driverId, driverName, rideId
  // ════════════════════════════════════════════════════
  Future<void> _submitRide() async {
    // ── Validation ────────────────────────────────────
    if (_pickupLatLng == null || _destLatLng == null) {
      _showSnack("Please set both pickup and destination.", kError);
      return;
    }
    if (_vecNameController.text.trim().isEmpty) {
      _showSnack("Please enter vehicle details.", kError);
      return;
    }
    if (_fare <= 0) {
      _showSnack("Please set a valid route to calculate fare.", kError);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack("You are not logged in.", kError);
        setState(() => _isPosting = false);
        return;
      }

      // ✅ Generate a proper push key as rideId
      final DatabaseReference rideRef = FirebaseDatabase.instance
          .ref()
          .child("available_rides")
          .push();
      final String rideId = rideRef.key!;

      // ✅ Get driver name from global var
      final String driverName =
      userName.isNotEmpty ? userName : "Driver";

      await rideRef.set({
        // ✅ CRITICAL FIELDS — these were missing before
        "rideId":     rideId,
        "driverId":   user.uid,        // ← was saved as "driverUid" before
        "driverName": driverName,

        // Route
        "pickup":      _pickupAddress,
        "destination": _destAddress,
        "pickupLat":   _pickupLatLng!.latitude,
        "pickupLng":   _pickupLatLng!.longitude,
        "destLat":     _destLatLng!.latitude,
        "destLng":     _destLatLng!.longitude,

        // Ride details
        "fare":         _fare.toStringAsFixed(0),
        "seats":        _seats,
        "date":         _selectedDate != null
            ? DateFormat('dd MMM yyyy').format(_selectedDate!)
            : "",
        "time":         _selectedTime != null
            ? _selectedTime!.format(context)
            : "",

        // Vehicle
        "vehicleName":  _vecNameController.text.trim(),
        "plateNumber":  _vecPlateController.text.trim(),
        "vehicleColor": _vecColorController.text.trim(),

        // Amenities & Preferences
        "ac":         _hasAC,
        "music":      _hasMusic,
        "luggage":    _selectedLuggage,
        "preference": _selectedPref,

        // Meta
        "status":    "active",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });

      _showSnack("Ride posted successfully! 🎉", kCyan);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Submit ride error: $e");
      _showSnack("Failed to post ride: $e", kError);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: kNavy,
      body: Stack(
        children: [
          // 1. Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
                target: LatLng(33.9989, 71.5341), zoom: 13),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled:       true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onTap:   _onMapTap,
          ),

          // 2. Top Search Bar & Back Button
          Positioned(
            top:   50,
            left:  15,
            right: 15,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: kNavy,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
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
                      onSubmitted: (val) async {
                        try {
                          final List<Location> locs =
                          await locationFromAddress(val);
                          if (locs.isNotEmpty) {
                            final LatLng target = LatLng(
                                locs.first.latitude,
                                locs.first.longitude);
                            _onMapTap(target);
                            _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(target, 15));
                            _searchBarController.clear();
                          }
                        } catch (e) {
                          _showSnack("Location not found.", kError);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: _isSelectingPickup
                            ? "Search Pickup..."
                            : "Search Dropoff...",
                        hintStyle: const TextStyle(
                            color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. My Location Button
          Positioned(
            bottom: (h * _currentSheetSize) + 15,
            right:  16,
            child: _circleBtn(Icons.my_location, _getCurrentLocation),
          ),

          // 4. Draggable Bottom Sheet
          DraggableScrollableSheet(
            controller:      _sheetController,
            initialChildSize: 0.50,
            minChildSize:     0.25,
            maxChildSize:     0.95,
            snap:             true,
            builder: (ctx, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: kNavy,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.black87, blurRadius: 20)
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width:  40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildAddressSelector(),
                    _divider(),

                    _sectionHeader("VEHICLE & LOGISTICS",
                        Icons.directions_car),
                    const SizedBox(height: 12),
                    _buildVehicleInfo(),
                    const SizedBox(height: 12),
                    _buildDateTimeRow(),
                    _divider(),

                    _sectionHeader("AMENITIES", Icons.star_border),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _toggleOption("❄️ AC", _hasAC,
                                  () => setState(() => _hasAC = !_hasAC))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _toggleOption("🎵 Music", _hasMusic,
                                  () => setState(() => _hasMusic = !_hasMusic))),
                    ]),
                    _divider(),

                    _sectionHeader("LUGGAGE CAPACITY", Icons.luggage),
                    const SizedBox(height: 12),
                    Row(children: [
                      _choiceChip("Small",  "💼",
                          _selectedLuggage == "Small",
                              () => setState(() => _selectedLuggage = "Small")),
                      const SizedBox(width: 8),
                      _choiceChip("Medium", "🧳",
                          _selectedLuggage == "Medium",
                              () => setState(() => _selectedLuggage = "Medium")),
                      const SizedBox(width: 8),
                      _choiceChip("Large",  "📦",
                          _selectedLuggage == "Large",
                              () => setState(() => _selectedLuggage = "Large")),
                    ]),
                    _divider(),

                    _sectionHeader(
                        "GENDER PREFERENCE", Icons.people_outline),
                    const SizedBox(height: 12),
                    Row(children: [
                      _choiceChip("Everyone", "🌍",
                          _selectedPref == "All",
                              () => setState(() => _selectedPref = "All")),
                      const SizedBox(width: 8),
                      _choiceChip("Females", "👩",
                          _selectedPref == "Females",
                              () => setState(() => _selectedPref = "Females")),
                      const SizedBox(width: 8),
                      _choiceChip("Males", "👨",
                          _selectedPref == "Males",
                              () => setState(() => _selectedPref = "Males")),
                    ]),
                    _divider(),

                    _buildSeatCounter(),
                    const SizedBox(height: 25),
                    _buildFareSubmit(),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // UI HELPERS
  // ════════════════════════════════════════════════════

  Widget _buildAddressSelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: kCardNavy, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        _addrRow(kCyan, "Pickup", _pickupAddress,
            _isSelectingPickup,
                () => setState(() => _isSelectingPickup = true)),
        const Divider(color: Colors.white10, height: 25),
        _addrRow(Colors.redAccent, "Dropoff", _destAddress,
            !_isSelectingPickup,
                () => setState(() => _isSelectingPickup = false)),
      ]),
    );
  }

  Widget _addrRow(Color col, String label, String val,
      bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Icon(
            active
                ? Icons.radio_button_checked
                : Icons.circle,
            color: col,
            size: 18),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: active ? col : Colors.white24,
                        fontSize:   10,
                        fontWeight: FontWeight.bold)),
                Text(val,
                    style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
      ]),
    );
  }

  Widget _buildVehicleInfo() {
    return Column(children: [
      _proInput(_vecNameController, "Vehicle Model",
          Icons.directions_car, kCyan),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _proInput(_vecPlateController, "Plate No.",
                Icons.badge, kAccent)),
        const SizedBox(width: 10),
        Expanded(
            child: _proInput(_vecColorController, "Color",
                Icons.palette, Colors.orange)),
      ]),
    ]);
  }

  Widget _proInput(TextEditingController ctrl, String hint,
      IconData icon, Color col) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: col, size: 18),
        filled:     true,
        fillColor:  kCardNavy,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDateTimeRow() {
    return Row(children: [
      Expanded(
          child: _chip(
              _selectedDate == null
                  ? "Set Date"
                  : DateFormat('dd MMM').format(_selectedDate!),
              _selectDate)),
      const SizedBox(width: 12),
      Expanded(
          child: _chip(
              _selectedTime == null
                  ? "Set Time"
                  : _selectedTime!.format(context),
              _selectTime)),
    ]);
  }

  Widget _chip(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: kCardNavy,
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildSeatCounter() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Available Seats",
              style: TextStyle(color: Colors.white)),
          Row(children: [
            IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.redAccent),
                onPressed: () =>
                    setState(() { if (_seats > 1) _seats--; })),
            Text("$_seats",
                style: const TextStyle(
                    color:      kCyan,
                    fontSize:   18,
                    fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: kCyan),
                onPressed: () =>
                    setState(() { if (_seats < 6) _seats++; })),
          ]),
        ]);
  }

  Widget _buildFareSubmit() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: kCardNavy,
          borderRadius: BorderRadius.circular(15)),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ESTIMATED FARE",
                      style: TextStyle(
                          color:      Colors.white38,
                          fontSize:   10,
                          fontWeight: FontWeight.bold)),
                  Text("PKR ${_fare.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color:      kCyan,
                          fontSize:   22,
                          fontWeight: FontWeight.bold)),
                ]),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kCyan,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _isPosting ? null : _submitRide,
              child: _isPosting
                  ? const SizedBox(
                  width:  20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kNavy))
                  : const Text("POST RIDE",
                  style: TextStyle(
                      color:      kNavy,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
    );
  }

  Widget _toggleOption(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? kCyan.withOpacity(0.1) : kCardNavy,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? kCyan : Colors.white12),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: isSelected ? kCyan : Colors.white60,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _choiceChip(String label, String emoji,
      bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kCyan.withOpacity(0.1) : kCardNavy,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? kCyan : Colors.white12),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: isSelected ? kCyan : Colors.white38,
                    fontSize:   10,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: kCyan, size: 16),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color:      kCyan,
              fontSize:   10,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _divider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 15),
      child: Divider(color: Colors.white10));

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          width:  45,
          height: 45,
          decoration: const BoxDecoration(
              color: kNavy, shape: BoxShape.circle),
          child: Icon(icon, color: kCyan, size: 20)),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now(),
      firstDate:   DateTime.now(),
      lastDate:    DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary:   kCyan,
              onPrimary: kNavy,
              surface:   kCardNavy,
              onSurface: Colors.white),
          dialogBackgroundColor: kNavy,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary:   kCyan,
              onPrimary: kNavy,
              surface:   kCardNavy,
              onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
}


