import 'package:flutter/material.dart';
import 'package:ride_together/driver/ride_request_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_together/driver/faq_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // Action: Open Email App
  Future<void> _launchEmail() async {
    final Uri url = Uri.parse('mailto:alishaheersarwar@gmail.com?subject=Driver Support Request');
    if (!await launchUrl(url)) throw 'Could not launch $url';
  }

  // Action: Open Dialer
  Future<void> _launchPhone() async {
    final Uri url = Uri.parse('tel:+923196271342');
    if (!await launchUrl(url)) throw 'Could not launch $url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text("Help & Support", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text("How can we help you?",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            // 1. FAQs
            _supportButton(context, Icons.question_answer_outlined, "Frequently Asked Questions", "Find quick answers", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const FAQScreen()));
            }),

            // 2. Live Chat
            _supportButton(context, Icons.chat_bubble_outline, "Live Chat", "Talk to our support team", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const RideRequestsScreen()));
            }),

            // 3. Email Us (UPGRADED: NOW CLICKABLE)
            _supportButton(
                context,
                Icons.mail_outline,
                "Email Us On",
                "alishaheersarwar@gmail.com",
                onTap: _launchEmail // Calls the email function
            ),

            // 4. Contact Us (UPGRADED: NOW CLICKABLE)
            _supportButton(
                context,
                Icons.phone_outlined,
                "Contact Us On",
                "+923196271342",
                onTap: _launchPhone // Calls the dialer function
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportButton(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ListTile(
        onTap: onTap,
        tileColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        leading: Icon(icon, color: const Color(0xFF00D4FF)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        // Arrow will now show because onTap is no longer null for any button
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14)
            : null,
      ),
    );
  }
}
