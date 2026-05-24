import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/login_screen.dart';

// ── Colors ────────────────────────────────────────────────────
const Color kNavy = Color(0xFF1A1A2E);
const Color kCardNavy = Color(0xFF16213E);
const Color kDeep = Color(0xFF0F3460);
const Color kCyan = Color(0xFF00FFB3);
const Color kSkyBlue = Color(0xFF00D4FF);
const Color kGold = Color(0xFFFFD700);

class DProfileScreen extends StatefulWidget {
  const DProfileScreen({super.key});

  @override
  State<DProfileScreen> createState() => _DProfileScreenState();
}

class _DProfileScreenState extends State<DProfileScreen> {
  // ── Controllers ───────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // ── State ─────────────────────────────────────────────────
  File? _imageFile;
  String _imageUrl = '';
  String _initials = '';
  double _rating = 0.0;
  int _ratingCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _isSigningOut = false; // ← NEW

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
    super.dispose();
  }

  // ── Initials from name ────────────────────────────────────
  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // ── Load Data ─────────────────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap = await _db.child("users").child(uid).get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _imageUrl = data['imageUrl'] ?? '';
          _rating = double.parse((data['rating'] ?? 0.0).toString());
          _ratingCount = int.parse((data['ratingCount'] ?? 0).toString());
          _initials = _getInitials(data['name'] ?? '');
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Save Profile ──────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name is required!'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String imageUrl = _imageUrl;

      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$uid.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await _db.child("users").child(uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'imageUrl': imageUrl,
      });

      userName = _nameController.text.trim();
      setState(() {
        _imageUrl = imageUrl;
        _initials = _getInitials(_nameController.text);
        _isSaving = false;
        _isEditMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Profile updated!'), backgroundColor: kCyan));
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Logout Dialog ─────────────────────────────────────────
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: kCardNavy,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded,
                      color: Colors.redAccent, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Sign Out",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Are you sure you want to log out? You will need to sign in again to access your account.",
                  textAlign: TextAlign.center,
                  style:
                  TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Cancel",
                            style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _performLogout(); // ← calls new method
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Sign Out",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Perform Logout with loading overlay ───────────────────
  Future<void> _performLogout() async {
    setState(() => _isSigningOut = true);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    try {
      await Future.wait([
        FirebaseAuth.instance.signOut(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);

      userName = '';
      if (mounted) {
        setState(() {
          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _addressController.clear();
          _imageUrl = '';
          _imageFile = null;
          _initials = '';
          _isEditMode = false;
        });
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
            (route) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Sign-out Loading Overlay ──────────────────────────────
  Widget _buildSignOutLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: kCardNavy,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(kCyan),
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Signing out...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none, // ← no underline
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar Widget ─────────────────────────────────────────
  Widget _buildAvatar({double size = 85}) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kCyan, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: kCyan.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2)
            ],
          ),
          child: ClipOval(
            child: _imageFile != null
                ? Image.file(_imageFile!, fit: BoxFit.cover)
                : _imageUrl.isNotEmpty
                ? Image.network(_imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsAvatar())
                : _initialsAvatar(),
          ),
        ),
        if (_isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                final picked =
                await _picker.pickImage(source: ImageSource.gallery);
                if (picked != null)
                  setState(() => _imageFile = File(picked.path));
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kCyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: kNavy, width: 2),
                ),
                child:
                const Icon(Icons.camera_alt, color: Colors.black, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initialsAvatar() {
    return Container(
      color: kDeep,
      child: Center(
          child: Text(_initials,
              style: const TextStyle(
                  color: kCyan, fontSize: 30, fontWeight: FontWeight.bold))),
    );
  }

  // ── Profile Header Card ───────────────────────────────────
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCyan.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: kCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                    Border.all(color: kCyan.withOpacity(0.4), width: 0.5),
                  ),
                  child: const Text(
                    "DRIVER",
                    style: TextStyle(
                      color: kCyan,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  _nameController.text.isEmpty
                      ? "User Name"
                      : _nameController.text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: kGold, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        _rating == 0.0
                            ? 'New Member'
                            : '${_rating.toStringAsFixed(1)} Rating',
                        style: const TextStyle(
                            color: kGold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Main Scaffold ──────────────────────────────────
        Scaffold(
          backgroundColor: kNavy,
          appBar: AppBar(
            backgroundColor: kNavy,
            elevation: 0,
            leading: IconButton(
                icon:
                const Icon(Icons.arrow_back_ios, color: kCyan, size: 20),
                onPressed:
                _isSigningOut ? null : () => Navigator.pop(context)),
            title: const Text('My Profile',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: 15),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: kCyan, strokeWidth: 2)),
                )
              else
                TextButton(
                  onPressed: _isSigningOut
                      ? null
                      : () {
                    if (_isEditMode)
                      _saveProfile();
                    else
                      setState(() => _isEditMode = true);
                  },
                  child: Text(_isEditMode ? 'Save' : 'Edit',
                      style: const TextStyle(
                          color: kCyan, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kCyan))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 25),

                // Personal Info Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: kCardNavy,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ACCOUNT DETAILS",
                          style: TextStyle(
                              color: kCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                      const Divider(color: Colors.white10, height: 30),
                      _inputField(
                          controller: _nameController,
                          label: "Full Name",
                          icon: Icons.person_outline),
                      _inputField(
                          controller: _emailController,
                          label: "Email Address",
                          icon: Icons.email_outlined,
                          enabled: false),
                      _inputField(
                          controller: _phoneController,
                          label: "Phone Number",
                          icon: Icons.phone_android_outlined),
                      _inputField(
                          controller: _addressController,
                          label: "Home Address",
                          icon: Icons.location_on_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // ── SIGN OUT BUTTON ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: InkWell(
                    onTap: _isSigningOut
                        ? null
                        : _showLogoutConfirmation,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withOpacity(
                                _isSigningOut ? 0.04 : 0.2),
                            Colors.redAccent.withOpacity(
                                _isSigningOut ? 0.02 : 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(
                                _isSigningOut ? 0.15 : 0.4),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.power_settings_new_rounded,
                              color: Colors.redAccent.withOpacity(
                                  _isSigningOut ? 0.4 : 1.0),
                              size: 22),
                          const SizedBox(width: 12),
                          Text(
                            "Sign Out",
                            style: TextStyle(
                                color: Colors.redAccent.withOpacity(
                                    _isSigningOut ? 0.4 : 1.0),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),

        // ── Sign-out Loading Overlay ───────────────────────
        if (_isSigningOut)
          WillPopScope(
            onWillPop: () async => false,
            child: _buildSignOutLoadingOverlay(),
          ),
      ],
    );
  }

  Widget _inputField(
      {required TextEditingController controller,
        required String label,
        required IconData icon,
        bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        enabled: _isEditMode && enabled,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon,
              color: _isEditMode && enabled ? kCyan : Colors.white24, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: kNavy,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kCyan, width: 1),
          ),
        ),
      ),
    );
  }
}

