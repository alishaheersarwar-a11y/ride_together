import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ride_together/driver/verification_screen.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/driver/driver_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  // --- Pro UI Colors ---
  static const Color kNavy = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kDeep = Color(0xFF0F3460);
  static const Color kCyan = Color(0xFF00FFB3);
  static const Color kSkyBlue = Color(0xFF00D4FF);

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cnicController = TextEditingController();

  // --- State Variables ---
  File? _imageFile;
  String _imageUrl = '';
  double _rating = 0.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _isSaved = false;
  bool _isVerified = false;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  // ── Fetch Data ────────────────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await _db.child("users").child(uid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _cnicController.text = data['cnic'] ?? '';
          _imageUrl = data['imageUrl'] ?? '';
          _isSaved = data['profileSaved'] == true;
          _isVerified = data['isVerified'] == true;
          _rating = double.parse((data['rating'] ?? 0.0).toString());
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isProfileFilled() {
    return _nameController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty &&
        _cnicController.text.trim().length == 15 &&
        (_imageFile != null || _imageUrl.isNotEmpty);
  }

  Future<void> _saveProfile() async {
    if (!_isProfileFilled()) {
      _showErrorSnack('Please fill all fields & add photo (15-digit CNIC)');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String finalImageUrl = _imageUrl;

      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
        await ref.putFile(_imageFile!);
        finalImageUrl = await ref.getDownloadURL();
      }

      await _db.child("users").child(uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'imageUrl': finalImageUrl,
        'profileSaved': true,
      });

      userName = _nameController.text.trim();
      setState(() {
        _imageUrl = finalImageUrl;
        _isSaving = false;
        _isEditMode = false;
        _isSaved = true;
      });

      _showSuccessSnack('Profile Updated!');
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnack('Update Failed: $e');
    }
  }

  // ── UI Sections ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 25),
                  _buildStatsRow(),
                  const SizedBox(height: 30),
                  _buildVerificationBanner(),
                  const SizedBox(height: 25),
                  _buildInfoSection(),
                  const SizedBox(height: 40),
                  _buildGetStartedButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: kNavy,
      pinned: true,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: kCyan, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "DRIVER PROFILE",
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () {
            if (_isEditMode) _saveProfile();
            else setState(() => _isEditMode = true);
          },
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kCyan, strokeWidth: 2))
              : Text(
            _isEditMode ? 'SAVE' : 'EDIT',
            style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kCyan, width: 2),
                boxShadow: [BoxShadow(color: kCyan.withOpacity(0.2), blurRadius: 15)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : (_imageUrl.isNotEmpty
                      ? Image.network(_imageUrl, fit: BoxFit.cover)
                      : Container(color: kDeep, child: const Icon(Icons.person, color: kCyan, size: 60))),
                ),
              ),
            ),
            if (_isEditMode)
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: () => _showImageSourceOptions(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, color: kNavy, size: 18),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          _nameController.text.isEmpty ? "SET YOUR NAME" : _nameController.text.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem("Rating", "⭐ $_rating"),
        _statItem("Status", _isVerified ? "Verified" : "Pending", color: _isVerified ? kCyan : Colors.redAccent),
        _statItem("Role", "Driver"),
      ],
    );
  }

  Widget _statItem(String label, String value, {Color color = Colors.white70}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildVerificationBanner() {
    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (c) => const VerificationScreen()));
        _loadUserData();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isVerified ? kCyan.withOpacity(0.1) : Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isVerified ? kCyan : Colors.redAccent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_isVerified ? Icons.verified : Icons.error_outline, color: _isVerified ? kCyan : Colors.redAccent, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Verification Documents", style: TextStyle(color: _isVerified ? kCyan : Colors.white, fontWeight: FontWeight.bold)),
                  Text(_isVerified ? "Identity Confirmed" : "Action Required", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _proTextField(_nameController, "Full Name", Icons.person_outline),
          _proTextField(_emailController, "Email Address", Icons.email_outlined, enabled: false),
          _proTextField(_phoneController, "Phone Number", Icons.phone_android_outlined, keyboard: TextInputType.phone),
          _proTextField(_cnicController, "CNIC Number", Icons.badge_outlined, hint: "xxxxx-xxxxxxx-x", limit: 15),
          _proTextField(_addressController, "Home Address", Icons.map_outlined),
        ],
      ),
    );
  }

  Widget _proTextField(TextEditingController controller, String label, IconData icon, {bool enabled = true, String? hint, int? limit, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: _isEditMode && enabled,
        maxLength: limit,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          counterText: "",
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white12),
          prefixIcon: Icon(icon, color: kCyan.withOpacity(0.5), size: 20),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kCyan)),
          disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    bool isReady = _isSaved && _isVerified && _isProfileFilled();
    return InkWell(
      onTap: () {
        if (isReady) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DriverHomeScreen()));
        } else {
          _showErrorSnack(_isVerified ? "Please Save Profile info" : "Complete Verification first");
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity, height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isReady
              ? const LinearGradient(colors: [kCyan, kSkyBlue])
              : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900]),
        ),
        child: Center(
          child: Text("GET STARTED", style: TextStyle(color: isReady ? kNavy : Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          const Text("Select Source", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: kCyan),
            title: const Text("Camera", style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
              if (picked != null) setState(() => _imageFile = File(picked.path));
            },
          ),
          ListTile(
            leading: const Icon(Icons.image, color: kCyan),
            title: const Text("Gallery", style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
              if (picked != null) setState(() => _imageFile = File(picked.path));
            },
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: kCyan, behavior: SnackBarBehavior.floating));
  }
}