import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/passenger/my_ride_status.dart';

class RideDetailScreen extends StatefulWidget {
  final Map ride;
  final String pickup;
  final String destination;
  final String date;
  final String time;
  final String passengers;
  final String passengerName;
  final String genderPref;

  const RideDetailScreen({
    super.key,
    required this.ride,
    required this.pickup,
    required this.destination,
    required this.date,
    required this.time,
    required this.passengers,
    required this.passengerName,
    required this.genderPref,
  });

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  static const Color bgTop   = Color(0xFF1A1A2E);
  static const Color accent  = Color(0xFF00FFB3);
  static const Color primary = Color(0xFF00D4FF);
  static const Color kDeep   = Color(0xFF16213E);
  static const Color kError  = Color(0xFFFF4B2B);

  bool _isBooking = false;

  // ════════════════════════════════════════════════════════════════════
  // BOOK RIDE
  // Saves to: ride_requests/{requestId}
  // Also sends: notifications/{driverId}
  // ════════════════════════════════════════════════════════════════════
  Future<void> _bookRide() async {
    setState(() => _isBooking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Authentication failed. Please login.";

      final String driverId = widget.ride['driverId']?.toString() ?? '';
      final String rideId   = widget.ride['rideId']?.toString()   ?? '';

      debugPrint("--- BOOKING ---");
      debugPrint("driverId : $driverId");
      debugPrint("rideId   : $rideId");

      if (driverId.isEmpty) {
        throw "Invalid driver. Please go back and select a ride.";
      }

      // ── Create request node ─────────────────────────────────────────
      final DatabaseReference requestRef =
      FirebaseDatabase.instance.ref().child('ride_requests').push();
      final String requestId = requestRef.key!;

      // ✅ Both field name sets saved so RideRequestsScreen can read either
      final Map<String, dynamic> requestData = {
        'requestId':          requestId,
        'passengerId':        user.uid,
        'passengerName':      widget.passengerName,
        'passengerPhone':     user.phoneNumber ?? "N/A",
        'genderPreference':   widget.genderPref,
        'rideId':             rideId,
        'driverId':           driverId,

        // ── address fields (used by RideRequestsScreen) ──────────────
        // The existing RideRequestsScreen reads 'pickup' and 'destination'
        // The new DriverRideRequestsScreen reads 'pickupAddress' / 'destinationAddress'
        // We save BOTH so either screen works without changes.
        'pickup':              widget.pickup,
        'destination':         widget.destination,
        'pickupAddress':       widget.pickup,
        'destinationAddress':  widget.destination,

        'pickupLat':          widget.ride['pickupLat']  ?? 0.0,
        'pickupLng':          widget.ride['pickupLng']  ?? 0.0,
        'destLat':            widget.ride['destLat']    ?? 0.0,
        'destLng':            widget.ride['destLng']    ?? 0.0,
        'fare':               widget.ride['fare'],
        'seats':              widget.passengers,
        'date':               widget.date,
        'time':               widget.time,
        'status':             'pending',
        'timestamp':          ServerValue.timestamp,
      };

      await requestRef.set(requestData);

      // ── Notify driver ───────────────────────────────────────────────
      await FirebaseDatabase.instance
          .ref()
          .child('notifications')
          .child(driverId)
          .push()
          .set({
        'title':     'New Ride Request! 🚗',
        'body':
        '${widget.passengerName} wants a ride to ${widget.destination}',
        'requestId': requestId,
        'status':    'new',
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        _showSnack("Request sent! Waiting for driver...", accent);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MyRideStatusScreen(
              requestId:  requestId,
              driverName: widget.ride['driverName']?.toString() ?? 'Driver',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isBooking = false);
      _showSnack(e.toString(), kError);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
      Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double price =
        double.tryParse(widget.ride['fare'].toString()) ?? 0.0;
    final int seats = int.tryParse(widget.passengers) ?? 1;
    final double total = price * seats;

    return Scaffold(
      backgroundColor: bgTop,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("TRIP ROUTE"),
                  _buildRouteCard(),
                  const SizedBox(height: 20),
                  _buildSectionLabel("PASSENGER DETAILS"),
                  _buildPassengerInfoCard(),
                  const SizedBox(height: 20),
                  _buildSectionLabel("PAYMENT"),
                  _buildFareCard(price, seats, total),
                  const SizedBox(height: 40),
                  _buildConfirmButton(),
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
      padding: const EdgeInsets.only(top: 55, bottom: 20, left: 10, right: 10),
      decoration: const BoxDecoration(
        color: kDeep,
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              "RIDE DETAIL",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(label,
          style: GoogleFonts.poppins(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5)),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kDeep,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _routeItem(Icons.my_location, accent, "Pickup", widget.pickup),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  width: 1.5, height: 25, color: Colors.white10),
            ),
          ),
          _routeItem(
              Icons.location_on, primary, "Destination", widget.destination),
        ],
      ),
    );
  }

  Widget _routeItem(
      IconData icon, Color color, String title, String val) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
              Text(val,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPassengerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: kDeep, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          _infoRow("Passenger Name", widget.passengerName,
              Icons.person_pin_rounded),
          const Divider(color: Colors.white10, height: 30),
          Row(
            children: [
              Expanded(
                  child: _infoRow(
                      "Gender", widget.genderPref, Icons.wc_rounded)),
              Expanded(
                  child: _infoRow(
                      "Seats",
                      "${widget.passengers} seat(s)",
                      Icons.airline_seat_recline_extra_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(icon, color: primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 9)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareCard(double price, int seats, double total) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [kDeep, Color(0xFF1F2D50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ESTIMATED TOTAL",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text("PKR ${total.toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
            ],
          ),
          Icon(Icons.payments_outlined,
              color: accent.withOpacity(0.5), size: 35),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: ElevatedButton(
        onPressed: _isBooking ? null : _bookRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          minimumSize: const Size(double.infinity, 65),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isBooking
            ? const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
                color: bgTop, strokeWidth: 3))
            : Text(
          "CONFIRM & SEND REQUEST",
          style: GoogleFonts.poppins(
              color: bgTop,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.5),
        ),
      ),
    );
  }
}

