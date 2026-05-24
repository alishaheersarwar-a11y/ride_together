import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text("FAQs", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _faqTile("How do I find and Book a ride?", "Enter your destination in the search bar to see available drivers. Select a ride that fits your schedule and tap 'Request Join' to notify the driver."),
          _faqTile("How is the ride fare calculated?", "To ensure fair cost-sharing, fares are fixed at Rs 50 per kilometer. The total is calculated automatically via GPS based on the exact distance of your trip."),
          _faqTile("What if the driver doesn't show up?", "If a driver is more than 10 minutes late, you can cancel the ride without penalty. Please report the 'No Show' via the support tab so we can take action."),
          _faqTile("How does the app ensure my safety?", "Every driver undergoes identity and document verification. You can also share your live trip location with friends or family and use the SOS button for emergencies."),
        ],
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 14, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(answer, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}