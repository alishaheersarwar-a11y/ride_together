import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/driver/driverprofile.dart';
import 'package:ride_together/login_screen.dart';
import 'package:ride_together/passenger/passenger_profile.dart';
import 'package:ride_together/app_charges/app_wallet.dart'; // ← your AppWalletScreen path

// ─── YOUR ADMIN EMAIL ─────────────────────────────────────────────────────────
const String kAdminEmail = 'alishaheersarwar@gmail.com'; // 🔴 must EXACTLY match Firebase Auth email
// ─────────────────────────────────────────────────────────────────────────────

class RoleSelection extends StatefulWidget {
  const RoleSelection({super.key});

  @override
  State<RoleSelection> createState() => _RoleSelectionState();
}

class _RoleSelectionState extends State<RoleSelection>
    with SingleTickerProviderStateMixin {

  static const Color primary    = Color(0xFF00D4FF);
  static const Color accent     = Color(0xFF00FFB3);
  static const Color bgDark     = Color(0xFF0D1B2A);
  static const Color bgCard     = Color(0xFF1A1A2E);
  static const Color bgDeep     = Color(0xFF0F3460);
  static const Color adminColor = Color(0xFF9B59B6);

  AnimationController? _controller;
  Animation<double>?   _fadeAnim;
  Animation<Offset>?   _slideAnim;

  bool   _isLoading    = false;
  String _selectedRole = '';
  bool   _isAdminEmail = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeOut));

    _controller!.forward();
    _checkAdminEmail();
  }

  // ── Check if logged-in email matches admin email ──────────────────────────
  void _checkAdminEmail() {
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    // 🔍 Debug prints — check Run console in Android Studio
    debugPrint('========================================');
    debugPrint('>>> Logged in as : "$currentEmail"');
    debugPrint('>>> Admin email   : "$kAdminEmail"');

    final bool matched = currentEmail.toLowerCase().trim() ==
        kAdminEmail.toLowerCase().trim();

    debugPrint('>>> Match result  : $matched');
    debugPrint('========================================');

    setState(() => _isAdminEmail = matched);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _selectRole(String role) async {
    // Admin — go straight to App Wallet screen
    if (role == 'Admin') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppWalletScreen()),
      );
      return;
    }

    setState(() {
      _selectedRole = role;
      _isLoading    = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(uid)
            .update({'role': role.toLowerCase()});
      }
      if (!mounted) return;

      if (role == 'Driver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PassengerProfileScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior:        SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fadeAnim == null || _slideAnim == null) {
      return const Scaffold(
        backgroundColor: bgDark,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bgDark,
      body: Stack(
        children: [

          // ── Background gradient ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [bgDark, bgCard, bgDeep],
              ),
            ),
          ),

          // ── Decorative circles ─────────────────────────────────────────────
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            top: 200, left: -40,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.04),
              ),
            ),
          ),

          // ── Main Content — wrapped in SingleChildScrollView ────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim!,
              child: SlideTransition(
                position: _slideAnim!,
                child: SingleChildScrollView(          // ✅ FIXES OVERFLOW
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        const SizedBox(height: 12),

                        // ── Back Button ──────────────────────────────────
                        Align(
                          alignment: Alignment.topLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            child: Container(
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bgDeep,
                                border: Border.all(color: primary, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: primary, size: 20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Logo ─────────────────────────────────────────
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [primary, accent],
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:        primary.withOpacity(0.35),
                                blurRadius:   24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Colors.white, size: 44,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── Title ─────────────────────────────────────────
                        const Text(
                          'Ride Together',
                          style: TextStyle(
                            color:         Colors.white,
                            fontSize:      30,
                            fontWeight:    FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Choose how you want to continue',
                          style: TextStyle(
                            color:    Colors.white.withOpacity(0.45),
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Divider ───────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text(
                                'SELECT YOUR ROLE',
                                style: TextStyle(
                                  color:         Colors.white.withOpacity(0.25),
                                  fontSize:      10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Driver Card ───────────────────────────────────
                        _roleCard(
                          role:        'Driver',
                          description: 'Offer rides and earn money',
                          icon:        Icons.drive_eta_rounded,
                          color:       primary,
                        ),

                        const SizedBox(height: 20),

                        // ── Passenger Card ────────────────────────────────
                        _roleCard(
                          role:        'Passenger',
                          description: 'Find rides and save money',
                          icon:        Icons.person_rounded,
                          color:       accent,
                        ),

                        // ── Admin Card (only your email sees this) ────────
                        if (_isAdminEmail) ...[
                          const SizedBox(height: 20),
                          _roleCard(
                            role:        'Admin',
                            description: 'Manage app wallet & earnings',
                            icon:        Icons.admin_panel_settings_rounded,
                            color:       adminColor,
                          ),
                        ],

                        const SizedBox(height: 40),

                        // ── Bottom label ──────────────────────────────────
                        Text(
                          'Smart Carpooling System',
                          style: TextStyle(
                            color:         Colors.white.withOpacity(0.25),
                            fontSize:      12,
                            letterSpacing: 1.5,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Loading Overlay ────────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedRole == 'Driver'
                          ? primary.withOpacity(0.4)
                          : accent.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(
                          color: _selectedRole == 'Driver' ? primary : accent,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Setting up your\n$_selectedRole account...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roleCard({
    required String   role,
    required String   description,
    required IconData icon,
    required Color    color,
  }) {
    final bool isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: _isLoading ? null : () => _selectRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:    double.infinity,
        padding:  const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isSelected ? color.withOpacity(0.12) : bgCard,
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.25),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:        color.withOpacity(isSelected ? 0.2 : 0.08),
              blurRadius:   20,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 65, height: 65,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  color.withOpacity(0.1),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      22,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      color:    Colors.white.withOpacity(0.45),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color, size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:ride_together/driver/driverprofile.dart';
// import 'package:ride_together/login_screen.dart';
// import 'package:ride_together/passenger/passenger_profile.dart';
//
// class RoleSelection extends StatefulWidget {
//   const RoleSelection({super.key});
//
//   @override
//   State<RoleSelection> createState() => _RoleSelectionState();
// }
//
// class _RoleSelectionState extends State<RoleSelection>
//     with SingleTickerProviderStateMixin {
//
//   static const Color primary = Color(0xFF00D4FF);
//   static const Color accent  = Color(0xFF00FFB3);
//   static const Color bgDark  = Color(0xFF0D1B2A);
//   static const Color bgCard  = Color(0xFF1A1A2E);
//   static const Color bgDeep  = Color(0xFF0F3460);
//
//   AnimationController? _controller;
//   Animation<double>?   _fadeAnim;
//   Animation<Offset>?   _slideAnim;
//
//   bool   _isLoading    = false;
//   String _selectedRole = '';
//
//   @override
//   void initState() {
//     super.initState();
//
//     _controller = AnimationController(
//       vsync:    this,
//       duration: const Duration(milliseconds: 900),
//     );
//     _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//           parent: _controller!, curve: Curves.easeOut),
//     );
//     _slideAnim = Tween<Offset>(
//       begin: const Offset(0, 0.12),
//       end:   Offset.zero,
//     ).animate(CurvedAnimation(
//         parent: _controller!, curve: Curves.easeOut));
//
//     _controller!.forward();
//   }
//
//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   Future<void> _selectRole(String role) async {
//     setState(() {
//       _selectedRole = role;
//       _isLoading    = true;
//     });
//     try {
//       final uid =
//           FirebaseAuth.instance.currentUser?.uid;
//       if (uid != null) {
//         await FirebaseDatabase.instance
//             .ref()
//             .child("users")
//             .child(uid)
//             .update({'role': role.toLowerCase()});
//       }
//       if (!mounted) return;
//       if (role == 'Driver') {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (_) =>
//               const DriverProfileScreen()),
//         );
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (_) =>
//               const PassengerProfileScreen()),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content:         Text('Error: $e'),
//           backgroundColor: Colors.red,
//           behavior:        SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_fadeAnim == null || _slideAnim == null) {
//       return const Scaffold(
//         backgroundColor: bgDark,
//         body: SizedBox.shrink(),
//       );
//     }
//
//     return Scaffold(
//       // ✅ Fix overflow — prevent keyboard resize
//       resizeToAvoidBottomInset: false,
//       backgroundColor: bgDark,
//       body: Stack(
//         children: [
//
//           // ── Background gradient ──────────────
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin:  Alignment.topCenter,
//                 end:    Alignment.bottomCenter,
//                 colors: [bgDark, bgCard, bgDeep],
//               ),
//             ),
//           ),
//
//           // ── Decorative circles ───────────────
//           Positioned(
//             top: -80, right: -80,
//             child: Container(
//               width: 260, height: 260,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: primary.withOpacity(0.05),
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: -100, left: -60,
//             child: Container(
//               width: 280, height: 280,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: accent.withOpacity(0.04),
//               ),
//             ),
//           ),
//           Positioned(
//             top: 200, left: -40,
//             child: Container(
//               width: 150, height: 150,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: primary.withOpacity(0.04),
//               ),
//             ),
//           ),
//
//           // ── Main Content ─────────────────────
//           SafeArea(
//             child: FadeTransition(
//               opacity: _fadeAnim!,
//               child: SlideTransition(
//                 position: _slideAnim!,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 24),
//                   child: Column(
//                     crossAxisAlignment:
//                     CrossAxisAlignment.center,
//                     children: [
//
//                       const SizedBox(height: 12),
//
//                       // ── Back Button ──────────
//                       Align(
//                         alignment: Alignment.topLeft,
//                         child: GestureDetector(
//                           onTap: () =>
//                               Navigator.pushReplacement(
//                                 context,
//                                 MaterialPageRoute(
//                                     builder: (_) =>
//                                     const LoginScreen()),
//                               ),
//                           child: Container(
//                             width: 45, height: 45,
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               color: bgDeep,
//                               border: Border.all(
//                                   color: primary,
//                                   width: 1.5),
//                             ),
//                             child: const Icon(
//                               Icons
//                                   .arrow_back_ios_new_rounded,
//                               color: primary,
//                               size:  20,
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 36),
//
//                       // ── Logo ─────────────────
//                       Container(
//                         width: 90, height: 90,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           gradient:
//                           const LinearGradient(
//                             colors: [primary, accent],
//                             begin:
//                             Alignment.topLeft,
//                             end:
//                             Alignment.bottomRight,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: primary
//                                   .withOpacity(0.35),
//                               blurRadius:   24,
//                               spreadRadius: 3,
//                             ),
//                           ],
//                         ),
//                         child: const Icon(
//                           Icons.directions_car_rounded,
//                           color: Colors.white,
//                           size:  44,
//                         ),
//                       ),
//
//                       const SizedBox(height: 22),
//
//                       // ── Title ────────────────
//                       const Text(
//                         'Ride Together',
//                         style: TextStyle(
//                           color:         Colors.white,
//                           fontSize:      30,
//                           fontWeight:    FontWeight.bold,
//                           letterSpacing: 1.2,
//                         ),
//                       ),
//
//                       const SizedBox(height: 8),
//
//                       // ── Subtitle ─────────────
//                       Text(
//                         'Choose how you want to continue',
//                         style: TextStyle(
//                           color: Colors.white
//                               .withOpacity(0.45),
//                           fontSize: 15,
//                         ),
//                       ),
//
//                       const SizedBox(height: 14),
//
//                       // ── Divider ──────────────
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Divider(
//                                 color: Colors.white
//                                     .withOpacity(0.08)),
//                           ),
//                           Padding(
//                             padding:
//                             const EdgeInsets.symmetric(
//                                 horizontal: 12),
//                             child: Text(
//                               'SELECT YOUR ROLE',
//                               style: TextStyle(
//                                 color: Colors.white
//                                     .withOpacity(0.25),
//                                 fontSize:      10,
//                                 letterSpacing: 2,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: Divider(
//                                 color: Colors.white
//                                     .withOpacity(0.08)),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 28),
//
//                       // ── Driver Card ──────────
//                       _roleCard(
//                         role:        'Driver',
//                         description:
//                         'Offer rides and earn money',
//                         icon:  Icons.drive_eta_rounded,
//                         color: primary,
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // ── Passenger Card ───────
//                       _roleCard(
//                         role:        'Passenger',
//                         description:
//                         'Find rides and save money',
//                         icon:  Icons.person_rounded,
//                         color: accent,
//                       ),
//
//                       // ✅ Use Spacer safely inside
//                       // Column without keyboard issues
//                       const SizedBox(height: 40),
//
//                       // ── Bottom label ─────────
//                       Text(
//                         'Smart Carpooling System',
//                         style: TextStyle(
//                           color: Colors.white
//                               .withOpacity(0.25),
//                           fontSize:      12,
//                           letterSpacing: 1.5,
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // ── Loading Overlay ──────────────────
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.55),
//               child: Center(
//                 child: Container(
//                   padding: const EdgeInsets.all(28),
//                   decoration: BoxDecoration(
//                     color: bgCard,
//                     borderRadius:
//                     BorderRadius.circular(20),
//                     border: Border.all(
//                       color: _selectedRole == 'Driver'
//                           ? primary.withOpacity(0.4)
//                           : accent.withOpacity(0.4),
//                     ),
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       SizedBox(
//                         width: 48, height: 48,
//                         child: CircularProgressIndicator(
//                           color:
//                           _selectedRole == 'Driver'
//                               ? primary
//                               : accent,
//                           strokeWidth: 3,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         'Setting up your\n$_selectedRole account...',
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           color:      Colors.white,
//                           fontSize:   14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _roleCard({
//     required String   role,
//     required String   description,
//     required IconData icon,
//     required Color    color,
//   }) {
//     final bool isSelected = _selectedRole == role;
//
//     return GestureDetector(
//       onTap:
//       _isLoading ? null : () => _selectRole(role),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         width:   double.infinity,
//         padding: const EdgeInsets.symmetric(
//             horizontal: 24, vertical: 28),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(22),
//           color: isSelected
//               ? color.withOpacity(0.12)
//               : bgCard,
//           border: Border.all(
//             color: isSelected
//                 ? color
//                 : color.withOpacity(0.25),
//             width: isSelected ? 2 : 1.5,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(
//                   isSelected ? 0.2 : 0.08),
//               blurRadius:   20,
//               spreadRadius: isSelected ? 2 : 0,
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 65, height: 65,
//               decoration: BoxDecoration(
//                 shape:  BoxShape.circle,
//                 color:  color.withOpacity(0.1),
//                 border: Border.all(
//                     color: color, width: 2),
//               ),
//               child: Icon(icon,
//                   color: color, size: 32),
//             ),
//             const SizedBox(width: 20),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment:
//                 CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     role,
//                     style: const TextStyle(
//                       color:         Colors.white,
//                       fontSize:      22,
//                       fontWeight:    FontWeight.bold,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                   const SizedBox(height: 5),
//                   Text(
//                     description,
//                     style: TextStyle(
//                       color: Colors.white
//                           .withOpacity(0.45),
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               width: 36, height: 36,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: color.withOpacity(0.12),
//               ),
//               child: Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 color: color,
//                 size:  16,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
