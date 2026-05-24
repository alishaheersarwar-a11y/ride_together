import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Pro UI Colors to match Profile Screen
  static const Color kNavy = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kCyan = Color(0xFF00FFB3);
  static const Color kSkyBlue = Color(0xFF00D4FF);

  File? _cnicImage;
  File? _licenseImage;
  File? _registrationImage;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickDocument(String type) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40, // Optimized for faster upload
      );

      if (pickedFile != null) {
        setState(() {
          if (type == "CNIC") _cnicImage = File(pickedFile.path);
          else if (type == "License") _licenseImage = File(pickedFile.path);
          else if (type == "Vehicle") _registrationImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showSnack("Error picking image: $e", Colors.red);
    }
  }

  Future<String?> _uploadToStorage(File file, String folderName) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      Reference ref = FirebaseStorage.instance
          .ref()
          .child("verifications")
          .child(uid)
          .child("$folderName.jpg");

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    if (_cnicImage == null || _licenseImage == null || _registrationImage == null) {
      _showSnack("Please upload all 3 documents to proceed", Colors.orange);
      return;
    }

    setState(() => _isUploading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Upload images
      String? cnicUrl = await _uploadToStorage(_cnicImage!, "cnic");
      String? licenseUrl = await _uploadToStorage(_licenseImage!, "license");
      String? vehicleUrl = await _uploadToStorage(_registrationImage!, "vehicle");

      if (cnicUrl != null && licenseUrl != null && vehicleUrl != null) {
        // 2. IMPORTANT: Update the 'isVerified' flag to TRUE
        DatabaseReference dbRef = FirebaseDatabase.instance.ref().child("users").child(uid);

        await dbRef.update({
          "verificationDocs": {
            "cnicUrl": cnicUrl,
            "licenseUrl": licenseUrl,
            "vehicleUrl": vehicleUrl,
          },
          "isVerified": true, // This turns the Profile banner Green
          "verificationStatus": "completed",
        });

        setState(() => _isUploading = false);
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnack("Submission failed: $e", Colors.red);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kCardNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kCyan, width: 1), // Change 'border' to 'side' and 'Border.all' to 'BorderSide'
        ),
        title: const Icon(Icons.check_circle_outline, color: kCyan, size: 60),
        content: const Text(
          "Documents submitted successfully!\nYour profile is now verified.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Return to Profile Screen
              },
              child: const Text("AWESOME", style: TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      appBar: AppBar(
        title: const Text("SECURITY VERIFICATION", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: kNavy,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: kCyan), onPressed: () => Navigator.pop(context)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Verify Identity", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Upload your documents to unlock carpooling and build trust with passengers.", style: TextStyle(color: Colors.white38, fontSize: 14)),
                const SizedBox(height: 35),

                _buildUploadCard("CNIC / ID Card", "Identity Proof", Icons.badge_outlined, _cnicImage, () => _pickDocument("CNIC")),
                _buildUploadCard("Driving License", "Driver Authority", Icons.assignment_ind_outlined, _licenseImage, () => _pickDocument("License")),
                _buildUploadCard("Vehicle Registration", "Ownership Proof", Icons.minor_crash_outlined, _registrationImage, () => _pickDocument("Vehicle")),

                const SizedBox(height: 40),

                _buildSubmitButton(),
              ],
            ),
          ),
          if (_isUploading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildUploadCard(String title, String subtitle, IconData icon, File? file, VoidCallback onTap) {
    bool done = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: done ? kCyan : Colors.white.withOpacity(0.05), width: done ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: done ? kCyan : kNavy, shape: BoxShape.circle),
              child: Icon(done ? Icons.check : icon, color: done ? kNavy : kCyan, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(done ? "Ready for upload" : subtitle, style: TextStyle(color: done ? kCyan : Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: kCyan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 10,
          shadowColor: kCyan.withOpacity(0.3),
        ),
        child: const Text("SUBMIT FOR REVIEW", style: TextStyle(color: kNavy, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kCyan),
            SizedBox(height: 20),
            Text("Securing Documents...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

