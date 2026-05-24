import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/login_screen.dart';

// ── Colors ─────────────────────────────────────────────────
const Color kNavy     = Color(0xFF1A1A2E);
const Color kCardNavy = Color(0xFF16213E);
const Color kDeep     = Color(0xFF0F3460);
const Color kCyan     = Color(0xFF00FFB3);
const Color kSkyBlue  = Color(0xFF00D4FF);
const Color kGold     = Color(0xFFFFD700);
const Color kError    = Color(0xFFFF4B2B);

class PProfileScreen extends StatefulWidget {
  const PProfileScreen({super.key});

  @override
  State<PProfileScreen> createState() => _PProfileScreenState();
}

class _PProfileScreenState extends State<PProfileScreen>
    with SingleTickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  // ── State ────────────────────────────────────────────────
  File?   _imageFile;
  String  _imageUrl        = '';
  String  _initials        = '';
  String  _lastDriverId    = '';
  String  _lastDriverName  = '';
  String  _lastDriverPhoto = '';
  bool    _isLoading       = true;
  bool    _isSaving        = false;
  bool    _isEditMode      = false;
  bool    _isRated         = false;
  bool    _isSigningOut    = false;

  // ── Rides ────────────────────────────────────────────────
  List<Map<String, dynamic>> _completedRides = [];
  bool                       _ridesLoaded    = false;
  bool                       _showAllRides   = false;
  static const int           _previewCount   = 3;

  final Map<String, String> _driverPhotoCache = {};
  final _db     = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  LOAD USER DATA
  // ─────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final uid  = FirebaseAuth.instance.currentUser!.uid;
      final snap = await _db.child('users').child(uid).get();
      if (snap.exists) {
        final d = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _nameCtrl.text    = d['name']     ?? '';
          _emailCtrl.text   = d['email']    ?? '';
          _phoneCtrl.text   = d['phone']    ?? '';
          _addressCtrl.text = d['address']  ?? '';
          _imageUrl         = d['imageUrl'] ?? '';
          _lastDriverId     = d['lastDriverId']    ?? '';
          _lastDriverName   = d['lastDriverName']  ?? 'Driver';
          _lastDriverPhoto  = d['lastDriverPhoto'] ?? '';
          _initials         = _getInitials(d['name'] ?? '');
          _isLoading        = false;
          _isRated          = _lastDriverId.isEmpty;
        });
      }
      await _loadCompletedRides(uid);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  LOAD COMPLETED RIDES
  // ─────────────────────────────────────────────────────────
  Future<void> _loadCompletedRides(String uid) async {
    try {
      final snap = await _db
          .child('ride_requests')
          .orderByChild('passengerId')
          .equalTo(uid)
          .get();

      if (!snap.exists || snap.value == null) {
        setState(() => _ridesLoaded = true);
        return;
      }

      final raw  = Map<String, dynamic>.from(snap.value as Map);
      final List<Map<String, dynamic>> rides = [];

      raw.forEach((key, val) {
        final r = Map<String, dynamic>.from(val as Map);
        r['_key'] = key;
        if ((r['status'] == 'accepted' ||
            r['status'] == 'completed') &&
            r['passengerRated'] != true) {
          rides.add(r);
        }
      });

      rides.sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      for (final ride in rides) {
        final dId = ride['driverId']?.toString() ?? '';
        if (dId.isNotEmpty && !_driverPhotoCache.containsKey(dId)) {
          await _fetchDriverPhoto(dId);
        }
      }

      setState(() {
        _completedRides = rides;
        _ridesLoaded    = true;
      });
    } catch (_) {
      setState(() => _ridesLoaded = true);
    }
  }

  Future<void> _fetchDriverPhoto(String driverId) async {
    if (driverId.isEmpty) return;
    if (_driverPhotoCache.containsKey(driverId)) return;
    try {
      for (final node in ['users', 'drivers']) {
        final snap = await _db.child('$node/$driverId').get();
        if (snap.exists && snap.value != null) {
          final d = Map<String, dynamic>.from(snap.value as Map);
          final photo =
              d['imageUrl']?.toString()     ??
                  d['photoUrl']?.toString()     ??
                  d['profileImage']?.toString() ??
                  d['photo']?.toString()        ??
                  d['driverImage']?.toString()  ?? '';
          _driverPhotoCache[driverId] = photo;
          return;
        }
      }
      _driverPhotoCache[driverId] = '';
    } catch (_) {
      _driverPhotoCache[driverId] = '';
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();
  }

  // ─────────────────────────────────────────────────────────
  //  LOGOUT DIALOG
  // ─────────────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context:            context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: kCardNavy,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        title: Column(
          children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.10),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.30),
                    width: 1.5),
              ),
              child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.redAccent,
                  size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Sign Out',
                style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:   19)),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        content: const Text(
          'Are you sure you want to sign out?\nYou will need to log in again.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white54, fontSize: 13, height: 1.65),
        ),
        actionsPadding:   const EdgeInsets.fromLTRB(20, 22, 20, 24),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(children: [
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performLogout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Sign Out',
                        style: TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize:   15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PERFORM LOGOUT
  // ─────────────────────────────────────────────────────────
  Future<void> _performLogout() async {
    setState(() => _isSigningOut = true);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
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
          _nameCtrl.clear();
          _emailCtrl.clear();
          _phoneCtrl.clear();
          _addressCtrl.clear();
          _imageUrl        = '';
          _imageFile       = null;
          _initials        = '';
          _completedRides  = [];
          _driverPhotoCache.clear();
          _lastDriverId    = '';
          _lastDriverName  = '';
          _lastDriverPhoto = '';
          _isRated         = false;
          _isEditMode      = false;
          _showAllRides    = false;
        });
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder:        (_, __, ___) => const LoginScreen(),
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
            content:         Text('Sign out failed: $e'),
            backgroundColor: kError,
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  //  SIGN-OUT LOADING OVERLAY  (navy card + cyan spinner)
  // ─────────────────────────────────────────────────────────
  Widget _buildSignOutLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color:        kCardNavy,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kCyan.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color:        Colors.black.withOpacity(0.4),
                blurRadius:   20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width:  22,
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
                  color:      Colors.white,
                  fontSize:   15,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  RATING BOTTOM SHEET
  // ─────────────────────────────────────────────────────────
  void _showRatingSheet({
    required String driverId,
    required String driverName,
    required String driverPhoto,
    required String requestId,
    required String pickup,
    required String destination,
    required String fare,
  }) {
    final resolvedPhoto = (_driverPhotoCache[driverId]?.isNotEmpty == true)
        ? _driverPhotoCache[driverId]!
        : driverPhoto;

    double _stars         = 0;
    String _feedback      = '';
    bool   _submitting    = false;
    final  _selectedChips = <String>{};
    final  _commentCtrl   = TextEditingController();

    final chips = [
      'Great driver!', 'Very punctual', 'Safe driving',
      'Friendly', 'Clean vehicle', 'Would ride again',
    ];

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF12192B),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color:        Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [kCyan, kSkyBlue]),
                      boxShadow: [
                        BoxShadow(
                            color:      kCyan.withOpacity(0.4),
                            blurRadius: 16),
                      ],
                    ),
                    child: CircleAvatar(
                      radius:          44,
                      backgroundColor: kDeep,
                      backgroundImage: resolvedPhoto.isNotEmpty
                          ? NetworkImage(resolvedPhoto) : null,
                      onBackgroundImageError:
                      resolvedPhoto.isNotEmpty ? (_, __) {} : null,
                      child: resolvedPhoto.isEmpty
                          ? Text(
                          driverName.isNotEmpty
                              ? driverName[0].toUpperCase() : 'D',
                          style: const TextStyle(
                              color: kCyan, fontSize: 30,
                              fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(driverName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('How was your ride?',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 10),
                  if (pickup.isNotEmpty || destination.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color:        kDeep.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radio_button_checked,
                              color: kCyan, size: 11),
                          const SizedBox(width: 5),
                          Flexible(child: Text(
                              pickup.length > 15
                                  ? '${pickup.substring(0, 15)}…' : pickup,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11))),
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white24, size: 12)),
                          const Icon(Icons.location_on,
                              color: kError, size: 11),
                          const SizedBox(width: 5),
                          Flexible(child: Text(
                              destination.length > 15
                                  ? '${destination.substring(0, 15)}…'
                                  : destination,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11))),
                          if (fare.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: kCyan.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('Rs $fare',
                                    style: const TextStyle(
                                        color: kCyan, fontSize: 10,
                                        fontWeight: FontWeight.bold))),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < _stars;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setSheet(() => _stars = i + 1.0);
                        },
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                                filled ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: filled ? kGold : Colors.white24,
                                size:  filled ? 48 : 40)),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                        _stars == 0 ? 'Tap to rate'
                            : _stars == 1 ? '😞  Poor'
                            : _stars == 2 ? '😐  Fair'
                            : _stars == 3 ? '😊  Good'
                            : _stars == 4 ? '😄  Great'
                            : '🤩  Excellent!',
                        key: ValueKey(_stars),
                        style: TextStyle(
                            color: _stars == 0 ? Colors.white30 : kGold,
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: chips.map((chip) {
                      final selected = _selectedChips.contains(chip);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheet(() => selected
                              ? _selectedChips.remove(chip)
                              : _selectedChips.add(chip));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: selected
                                  ? kCyan.withOpacity(0.18)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: selected ? kCyan : Colors.white12,
                                  width: selected ? 1.5 : 1)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                const Icon(Icons.check_rounded,
                                    color: kCyan, size: 13),
                                const SizedBox(width: 4),
                              ],
                              Text(chip,
                                  style: TextStyle(
                                      color: selected ? kCyan : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1))),
                    child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        maxLines: 3, maxLength: 200,
                        onChanged: (v) => setSheet(() => _feedback = v),
                        decoration: const InputDecoration(
                            hintText: 'Add a comment (optional)...',
                            hintStyle: TextStyle(
                                color: Colors.white30, fontSize: 13),
                            border:         InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            counterStyle:   TextStyle(
                                color: Colors.white24, fontSize: 10))),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: (_stars == 0 || _submitting) ? null
                          : () async {
                        setSheet(() => _submitting = true);
                        final allFeedback = [
                          ..._selectedChips,
                          if (_feedback.trim().isNotEmpty)
                            _feedback.trim(),
                        ].join(', ');
                        await _submitRating(
                          driverId:  driverId,
                          stars:     _stars,
                          feedback:  allFeedback,
                          requestId: requestId,
                        );
                        _commentCtrl.dispose();
                        if (mounted) {
                          Navigator.pop(ctx);
                          _showRatingSuccess(_stars);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _stars == 0 ? Colors.white10 : kCyan,
                          disabledBackgroundColor: Colors.white10,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation:   _stars > 0 ? 6 : 0,
                          shadowColor: kCyan.withOpacity(0.4)),
                      child: _submitting
                          ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5))
                          : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                                _stars == 0
                                    ? 'SELECT A RATING FIRST'
                                    : 'SUBMIT RATING',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15, letterSpacing: 1,
                                    color: _stars == 0
                                        ? Colors.white30 : Colors.black)),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Skip for now',
                          style: TextStyle(
                              color: Colors.white30, fontSize: 13))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  SUBMIT RATING
  // ─────────────────────────────────────────────────────────
  Future<void> _submitRating({
    required String driverId,
    required double stars,
    required String feedback,
    required String requestId,
  }) async {
    try {
      final uid       = FirebaseAuth.instance.currentUser!.uid;
      final driverRef = _db.child('users').child(driverId);
      final snap      = await driverRef.get();
      if (snap.exists) {
        final d        = Map<String, dynamic>.from(snap.value as Map);
        final curScore = double.tryParse(
            d['ratingScore']?.toString() ?? '0') ?? 0;
        final curCount = int.tryParse(
            d['ratingCount']?.toString() ?? '0') ?? 0;
        final newScore = curScore + stars;
        final newCount = curCount + 1;
        await driverRef.update({
          'rating':      (newScore / newCount).toStringAsFixed(1),
          'ratingScore': newScore,
          'ratingCount': newCount,
        });
      }
      await _db.child('driver_reviews').child(driverId).push().set({
        'passengerId':   uid,
        'passengerName': _nameCtrl.text.trim(),
        'rating':        stars,
        'feedback':      feedback,
        'requestId':     requestId,
        'timestamp':     DateTime.now().millisecondsSinceEpoch,
      });
      if (requestId.isNotEmpty) {
        await _db
            .child('ride_requests')
            .child(requestId)
            .update({'passengerRated': true});
      }
      await _db.child('users').child(uid).update({
        'lastDriverId':    '',
        'lastDriverName':  '',
        'lastDriverPhoto': '',
      });
      await _db.child('notifications').child(driverId).push().set({
        'message':
        '⭐ ${_nameCtrl.text} rated you ${stars.toStringAsFixed(0)} stars!'
            '${feedback.isNotEmpty ? ' "$feedback"' : ''}',
        'type':      'rating',
        'isRead':    false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _isRated      = true;
        _lastDriverId = '';
        _completedRides.removeWhere((r) =>
        r['requestId'] == requestId || r['driverId'] == driverId);
      });
    } catch (e) {
      debugPrint('Rating error: $e');
    }
  }

  void _showRatingSuccess(double stars) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: kCardNavy,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        content: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:        kGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.star_rounded,
                  color: kGold, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    const Text('Rating submitted! 🎉',
                        style: TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold)),
                    Text(
                        '${stars.toStringAsFixed(0)} star'
                            '${stars > 1 ? 's' : ''} sent to driver',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ])),
        ]),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PICK IMAGE / SAVE PROFILE
  // ─────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String imageUrl = _imageUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref().child('profile_images').child('$uid.jpg');
        await ref.putFile(
            _imageFile!, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      }
      await _db.child('users').child(uid).update({
        'name':     _nameCtrl.text.trim(),
        'phone':    _phoneCtrl.text.trim(),
        'address':  _addressCtrl.text.trim(),
        'imageUrl': imageUrl,
      });
      userName = _nameCtrl.text.trim();
      setState(() {
        _imageUrl   = imageUrl;
        _imageFile  = null;
        _isEditMode = false;
        _isSaving   = false;
        _initials   = _getInitials(_nameCtrl.text);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Profile saved!'),
          backgroundColor: kCyan));
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Main scaffold ─────────────────────────────────
        Scaffold(
          backgroundColor: kNavy,
          appBar: AppBar(
            backgroundColor: kNavy,
            elevation:       0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: kCyan, size: 20),
              onPressed:
              _isSigningOut ? null : () => Navigator.pop(context),
            ),
            title: const Text('My Profile',
                style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              _isSaving
                  ? const Padding(
                padding: EdgeInsets.only(right: 15),
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: kCyan, strokeWidth: 2)),
              )
                  : TextButton(
                onPressed: _isSigningOut
                    ? null
                    : () => _isEditMode
                    ? _saveProfile()
                    : setState(() => _isEditMode = true),
                child: Text(
                    _isEditMode ? 'Save' : 'Edit',
                    style: const TextStyle(
                        color:      kCyan,
                        fontWeight: FontWeight.bold,
                        fontSize:   16)),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
              child: CircularProgressIndicator(color: kCyan))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                _buildPersonalInfoCard(),
                const SizedBox(height: 24),
                _buildRateRidesSection(),
                const SizedBox(height: 24),
                _buildSignOutButton(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),

        // ── Sign-out loading overlay ──────────────────────
        if (_isSigningOut)
          WillPopScope(
            onWillPop: () async => false,
            child: _buildSignOutLoadingOverlay(),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  RATE RIDES SECTION
  // ─────────────────────────────────────────────────────────
  Widget _buildRateRidesSection() {
    final bool hasPending = _lastDriverId.isNotEmpty && !_isRated;
    final visibleRides = _showAllRides
        ? _completedRides
        : _completedRides.take(_previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPending)
          GestureDetector(
            onTap: () => _showRatingSheet(
              driverId:    _lastDriverId,
              driverName:  _lastDriverName,
              driverPhoto: _lastDriverPhoto,
              requestId:   '',
              pickup:      '',
              destination: '',
              fare:        '',
            ),
            child: Container(
              margin:  const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    kGold.withOpacity(0.15),
                    kCyan.withOpacity(0.08),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: kGold.withOpacity(0.4), width: 1.5)),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color:        kGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.star_rounded,
                        color: kGold, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rate your last driver!',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize:   14)),
                          const SizedBox(height: 3),
                          Text(
                              'How was your ride with $_lastDriverName?',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ])),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: kGold, size: 14),
              ]),
            ),
          ),

        if (_ridesLoaded && _completedRides.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color:        kCardNavy,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.star_outline_rounded,
                        color: kGold, size: 18),
                    const SizedBox(width: 8),
                    const Text('RATE YOUR RIDES',
                        style: TextStyle(
                            color:         kGold,
                            fontSize:      12,
                            fontWeight:    FontWeight.bold,
                            letterSpacing: 1.5)),
                    const Spacer(),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: kGold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: kGold.withOpacity(0.3))),
                        child: Text(
                            '${_completedRides.length} pending',
                            style: const TextStyle(
                                color:      kGold,
                                fontSize:   10,
                                fontWeight: FontWeight.bold))),
                  ]),
                  const Divider(color: Colors.white10, height: 24),
                  ...visibleRides.map((ride) {
                    final driverName  = ride['driverName']?.toString()  ?? 'Driver';
                    final driverId    = ride['driverId']?.toString()     ?? '';
                    final pickup      = ride['pickup']?.toString()       ?? '';
                    final dest        = ride['destination']?.toString()  ?? '';
                    final fare        = ride['fare']?.toString()         ?? '';
                    final requestId   = ride['_key']?.toString()         ?? '';
                    final driverPhoto = _driverPhotoCache[driverId]      ?? '';
                    return _buildRideTile(
                      driverName:  driverName,
                      driverId:    driverId,
                      driverPhoto: driverPhoto,
                      pickup:      pickup,
                      dest:        dest,
                      fare:        fare,
                      requestId:   requestId,
                    );
                  }).toList(),
                  if (_completedRides.length > _previewCount)
                    GestureDetector(
                        onTap: () => setState(
                                () => _showAllRides = !_showAllRides),
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          width:  double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: kCyan.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: kCyan.withOpacity(0.2))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                    _showAllRides
                                        ? 'Show Less'
                                        : 'See All ${_completedRides.length} Rides',
                                    style: const TextStyle(
                                        color: kCyan, fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Icon(
                                    _showAllRides
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: kCyan, size: 18),
                              ]),
                        )),
                ]),
          ),
        ],

        if (_ridesLoaded && _completedRides.isEmpty && !hasPending)
          Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                  color:        kCyan.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kCyan.withOpacity(0.15))),
              child: const Row(children: [
                Icon(Icons.check_circle_outline, color: kCyan, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                    'All rides rated — thanks for your feedback!',
                    style: TextStyle(color: Colors.white54, fontSize: 12))),
              ])),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  SINGLE RIDE TILE
  // ─────────────────────────────────────────────────────────
  Widget _buildRideTile({
    required String driverName,
    required String driverId,
    required String driverPhoto,
    required String pickup,
    required String dest,
    required String fare,
    required String requestId,
  }) {
    final String initial =
    driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D';
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color:        kDeep.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(children: [
        Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kCyan.withOpacity(0.4), width: 2)),
            child: CircleAvatar(
                radius:          24,
                backgroundColor: kDeep,
                backgroundImage: driverPhoto.isNotEmpty
                    ? NetworkImage(driverPhoto) : null,
                onBackgroundImageError:
                driverPhoto.isNotEmpty ? (_, __) {} : null,
                child: driverPhoto.isEmpty
                    ? Text(initial,
                    style: const TextStyle(
                        color: kCyan, fontWeight: FontWeight.bold,
                        fontSize: 14))
                    : null)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driverName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  if (pickup.isNotEmpty || dest.isNotEmpty)
                    Text(
                        _truncate(pickup, 14) +
                            (pickup.isNotEmpty && dest.isNotEmpty ? ' → ' : '') +
                            _truncate(dest, 14),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  if (fare.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Rs $fare',
                        style: const TextStyle(
                            color: kCyan, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ])),
        GestureDetector(
            onTap: () => _showRatingSheet(
              driverId:    driverId,
              driverName:  driverName,
              driverPhoto: driverPhoto,
              requestId:   requestId,
              pickup:      pickup,
              destination: dest,
              fare:        fare,
            ),
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [kGold, Color(0xFFFF9800)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: kGold.withOpacity(0.3), blurRadius: 8)]),
                child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.black, size: 14),
                      SizedBox(width: 4),
                      Text('Rate',
                          style: TextStyle(
                              color: Colors.black, fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ]))),
      ]),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;

  // ─────────────────────────────────────────────────────────
  //  SIGN OUT BUTTON
  // ─────────────────────────────────────────────────────────
  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: _isSigningOut ? null : _showLogoutDialog,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(
                _isSigningOut ? 0.04 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.redAccent.withOpacity(
                    _isSigningOut ? 0.15 : 0.35),
                width: 1.5)),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.power_settings_new_rounded,
                  color: Colors.redAccent.withOpacity(
                      _isSigningOut ? 0.4 : 1.0),
                  size: 22),
              const SizedBox(width: 12),
              Text('SIGN OUT',
                  style: TextStyle(
                    color: Colors.redAccent.withOpacity(
                        _isSigningOut ? 0.4 : 1.0),
                    fontSize:      15,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 1,
                  )),
            ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    ImageProvider? img;
    if (_imageFile != null)        img = FileImage(_imageFile!);
    else if (_imageUrl.isNotEmpty) img = NetworkImage(_imageUrl);

    return Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                  radius:          50,
                  backgroundColor: kDeep,
                  backgroundImage: img,
                  child: img == null
                      ? Text(_initials,
                      style: const TextStyle(
                          color:      kCyan,
                          fontSize:   32,
                          fontWeight: FontWeight.bold))
                      : null),
              if (_isEditMode)
                Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                            width:  32, height: 32,
                            decoration: BoxDecoration(
                                color:  kCyan,
                                shape:  BoxShape.circle,
                                border: Border.all(color: kNavy, width: 2)),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.black, size: 18)))),
            ],
          ),
          const SizedBox(height: 15),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin:  const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                  color:        kCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: kCyan.withOpacity(0.4), width: 0.5)),
              child: const Text('PASSENGER',
                  style: TextStyle(
                      color:         kCyan,
                      fontSize:      10,
                      letterSpacing: 1.2))),
          Text(
              _nameCtrl.text.isEmpty ? 'User Name' : _nameCtrl.text,
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   22,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ]);
  }

  // ─────────────────────────────────────────────────────────
  //  PERSONAL INFO CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildPersonalInfoCard() {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: kCardNavy, borderRadius: BorderRadius.circular(24)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PERSONAL INFORMATION',
                  style: TextStyle(
                      color:         kCyan,
                      fontSize:      11,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: 1.5)),
              const Divider(color: Colors.white10, height: 30),
              _field('Full Name',    _nameCtrl,    Icons.person_outline,        _isEditMode),
              _field('Email',        _emailCtrl,   Icons.email_outlined,         false),
              _field('Phone',        _phoneCtrl,   Icons.phone_android_outlined, _isEditMode),
              _field('Home Address', _addressCtrl, Icons.location_on_outlined,   _isEditMode),
            ]));
  }

  Widget _field(
      String label,
      TextEditingController ctrl,
      IconData icon,
      bool enabled,
      ) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TextField(
            controller: ctrl,
            enabled:    enabled,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
                prefixIcon: Icon(icon,
                    color: enabled ? kCyan : Colors.white24, size: 20),
                labelText:  label,
                labelStyle: const TextStyle(
                    color: Colors.white38, fontSize: 12),
                filled:    true,
                fillColor: enabled ? kNavy : Colors.transparent,
                disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.05))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   const BorderSide(color: kDeep)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   const BorderSide(color: kCyan)))));
  }
}

