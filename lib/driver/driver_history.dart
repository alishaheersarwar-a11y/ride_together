import 'package:flutter/material.dart';

// --- THE DATA MODEL (Original Data Structure) ---
class RideRecord {
  final String date;
  final String origin;
  final String destination;
  final String driverName;
  final double km; // Kilometers traveled

  RideRecord({
    required this.date,
    required this.origin,
    required this.destination,
    required this.driverName,
    required this.km,
  });

  // Automatically calculate price based on Rs 50/km logic
  String get totalFare => "Rs ${(km * 50).toStringAsFixed(0)}";
}

class PassengerHistory extends StatefulWidget {
  const PassengerHistory({super.key});

  @override
  State<PassengerHistory> createState() => _PassengerHistoryState();
}

class _PassengerHistoryState extends State<PassengerHistory> {
  // --- REAL DATA LIST ---
  // Leave this empty [] to see the "No Rides Yet" screen.
  // Add items here to see the "History" list.
  List<RideRecord> myRideHistory = [
    // Example:
    // RideRecord(date: "Today, 12:45 PM", origin: "Model Town", destination: "DHA Phase 6", driverName: "Zeeshan", km: 12.5),
  ];

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF0F1219);
    const Color bgDarker = Color(0xFF07090C);
    const Color accentCyan = Color(0xFF00E5FF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Trip History",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, bgDarker],
          ),
        ),
        child: SafeArea(
          child: myRideHistory.isEmpty
              ? _buildEmptyState(accentCyan)
              : _buildRideList(accentCyan),
        ),
      ),
    );
  }

  // --- UI: EMPTY STATE ---
  Widget _buildEmptyState(Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large stylized icon
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_filled_outlined, size: 80, color: accent.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Rides Yet",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              "Your completed trips and shared rides will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI: RIDE LIST ---
  Widget _buildRideList(Color accent) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: myRideHistory.length,
      itemBuilder: (context, index) {
        return _buildRideCard(myRideHistory[index], accent);
      },
    );
  }

  Widget _buildRideCard(RideRecord ride, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C212B), // Dark Glass Card
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Top Row: Date and Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ride.date, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(ride.totalFare, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: Colors.white10),
          ),
          // Center: Route Visualization
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, color: Colors.blueAccent, size: 12),
                  Container(width: 1, height: 30, color: Colors.white12),
                  const Icon(Icons.location_on, color: Colors.redAccent, size: 14),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.origin, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 25),
                    Text(ride.destination, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bottom: Driver info and status
          Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white12,
                child: Icon(Icons.person, size: 14, color: Colors.white60),
              ),
              const SizedBox(width: 8),
              Text(ride.driverName, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("COMPLETED", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}