import 'package:flutter/material.dart';

class LegalTerms extends StatelessWidget {
  const LegalTerms({super.key});

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
          "Legal & Terms",
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildHeaderSection(accentCyan),
                const SizedBox(height: 30),

                _buildLegalTile(
                  context,
                  title: "Terms of Service",
                  subtitle: "Rules and usage agreements",
                  icon: Icons.article_rounded,
                  iconColor: Colors.blueAccent,
                ),
                _buildLegalTile(
                  context,
                  title: "Privacy Policy",
                  subtitle: "Data protection and GPS usage",
                  icon: Icons.shield_rounded,
                  iconColor: Colors.greenAccent,
                ),

                // HIGHLIGHTED OPTION
                _buildLegalTile(
                  context,
                  title: "Cost-Sharing & Rates",
                  subtitle: "Detailed per-kilometer fee structure",
                  icon: Icons.monetization_on_rounded,
                  iconColor: Colors.amberAccent,
                ),

                _buildLegalTile(
                  context,
                  title: "Community Guidelines",
                  subtitle: "Safety and behavior expectations",
                  icon: Icons.groups_rounded,
                  iconColor: Colors.purpleAccent,
                ),
                _buildLegalTile(
                  context,
                  title: "Zero Tolerance Policy",
                  subtitle: "Substance and safety restrictions",
                  icon: Icons.report_problem_rounded,
                  iconColor: Colors.redAccent,
                ),
                _buildLegalTile(
                  context,
                  title: "Open Source Licenses",
                  subtitle: "Third-party legal libraries",
                  icon: Icons.code_rounded,
                  iconColor: Colors.grey,
                ),

                const SizedBox(height: 40),
                Center(
                  child: Text(
                    "App Version 1.0.4",
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Color accentColor) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          "Trust & Transparency",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          "We value your security and fair pricing.",
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLegalTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color iconColor,
        bool isSpecial = false,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C212B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpecial ? Colors.amberAccent.withOpacity(0.6) : Colors.white.withOpacity(0.05),
          width: isSpecial ? 1.5 : 1,
        ),
        boxShadow: isSpecial
            ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 14),
        onTap: () => _showLegalDetail(context, title),
      ),
    );
  }

  void _showLegalDetail(BuildContext context, String title) {
    String getDetailedText() {
      switch (title) {
        case "Terms of Service":
          return "This platform connects private individuals for carpooling and is not a taxi service. Users assume all risks, as the platform is not liable for participant conduct or vehicle safety. Valid ID and respectful behavior are mandatory. \n\n Fees are fixed per-kilometer for fuel and maintenance cost-sharing only, not commercial profit. Users must ensure local legal compliance. All trip disputes must be resolved directly between the driver and passenger.";

        case "Privacy Policy":
          return "We collect GPS location only during active trips to calculate distances and ensure safety. Personal data is used exclusively for account verification and connecting you with verified ride partners. \n\n Contact details are shared with your ride partner only after a booking is confirmed. We never sell your personal data to third parties and use encryption to protect your travel history and payment records.";

        case "Cost-Sharing & Rates":
          return "Our Smart Carpooling system operates on a transparent 'Per-Kilometer' cost-sharing model to ensure fairness for both drivers and passengers.\n\n"
              "• Rate: Rs 50 per kilometer.\n"
              "• Calculation: Calculated via GPS from the point of pickup to the point of drop-off.\n"
              "• Purpose: This fee is collected solely to cover fuel, maintenance, and vehicle wear-and-tear.\n"
              "• Legality: This is a non-commercial carpooling arrangement. Drivers do not earn a profit, only cost recovery.";

        case "Community Guidelines":
          return "All users are expected to be punctual and respectful to maintain a positive environment. Smoking, littering, or unprofessional behavior is strictly prohibited and may lead to temporary or permanent account suspension.";

        case "Zero Tolerance Policy":
          return "We prohibit the use of alcohol, drugs, or any impairing substances during any trip. Any report of a user appearing under the influence will result in an immediate account suspension while the incident is investigated. \n\n Harassment, discrimination, or violence of any kind is strictly forbidden. To ensure community safety, violations will lead to a permanent account ban and, if necessary, reporting to local law enforcement.";

        case "Open Source Licenses":
          return "This application utilizes various open-source libraries and digital assets. We acknowledge and thank the developers of the Flutter framework and Google Maps API for their contributions to our technological infrastructure.";

        default:
          return "Detailed information for this section is currently being updated.";
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12161F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    getDetailedText(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                        height: 1.6,
                        letterSpacing: 0.2
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }
}