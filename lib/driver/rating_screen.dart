import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AppRatingScreen extends StatefulWidget {
  const AppRatingScreen({super.key});

  @override
  State<AppRatingScreen> createState() => _AppRatingScreenState();
}

class _AppRatingScreenState extends State<AppRatingScreen> {
  int _selectedStars = 0;
  TextEditingController feedbackController = TextEditingController();

  void _submitFeedback() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating")),
      );
      return;
    }

    DatabaseReference feedbackRef = FirebaseDatabase.instance.ref().child("app_feedback");
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    await feedbackRef.push().set({
      "userId": userId,
      "rating": _selectedStars,
      "comment": feedbackController.text.trim(),
      "timestamp": ServerValue.timestamp,
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Thank you for your feedback!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      // This ensures the screen adjusts when the keyboard opens
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Rate Our App", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      // ✅ FIX: Added SingleChildScrollView to prevent overflow
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.stars_rounded, size: 80, color: Color(0xFF00D4FF)),
              const SizedBox(height: 20),
              const Text(
                "How is your experience?",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your feedback helps us make the carpooling community better for everyone.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 40),

              // STAR RATING ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => _selectedStars = index + 1),
                    icon: Icon(
                      index < _selectedStars ? Icons.star : Icons.star_border,
                      color: const Color(0xFF00D4FF),
                      size: 40,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 30),

              // FEEDBACK TEXT FIELD
              TextField(
                controller: feedbackController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Write your suggestions (optional)...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white10)
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF00D4FF))
                  ),
                ),
              ),

              // ✅ FIX: Replaced Spacer with fixed SizedBox
              // Spacer does not work inside SingleChildScrollView
              const SizedBox(height: 40),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("SUBMIT FEEDBACK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20), // Extra space at bottom
            ],
          ),
        ),
      ),
    );
  }
}
