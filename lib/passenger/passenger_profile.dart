import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ride_together/driver/verification_screen.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/passenger/passenger_screen.dart';

class PassengerProfileScreen extends StatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  State<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends State<PassengerProfileScreen> {
  static const Color primary   = Color(0xFF00FFB3);
  static const Color bgDark    = Color(0xFF0D1B2A);
  static const Color cardColor = Color(0xFF1A1A2E);

  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _phoneController   = TextEditingController();
  final _addressController = TextEditingController();
  final _cnicController    = TextEditingController();

  File?   _imageFile;
  String  _imageUrl    = '';
  String  _role        = '';
  bool    _isLoading   = true;
  bool    _isSaving    = false;
  bool    _isEditMode  = false;
  bool    _isSaved     = false;

  final DatabaseReference _db     = FirebaseDatabase.instance.ref();
  final ImagePicker       _picker = ImagePicker();

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

  // ── Load User Data ────────────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final uid      = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await _db.child("users").child(uid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _nameController.text    = data['name']     ?? '';
          _emailController.text   = data['email']    ?? '';
          _phoneController.text   = data['phone']    ?? '';
          _addressController.text = data['address']  ?? '';
          _cnicController.text    = data['cnic']      ?? '';
          _imageUrl               = data['imageUrl'] ?? '';
          _role                   = data['role']     ?? '';
          _isLoading              = false;

