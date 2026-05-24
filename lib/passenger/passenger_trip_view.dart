import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ride_together/widgets/active_trip_chat.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

class PassengerTripView extends StatefulWidget {
  const PassengerTripView({super.key});

  @override
  State<PassengerTripView> createState() => _PassengerTripViewState();
}

class _PassengerTripViewState extends State<PassengerTripView> {
  late GoogleMapController mapController;
  LatLng driverLatLng = const LatLng(37.7749, -122.4194); // Mock location
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulation: Move the driver icon every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        driverLatLng = LatLng(driverLatLng.latitude + 0.0001, driverLatLng.longitude + 0.0001);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Matching your dark theme
      body: Stack(
        children: [
          // 1. Live Tracking Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: driverLatLng, zoom: 15),
            onMapCreated: (controller) => mapController = controller,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('driver'),
                position: driverLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            },
          ),

          // 2. SOS & Back Button
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black,
                  child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ),
                GestureDetector(
                  onTap: () => Share.share("I'm on a trip! Track me here: https://maps.app.goo.gl/share"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.shieldAlert, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Driver Info Card (Bottom Sheet)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const CircleAvatar(radius: 28, backgroundColor: Colors.white10, child: Icon(LucideIcons.user, color: Colors.white)),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Alex Johnson", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("Tesla Model 3 • EV-992", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.messageSquare, color: Colors.cyanAccent),
                        onPressed: () => _showChat(context),
                      ),
                      IconButton(icon: const Icon(LucideIcons.phone, color: Colors.greenAccent), onPressed: () {}),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(value: 0.6, color: Colors.cyanAccent, backgroundColor: Colors.white10),
                  const SizedBox(height: 10),
                  const Text("Driver is 4 mins away", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => const ActiveTripChat(),
    );
  }
}