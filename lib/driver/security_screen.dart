import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Theme Colors ---
const Color kNavy = Color(0xFF1A1A2E);
const Color kCardNavy = Color(0xFF16213E);
const Color kCyan = Color(0xFF00FFB3);
const Color kRed = Color(0xFFFF4B5C);
const Color kGold = Color(0xFFFFD700);

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _isRecording = false;
  final String _safetyPin = "4829"; // This would dynamic from your DB

  // --- Actions ---
  void _callEmergency() async {
    final Uri url = Uri.parse('tel:911');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _shareLiveLocation() {
    Share.share("I'm on a ride! Follow my live location here: https://maps.google.com/?q=ride_location");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kCyan, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Safety Center",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. EMERGENCY SOS CARD
            _buildSOSCard(),

            const SizedBox(height: 25),
            const Text("ACTIVE PROTECTION",
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 15),

            // 2. SAFETY PIN & AUDIO RECORDING ROW
            Row(
              children: [
                Expanded(child: _buildInfoCard("Safety PIN", _safetyPin, Icons.vibration, kCyan)),
                const SizedBox(width: 15),
                Expanded(child: _buildAudioRecordingCard()),
              ],
            ),

            const SizedBox(height: 25),
            const Text("SAFETY TOOLS",
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 15),

            // 3. FEATURE LIST
            _buildSafetyTile(
              icon: Icons.people_alt_outlined,
              title: "Trusted Contacts",
              subtitle: "Share ride status with family automatically",
              onTap: () => _showTrustedContactsDialog(),
            ),
            _buildSafetyTile(
              icon: Icons.share_location_rounded,
              title: "Share Trip Details",
              subtitle: "Send a live tracking link via WhatsApp/SMS",
              onTap: _shareLiveLocation,
            ),
            _buildSafetyTile(
              icon: Icons.support_agent_rounded,
              title: "24/7 Safety Support",
              subtitle: "Talk to our dedicated safety agents",
              onTap: () => _callEmergency(), // Replace with support number
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSOSCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kRed, kRed.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kRed.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Emergency SOS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Instantly notify local police", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _callEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text("HELP", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardNavy, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildAudioRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRecording ? kRed.withOpacity(0.1) : kCardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isRecording ? kRed : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.mic_none_rounded, color: _isRecording ? kRed : Colors.white38),
              if (_isRecording)
                const Icon(Icons.circle, color: kRed, size: 10), // Recording indicator
            ],
          ),
          const SizedBox(height: 12),
          const Text("Audio Recording", style: TextStyle(color: Colors.white38, fontSize: 12)),
          Switch.adaptive(
            value: _isRecording,
            activeColor: kRed,
            onChanged: (val) {
              setState(() => _isRecording = val);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(val ? "Recording Started for Safety" : "Recording Stopped"),
                backgroundColor: val ? kRed : kNavy,
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kCardNavy, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: kCyan, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
      ),
    );
  }

  // --- Dialogs ---

  void _showTrustedContactsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Trusted Contacts", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildSafetyTile(icon: Icons.add, title: "Add New Contact", subtitle: "Notify them when trip starts", onTap: () {}),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: kCyan, minimumSize: const Size(double.infinity, 50)),
              child: const Text("CLOSE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _showInsuranceDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardNavy,
        title: const Text("Insurance Verified", style: TextStyle(color: kCyan)),
        content: const Text("Your trip is covered up to \$100,000 for medical and accidental damages. Policy #RT-99283-X",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: kCyan)))
        ],
      ),
    );
  }
}