          // ✅ Get Started only works if profileSaved == true in Firebase
          _isSaved = data['profileSaved'] == true;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Show Image Picker ─────────────────────────────────────
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Profile Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _imageOption(
              icon: Icons.camera_alt,
              label: 'Take a Photo',
              subtitle: 'Open camera',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _imageOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              subtitle: 'Pick from your photos',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imageUrl.isNotEmpty || _imageFile != null) ...[
              const SizedBox(height: 12),
              _imageOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                subtitle: 'Use default avatar',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageFile = null;
                    _imageUrl  = '';
                  });
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Image Option Tile ─────────────────────────────────────
  Widget _imageOption({
    required IconData     icon,
    required String       label,
    required String       subtitle,
    required VoidCallback onTap,
    Color color = primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }

  // ── Pick Image ────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Upload Image ──────────────────────────────────────────
  Future<String?> _uploadImage(File file) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // ── Save Profile ──────────────────────────────────────────
  Future<void> _saveProfile() async {

    // ✅ Validate all required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter your Full Name!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter your Phone Number!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter your Home Address!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String imageUrl = _imageUrl;

      if (_imageFile != null) {
        final uploaded = await _uploadImage(_imageFile!);
        if (uploaded != null) imageUrl = uploaded;
      }

      // ✅ Save all data + profileSaved flag to Firebase
      await _db.child("users").child(uid).update({
        'name':         _nameController.text.trim(),
        'phone':        _phoneController.text.trim(),
        'address':      _addressController.text.trim(),
        'cnic':         _addressController.text.trim(),
        'imageUrl':     imageUrl,
        'profileSaved': true, // ✅ This enables Get Started
      });

      userName = _nameController.text.trim();

      setState(() {
        _imageUrl   = imageUrl;
        _isSaving   = false;
        _isEditMode = false;
        _isSaved    = true; // ✅ Unlock Get Started button
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile saved! Get Started is now unlocked.'),
          backgroundColor: Color(0xFF00FFB3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Get Started ───────────────────────────────────────────
  void _getStarted() {
    // ✅ Block if not saved
    if (!_isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please fill all fields and save your profile first!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ✅ Navigate to Driver Home Screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const PassengerHomeScreen(),
      ),
    );
  }

  // ── Input Field ───────────────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String                label,
    required IconData              icon,
    bool          enabled      = true,
    bool          isMultiline  = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller:   controller,
            enabled:      _isEditMode && enabled,
            keyboardType: keyboardType,
            maxLines:     isMultiline ? 3 : 1,
            style: TextStyle(
              color: _isEditMode && enabled
                  ? Colors.white
                  : Colors.white60,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: _isEditMode && enabled
                    ? primary
                    : Colors.white30,
                size: 20,
              ),
              filled:    true,
              fillColor: _isEditMode && enabled
                  ? const Color(0xFF0F3460)
                  : const Color(0xFF0F3460).withOpacity(0.5),
              hintText: hint ?? 'Enter $label',
              hintStyle: const TextStyle(
                color: Colors.white24,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:   BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: primary,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Default Avatar ────────────────────────────────────────
  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFF0F3460),
      child: const Icon(Icons.person, color: primary, size: 55),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation:       0,
        title: const Text(
          'Passenger Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        // ✅ Edit / Save button at top right
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
              if (_isEditMode) {
                _saveProfile();
              } else {
                setState(() => _isEditMode = true);
              }
            },
            child: _isSaving
                ? const SizedBox(
              width:  20,
              height: 20,
              child: CircularProgressIndicator(
                color: primary,
                strokeWidth: 2,
              ),
            )
                : Text(
              _isEditMode ? 'Save' : 'Edit',
              style: const TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: primary),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // ── Profile Photo ──────────────────────
            Center(
              child: Stack(
                children: [
                  Container(
                    width:  110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _imageFile != null
                          ? Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      )
                          : _imageUrl.isNotEmpty
                          ? Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                          child: CircularProgressIndicator(
                            color: primary,
                            strokeWidth: 2,
                          ),
                        ),
                        errorBuilder: (_, __, ___) =>
                            _defaultAvatar(),
                      )
                          : _defaultAvatar(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right:  0,
                    child: GestureDetector(
                      onTap: _showImagePicker,
                      child: Container(
                        width:  34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:  primary,
                          shape:  BoxShape.circle,
                          border: Border.all(
                            color: bgDark,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size:  16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Name ──────────────────────────────
            Text(
              _nameController.text.isEmpty
                  ? userName
                  : _nameController.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // ── Role Badge ────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primary.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Passenger',
                style: const TextStyle(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Personal Info Card ─────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primary.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isEditMode)
                        GestureDetector(
                          onTap: () => setState(
                                () => _isEditMode = false,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  _inputField(
                    controller: _nameController,
                    label:      'Full Name',
                    icon:       Icons.person,
                  ),
                  _inputField(
                    controller:   _emailController,
                    label:        'Email Address',
                    icon:         Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _inputField(
                    controller:   _phoneController,
                    label:        'Phone Number',
                    icon:         Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _inputField(
                    controller:   _cnicController,
                    label:        'CNIC Number',
                    icon: Icons.badge_outlined,
                    hint: "xxxxx-xxxxxxx-x",
                    keyboardType: TextInputType.number,
                  ),
                  _inputField(
                    controller: _addressController,
                    label:      'Home Address',
                    icon:       Icons.location_on_outlined,
                  ),
                ],
              ),
            ),


            const SizedBox(height: 60),

            // ✅ Info text when not saved
            if (!_isSaved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Click Edit → fill all fields → Save to unlock Get Started',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ✅ Success text when saved
            if (_isSaved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primary.withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ' Profile saved! You can now Get Started.',
                        style: TextStyle(
                          color: primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── Get Started Button ─────────────────
            GestureDetector(
              onTap: _getStarted,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: _isSaved
                        ? [primary, const Color(0xFF00B4D8)]
                        : [
                      Colors.grey.shade800,
                      Colors.grey.shade700,
                    ],
                  ),
                  boxShadow: _isSaved
                      ? [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSaved
                          ? Icons.directions_car
                          : Icons.lock_outline,
                      color: _isSaved
                          ? Colors.black
                          : Colors.white38,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isSaved
                          ? 'Get Started'
                          : 'Save Profile First to Continue',
                      style: TextStyle(
                        color: _isSaved
                            ? Colors.black
                            : Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
