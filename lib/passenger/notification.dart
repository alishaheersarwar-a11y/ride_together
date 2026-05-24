import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("Clear All", style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentCyan.withOpacity(0.5)),
                      ),
                      child: const Text(
                        "3 NEW",
                        style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Updates since your last ride",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Notification List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildNotificationTile(
                      title: "New Ride Request",
                      message: "Sarah is looking for a ride (2.4 km away). Tap to accept.",
                      time: "2 mins ago",
                      icon: Icons.directions_car_filled_rounded,
                      iconColor: Colors.blueAccent,
                      isUnread: true,
                    ),
                    _buildNotificationTile(
                      title: "Payment Received",
                      message: "Rs 250.00 has been added to your wallet for the last trip.",
                      time: "1 hour ago",
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: Colors.greenAccent,
                      isUnread: true,
                    ),
                    _buildNotificationTile(
                      title: "Terms Updated",
                      message: "We have updated our Kilometric Rates. Tap to view changes.",
                      time: "Yesterday",
                      icon: Icons.gavel_rounded,
                      iconColor: Colors.amberAccent,
                      isUnread: true,
                    ),
                    _buildNotificationTile(
                      title: "Account Verified",
                      message: "Your driver documents have been successfully verified.",
                      time: "2 days ago",
                      icon: Icons.verified_user_rounded,
                      iconColor: Colors.cyanAccent,
                      isUnread: false,
                    ),
                    _buildNotificationTile(
                      title: "Weekly Summary",
                      message: "You completed 15 rides this week. Great job!",
                      time: "3 days ago",
                      icon: Icons.insights_rounded,
                      iconColor: Colors.purpleAccent,
                      isUnread: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String message,
    required String time,
    required IconData icon,
    required Color iconColor,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C212B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? iconColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          if (isUnread)
            Positioned(
              right: 15,
              top: 15,
              child: CircleAvatar(radius: 4, backgroundColor: iconColor),
            ),
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                message,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
              ),
            ),
            onTap: () {
              // Handle Notification Click
            },
          ),
        ],
      ),
    );
  }
}