import 'package:flutter/material.dart';
import 'package:ride_together/driver/driverprofile.dart';
import 'package:ride_together/driver/wallet_driver.dart';

const Color kNavy = Color(0xFF1A1A2E);
const Color kCardNavy = Color(0xFF16213E);
const Color kCyan = Color(0xFF00FFB3);
const Color kDeep = Color(0xFF0F3460);

class DriverSettings extends StatefulWidget {
  const DriverSettings({super.key});

  @override
  State<DriverSettings> createState() => _DriverSettingsState();
}

class _DriverSettingsState extends State<DriverSettings> {
  bool _pushNotifications = true;
  bool _emailUpdates = false;

  // --- LOGIC: HANDLE ACCOUNT DELETION ---
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kCardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.redAccent.withOpacity(0.2))),
          title: const Text("Delete Account?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            "This action is permanent. All your ride history, profile data, and earnings will be lost forever.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // 1. Close Dialog
                Navigator.pop(context);

                // 2. Perform Deletion (Add your Backend/Firebase logic here)
                _performAccountDeletion();
              },
              child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _performAccountDeletion() {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: kCyan)),
    );

    // Simulate Network Delay (In real app, call your API/Firebase here)
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading indicator

      // IMPORTANT: Clear the navigation stack and go back to Login/Landing Page
      // Make sure you have a route named '/login' or use the LandingPage widget directly
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account successfully deleted"), backgroundColor: Colors.redAccent),
      );
    });
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
        title: const Text("Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionHeader("ACCOUNT SETTINGS"),
          _settingTile(Icons.person_outline, "Personal Information", "Edit your name, phone, and address", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const DriverProfileScreen()));
          }),
          _settingTile(Icons.payment_rounded, "Payment Methods", "Manage your cards and digital wallets", onTap: () {Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletDriver()));}),

          const SizedBox(height: 30),

          _sectionHeader("PREFERENCES"),
          _toggleTile(Icons.notifications_none_rounded, "Push Notifications", _pushNotifications, (val) {
            setState(() => _pushNotifications = val);
          }),
          _toggleTile(Icons.alternate_email_rounded, "Email Updates", _emailUpdates, (val) {
            setState(() => _emailUpdates = val);
          }),

          const SizedBox(height: 40),

          _sectionHeader("DANGER ZONE"),
          // UPDATED: Now calls the Delete Confirmation logic
          _settingTile(
            Icons.no_accounts_outlined,
            "Deactivate Account",
            "Temporarily disable your profile",
            color: Colors.redAccent,
            onTap: _showDeleteConfirmation, // Trigger Dialog
          ),

          const SizedBox(height: 40),

          const Center(
            child: Text("Ride Together v1.0.42", style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 12),
      child: Text(title, style: const TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  // Updated to include VoidCallback onTap
  Widget _settingTile(IconData icon, String title, String subtitle, {Color color = Colors.white, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap, // Connected here
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color == Colors.white ? kCyan : color, size: 22),
        ),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
      ),
    );
  }

  Widget _toggleTile(IconData icon, String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: kCyan, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        trailing: Switch.adaptive(
          value: value,
          activeColor: kCyan,
          onChanged: onChanged,
        ),
      ),
    );
  }
}