import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/global/global_var.dart';
import 'package:ride_together/landing_page.dart';
import 'package:ride_together/methods/common_methods.dart';
import 'package:ride_together/select_role_screen.dart';
import 'package:ride_together/signup_screen.dart';
import 'package:ride_together/widgets/loading.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final CommonMethods _cMethods = CommonMethods();

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  bool _isPasswordVisible = false;
  bool _isLoading         = false;

  // ── Palette — exact copy from role selection screen ─────────────────
  static const Color kBg    = Color(0xFF0D1B2A);
  static const Color kCard  = Color(0xFF1A1A2E);
  static const Color kDeep  = Color(0xFF0F3460);
  static const Color kCyan  = Color(0xFF00D4FF);
  static const Color kGreen = Color(0xFF00FFB3);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelection()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (!_emailController.text.contains('@')) {
      _cMethods.displaySnackBar('Please enter a valid email.', context);
      return false;
    } else if (_passwordController.text.trim().length < 6) {
      _cMethods.displaySnackBar('Password must be at least 6 characters.', context);
      return false;
    }
    return true;
  }

  Future<void> _checkNetwork() async {
    if (_validateForm()) {
      bool isConnected = await CommonMethods.checkConnectivity(context);
      if (isConnected) _loginUser();
    }
  }

  Future<void> _loginUser() async {
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder:            (_) => LoadingDialog(messageText: 'Logging you in...'),
    );
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;
      if (!context.mounted) return;

      if (user != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref().child('users').child(user.uid).get();
        if (!context.mounted) return;

        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          if (data['blockStatus'] == 'yes') {
            await FirebaseAuth.instance.signOut();
            if (!context.mounted) return;
            Navigator.pop(context);
            _cMethods.displaySnackBar(
                'Your account has been blocked. Contact support.', context);
            return;
          }
          userName = data['name'] ?? '';
          Navigator.pop(context);
          if (!context.mounted) return;
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const RoleSelection()));
        } else {
          Navigator.pop(context);
          _cMethods.displaySnackBar(
              'User data not found. Please sign up again.', context);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      String message = 'Login failed. Try again.';
      if (e.code == 'user-not-found')
        message = 'No account found with this email.';
      else if (e.code == 'wrong-password')
        message = 'Incorrect password. Try again.';
      else if (e.code == 'invalid-email')
        message = 'Invalid email address.';
      else if (e.code == 'too-many-requests')
        message = 'Too many attempts. Try again later.';
      _cMethods.displaySnackBar(message, context);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _cMethods.displaySnackBar(e.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: kBg,
        body: Stack(
          children: [

            // ── Background — same 3-stop gradient as role selection ─────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [kBg, kCard, kDeep],
                ),
              ),
            ),

            // ── Glowing orb top-right — same as role selection ──────────
            Positioned(
              top: -80, right: -80,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kCyan.withOpacity(0.18),
                      kCyan.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── Glowing orb bottom-left ─────────────────────────────────
            Positioned(
              bottom: -100, left: -60,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kGreen.withOpacity(0.12),
                      kGreen.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── Small orb mid-left ──────────────────────────────────────
            Positioned(
              top: 220, left: -50,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kCyan.withOpacity(0.08),
                      kCyan.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── Main Scrollable Content ─────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        const SizedBox(height: 12),

                        // ── Back Button — same cyan circle as role screen
                        Align(
                          alignment: Alignment.topLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacement(context,
                                MaterialPageRoute(
                                    builder: (_) => const LandingPage())),
                            child: Container(
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kDeep,
                                border: Border.all(color: kCyan, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: kCyan, size: 20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Logo — same gradient glow circle ────────────
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [kCyan, kGreen],
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:        kCyan.withOpacity(0.45),
                                blurRadius:   30,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color:        kGreen.withOpacity(0.2),
                                blurRadius:   60,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Colors.white,
                            size:  44,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── App name ─────────────────────────────────────
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
                          'Sign in to continue your journey',
                          style: TextStyle(
                            color:    Colors.white.withOpacity(0.45),
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Divider ───────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.08))),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'SIGN IN',
                                style: TextStyle(
                                  color:         Colors.white.withOpacity(0.25),
                                  fontSize:      10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.08))),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Form card ─────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: kCyan.withOpacity(0.15), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color:      kCyan.withOpacity(0.05),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [

                              // Email
                              _buildField(
                                controller:   _emailController,
                                hint:         'Email address',
                                icon:         Icons.alternate_email_rounded,
                                accentColor:  kCyan,
                                keyboardType: TextInputType.emailAddress,
                              ),

                              const SizedBox(height: 14),

                              // Password
                              _buildField(
                                controller:  _passwordController,
                                hint:        'Password',
                                icon:        Icons.lock_outline_rounded,
                                accentColor: kGreen,
                                isPassword:  true,
                              ),

                              const SizedBox(height: 30),

                              // Sign In button — same gradient as role cards
                              GestureDetector(
                                onTap: _isLoading ? null : _checkNetwork,
                                child: AnimatedContainer(
                                  duration:
                                  const Duration(milliseconds: 200),
                                  width:  double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: _isLoading
                                          ? [
                                        kCyan.withOpacity(0.4),
                                        kGreen.withOpacity(0.4)
                                      ]
                                          : [kCyan, kGreen],
                                      begin: Alignment.centerLeft,
                                      end:   Alignment.centerRight,
                                    ),
                                    boxShadow: _isLoading
                                        ? []
                                        : [
                                      BoxShadow(
                                        color:      kCyan.withOpacity(0.4),
                                        blurRadius: 20,
                                        offset:
                                        const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                      width:  22,
                                      height: 22,
                                      child:  CircularProgressIndicator(
                                        color:       Colors.black,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                        : const Row(
                                      mainAxisSize:
                                      MainAxisSize.min,
                                      children: [
                                        Icon(Icons.login_rounded,
                                            color: Colors.black,
                                            size:  20),
                                        SizedBox(width: 10),
                                        Text(
                                          'SIGN IN',
                                          style: TextStyle(
                                            color:         Colors.black,
                                            fontSize:      15,
                                            fontWeight:
                                            FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Sign Up link ──────────────────────────────────
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignUpScreen())),
                          child: Container(
                            width:  double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color:        kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1.5),
                            ),
                            child: Center(
                              child: RichText(
                                text: TextSpan(
                                  text: "Don't have an account?  ",
                                  style: TextStyle(
                                    color:    Colors.white.withOpacity(0.4),
                                    fontSize: 14,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Sign Up',
                                      style: TextStyle(
                                        color:      kGreen,
                                        fontWeight: FontWeight.w700,
                                        fontSize:   14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String                hint,
    required IconData              icon,
    required Color                 accentColor,
    bool          isPassword   = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        kDeep.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: TextField(
        controller:   controller,
        obscureText:  isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        cursorColor:  accentColor,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          prefixIcon: Icon(icon, color: accentColor.withOpacity(0.7), size: 20),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.white38,
              size:  20,
            ),
            onPressed: () => setState(
                    () => _isPasswordVisible = !_isPasswordVisible),
          )
              : null,
          hintText:  hint,
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.28), fontSize: 14),
          border:        InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}




// import 'dart:math' as math;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:ride_together/global/global_var.dart';
// import 'package:ride_together/landing_page.dart';
// import 'package:ride_together/methods/common_methods.dart';
// import 'package:ride_together/select_role_screen.dart';
// import 'package:ride_together/signup_screen.dart';
// import 'package:ride_together/widgets/loading.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen>
//     with TickerProviderStateMixin {
//
//   // ── Controllers ────────────────────────────────────────────────────────────
//   final TextEditingController _emailController    = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final CommonMethods _cMethods = CommonMethods();
//
//   // ── Animation Controllers ──────────────────────────────────────────────────
//   late AnimationController _bgController;   // rotating background orbs
//   late AnimationController _entryController; // staggered entry
//   late AnimationController _pulseController; // logo pulse
//
//   late Animation<double> _fadeAnim;
//   late Animation<Offset> _slideEmailAnim;
//   late Animation<Offset> _slidePassAnim;
//   late Animation<Offset> _slideBtnAnim;
//   late Animation<double> _logoScaleAnim;
//   late Animation<double> _pulseAnim;
//   late Animation<double> _bgRotateAnim;
//
//   // ── State ──────────────────────────────────────────────────────────────────
//   bool _isPasswordVisible = false;
//   bool _isLoading         = false;
//   bool _emailFocused      = false;
//   bool _passFocused       = false;
//
//   final FocusNode _emailFocus = FocusNode();
//   final FocusNode _passFocus  = FocusNode();
//
//   // ── Palette ────────────────────────────────────────────────────────────────
//   static const Color kBg      = Color(0xFF060B18);
//   static const Color kSurface = Color(0xFF0E1628);
//   static const Color kCard    = Color(0xFF111827);
//   static const Color kCyan    = Color(0xFF00D4FF);
//   static const Color kGreen   = Color(0xFF00FFB3);
//   static const Color kGold    = Color(0xFFFFD166);
//   static const Color kBorder  = Color(0xFF1E2D45);
//
//   //@override
//   // void initState() {
//   //   super.initState();
//   //
//   //   // Background rotating animation (infinite)
//   //   _bgController = AnimationController(
//   //     vsync:    this,
//   //     duration: const Duration(seconds: 20),
//   //   )..repeat();
//   //
//   //   _bgRotateAnim = Tween<double>(begin: 0, end: 2 * math.pi)
//   //       .animate(_bgController);
//   //
//   //   // Pulse animation for logo (infinite)
//   //   _pulseController = AnimationController(
//   //     vsync:    this,
//   //     duration: const Duration(milliseconds: 1800),
//   //   )..repeat(reverse: true);
//   //
//   //   _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
//   //     CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//   //   );
//   //
//   //   // Entry animations (one-shot)
//   //   _entryController = AnimationController(
//   //     vsync:    this,
//   //     duration: const Duration(milliseconds: 1200),
//   //   );
//   //
//   //   _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
//   //     CurvedAnimation(
//   //       parent: _entryController,
//   //       curve:  const Interval(0.0, 0.5, curve: Curves.easeOut),
//   //     ),
//   //   );
//   //
//   //   _logoScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
//   //     CurvedAnimation(
//   //       parent: _entryController,
//   //       curve:  const Interval(0.0, 0.55, curve: Curves.elasticOut),
//   //     ),
//   //   );
//   //
//   //   _slideEmailAnim = Tween<Offset>(
//   //     begin: const Offset(0, 0.3),
//   //     end:   Offset.zero,
//   //   ).animate(CurvedAnimation(
//   //     parent: _entryController,
//   //     curve:  const Interval(0.3, 0.7, curve: Curves.easeOut),
//   //   ));
//   //
//   //   _slidePassAnim = Tween<Offset>(
//   //     begin: const Offset(0, 0.3),
//   //     end:   Offset.zero,
//   //   ).animate(CurvedAnimation(
//   //     parent: _entryController,
//   //     curve:  const Interval(0.45, 0.8, curve: Curves.easeOut),
//   //   ));
//   //
//   //   _slideBtnAnim = Tween<Offset>(
//   //     begin: const Offset(0, 0.3),
//   //     end:   Offset.zero,
//   //   ).animate(CurvedAnimation(
//   //     parent: _entryController,
//   //     curve:  const Interval(0.6, 1.0, curve: Curves.easeOut),
//   //   ));
//   //
//   //   _entryController.forward();
//   //
//   //   // Focus listeners for field glow effect
//   //   _emailFocus.addListener(() =>
//   //       setState(() => _emailFocused = _emailFocus.hasFocus));
//   //   _passFocus.addListener(() =>
//   //       setState(() => _passFocused = _passFocus.hasFocus));
//   //
//   //   // Auto-redirect if already logged in
//   //   WidgetsBinding.instance.addPostFrameCallback((_) {
//   //     final user = FirebaseAuth.instance.currentUser;
//   //     if (user != null && mounted) {
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (_) => const RoleSelection()),
//   //       );
//   //     }
//   //   });
//   // }
//
//   @override
//   void dispose() {
//     _bgController.dispose();
//     _entryController.dispose();
//     _pulseController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _emailFocus.dispose();
//     _passFocus.dispose();
//     super.dispose();
//   }
//
//   // ── Validation ─────────────────────────────────────────────────────────────
//   bool _validateForm() {
//     if (!_emailController.text.contains('@')) {
//       _cMethods.displaySnackBar('Please enter a valid email.', context);
//       return false;
//     } else if (_passwordController.text.trim().length < 6) {
//       _cMethods.displaySnackBar(
//           'Password must be at least 6 characters.', context);
//       return false;
//     }
//     return true;
//   }
//
//   Future<void> _checkNetwork() async {
//     if (_validateForm()) {
//       bool isConnected = await CommonMethods.checkConnectivity(context);
//       if (isConnected) _loginUser();
//     }
//   }
//
//   // ── Login Logic (unchanged from original) ──────────────────────────────────
//   Future<void> _loginUser() async {
//     showDialog(
//       context:            context,
//       barrierDismissible: false,
//       builder:            (_) => LoadingDialog(messageText: 'Logging you in...'),
//     );
//
//     try {
//       final userCredential = await FirebaseAuth.instance
//           .signInWithEmailAndPassword(
//         email:    _emailController.text.trim(),
//         password: _passwordController.text.trim(),
//       );
//
//       final User? user = userCredential.user;
//       if (!context.mounted) return;
//
//       if (user != null) {
//         final snapshot = await FirebaseDatabase.instance
//             .ref()
//             .child('users')
//             .child(user.uid)
//             .get();
//
//         if (!context.mounted) return;
//
//         if (snapshot.exists) {
//           final data = Map<String, dynamic>.from(snapshot.value as Map);
//
//           if (data['blockStatus'] == 'yes') {
//             await FirebaseAuth.instance.signOut();
//             if (!context.mounted) return;
//             Navigator.pop(context);
//             _cMethods.displaySnackBar(
//                 'Your account has been blocked. Contact support.', context);
//             return;
//           }
//
//           userName = data['name'] ?? '';
//           Navigator.pop(context);
//
//           if (!context.mounted) return;
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const RoleSelection()),
//           );
//         } else {
//           Navigator.pop(context);
//           _cMethods.displaySnackBar(
//               'User data not found. Please sign up again.', context);
//         }
//       }
//     } on FirebaseAuthException catch (e) {
//       if (!context.mounted) return;
//       Navigator.pop(context);
//       String message = 'Login failed. Try again.';
//       if (e.code == 'user-not-found')
//         message = 'No account found with this email.';
//       else if (e.code == 'wrong-password')
//         message = 'Incorrect password. Try again.';
//       else if (e.code == 'invalid-email')
//         message = 'Invalid email address.';
//       else if (e.code == 'too-many-requests')
//         message = 'Too many attempts. Try again later.';
//       _cMethods.displaySnackBar(message, context);
//     } catch (e) {
//       if (!context.mounted) return;
//       Navigator.pop(context);
//       _cMethods.displaySnackBar(e.toString(), context);
//     }
//   }
//
//   // ── BUILD ──────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: kBg,
//         resizeToAvoidBottomInset: true,
//         body: Stack(
//           children: [
//
//             // ── Animated Background ────────────────────────────────────────
//             // AnimatedBuilder(
//             //   animation: _bgRotateAnim,
//             //   builder: (_, __) => Stack(
//             //     children: [
//             //       // Deep base
//             //       Container(
//             //         decoration: const BoxDecoration(
//             //           gradient: RadialGradient(
//             //             center: Alignment(-0.3, -0.5),
//             //             radius: 1.2,
//             //             colors: [Color(0xFF0A1628), kBg],
//             //           ),
//             //         ),
//             //       ),
//             //       // Rotating orb 1 — cyan
//             //       Positioned(
//             //         top:  size.height * 0.05 +
//             //             math.sin(_bgRotateAnim.value) * 30,
//             //         right: -size.width * 0.25 +
//             //             math.cos(_bgRotateAnim.value) * 20,
//             //         child: Container(
//             //           width: size.width * 0.75,
//             //           height: size.width * 0.75,
//             //           decoration: BoxDecoration(
//             //             shape: BoxShape.circle,
//             //             gradient: RadialGradient(
//             //               colors: [
//             //                 kCyan.withOpacity(0.12),
//             //                 kCyan.withOpacity(0.0),
//             //               ],
//             //             ),
//             //           ),
//             //         ),
//             //       ),
//             //       // Rotating orb 2 — green
//             //       Positioned(
//             //         bottom: size.height * 0.1 +
//             //             math.cos(_bgRotateAnim.value) * 25,
//             //         left: -size.width * 0.2 +
//             //             math.sin(_bgRotateAnim.value) * 15,
//             //         child: Container(
//             //           width: size.width * 0.65,
//             //           height: size.width * 0.65,
//             //           decoration: BoxDecoration(
//             //             shape: BoxShape.circle,
//             //             gradient: RadialGradient(
//             //               colors: [
//             //                 kGreen.withOpacity(0.10),
//             //                 kGreen.withOpacity(0.0),
//             //               ],
//             //             ),
//             //           ),
//             //         ),
//             //       ),
//             //       // Gold streak
//             //       Positioned(
//             //         top:  size.height * 0.42,
//             //         left: size.width * 0.6,
//             //         child: Transform.rotate(
//             //           angle: -0.4,
//             //           child: Container(
//             //             width:  2,
//             //             height: size.height * 0.18,
//             //             decoration: BoxDecoration(
//             //               gradient: LinearGradient(
//             //                 begin:  Alignment.topCenter,
//             //                 end:    Alignment.bottomCenter,
//             //                 colors: [
//             //                   kGold.withOpacity(0.0),
//             //                   kGold.withOpacity(0.18),
//             //                   kGold.withOpacity(0.0),
//             //                 ],
//             //               ),
//             //             ),
//             //           ),
//             //         ),
//             //       ),
//             //     ],
//             //   ),
//             // ),
//
//             // ── Main Scrollable Content ────────────────────────────────────
//             SafeArea(
//               child: SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 padding: const EdgeInsets.symmetric(horizontal: 28),
//                 child: FadeTransition(
//                   opacity: _fadeAnim,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//
//                       const SizedBox(height: 16),
//
//                       // ── Top bar ──────────────────────────────────────
//                       Row(
//                         children: [
//                           // Back button
//                           GestureDetector(
//                             onTap: () => Navigator.pushReplacement(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (_) => const LandingPage()),
//                             ),
//                             child: Container(
//                               width: 44, height: 44,
//                               decoration: BoxDecoration(
//                                 shape:   BoxShape.circle,
//                                 color:   kSurface,
//                                 border:  Border.all(color: kBorder, width: 1.5),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color:      kCyan.withOpacity(0.08),
//                                     blurRadius: 12,
//                                   ),
//                                 ],
//                               ),
//                               child: const Icon(
//                                 Icons.arrow_back_ios_new_rounded,
//                                 color: kCyan, size: 18,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 25),
//
//                       // ── Logo ─────────────────────────────────────────
//                       ScaleTransition(
//                         scale: _logoScaleAnim,
//                         child: AnimatedBuilder(
//                           animation: _pulseAnim,
//                           builder: (_, child) => Transform.scale(
//                             scale: _pulseAnim.value,
//                             child: child,
//                           ),
//                           child: Stack(
//                             alignment: Alignment.center,
//                             children: [
//                               // Outer glow ring
//                               Container(
//                                 width: 110, height: 110,
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   border: Border.all(
//                                     color: kCyan.withOpacity(0.15),
//                                     width: 1,
//                                   ),
//                                 ),
//                               ),
//                               // Middle ring
//                               Container(
//                                 width: 96, height: 96,
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   border: Border.all(
//                                     color: kCyan.withOpacity(0.25),
//                                     width: 1,
//                                   ),
//                                 ),
//                               ),
//                               // Logo circle
//                               Container(
//                                 width: 80, height: 80,
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   gradient: const LinearGradient(
//                                     colors: [kCyan, kGreen],
//                                     begin:  Alignment.topLeft,
//                                     end:    Alignment.bottomRight,
//                                   ),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color:        kCyan.withOpacity(0.4),
//                                       blurRadius:   28,
//                                       spreadRadius: 2,
//                                     ),
//                                     BoxShadow(
//                                       color:        kGreen.withOpacity(0.2),
//                                       blurRadius:   50,
//                                       spreadRadius: 5,
//                                     ),
//                                   ],
//                                 ),
//                                 child: const Icon(
//                                   Icons.directions_car_rounded,
//                                   color: Colors.white,
//                                   size:  38,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 28),
//
//                       // ── Headline ──────────────────────────────────────
//                       ShaderMask(
//                         shaderCallback: (bounds) => const LinearGradient(
//                           colors: [kCyan, kGreen],
//                         ).createShader(bounds),
//                         child: const Text(
//                           'Ride Together',
//                           style: TextStyle(
//                             color:         Colors.white,
//                             fontSize:      32,
//                             fontWeight:    FontWeight.w900,
//                             letterSpacing: 0.5,
//                             height:        1.1,
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 8),
//
//                       Text(
//                         'Welcome back — sign in to continue',
//                         style: TextStyle(
//                           color:    Colors.white,
//                           fontSize: 14,
//                           height:   1.5,
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // ── Form Card ─────────────────────────────────────
//                       Container(
//                         padding: const EdgeInsets.all(26),
//                         decoration: BoxDecoration(
//                           color:        kCard,
//                           borderRadius: BorderRadius.circular(28),
//                           border:       Border.all(color: kBorder, width: 1),
//                           boxShadow: [
//                             BoxShadow(
//                               color:      Colors.black.withOpacity(0.4),
//                               blurRadius: 30,
//                               offset:     const Offset(0, 10),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//
//                             // Section label
//                             Text(
//                               'YOUR CREDENTIALS',
//                               style: TextStyle(
//                                 color:         Colors.white,
//                                 fontSize:      10,
//                                 letterSpacing: 2.5,
//                                 fontWeight:    FontWeight.w700,
//                               ),
//                             ),
//
//                             const SizedBox(height: 20),
//
//                             // ── Email Field ─────────────────────────────
//                             SlideTransition(
//                               position: _slideEmailAnim,
//                               child: _buildField(
//                                 controller:   _emailController,
//                                 focusNode:    _emailFocus,
//                                 label:        'Email address',
//                                 hint:         'you@example.com',
//                                 icon:         Icons.alternate_email_rounded,
//                                 isFocused:    _emailFocused,
//                                 keyboardType: TextInputType.emailAddress,
//                                 accentColor:  kCyan,
//                               ),
//                             ),
//
//                             const SizedBox(height: 16),
//
//                             // ── Password Field ──────────────────────────
//                             SlideTransition(
//                               position: _slidePassAnim,
//                               child: _buildField(
//                                 controller:  _passwordController,
//                                 focusNode:   _passFocus,
//                                 label:       'Password',
//                                 hint:        '••••••••',
//                                 icon:        Icons.lock_outline_rounded,
//                                 isFocused:   _passFocused,
//                                 isPassword:  true,
//                                 accentColor: kGreen,
//                               ),
//                             ),
//
//                             const SizedBox(height: 28),
//
//                             // ── Login Button ────────────────────────────
//                             SlideTransition(
//                               position: _slideBtnAnim,
//                               child: GestureDetector(
//                                 onTap: _isLoading ? null : _checkNetwork,
//                                 child: AnimatedContainer(
//                                   duration: const Duration(milliseconds: 200),
//                                   width:  double.infinity,
//                                   height: 56,
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(16),
//                                     gradient: _isLoading
//                                         ? LinearGradient(
//                                       colors: [
//                                         kCyan.withOpacity(0.4),
//                                         kGreen.withOpacity(0.4),
//                                       ],
//                                     )
//                                         : const LinearGradient(
//                                       colors: [kCyan, kGreen],
//                                       begin: Alignment.centerLeft,
//                                       end:   Alignment.centerRight,
//                                     ),
//                                     boxShadow: _isLoading
//                                         ? []
//                                         : [
//                                       BoxShadow(
//                                         color:      kCyan.withOpacity(0.35),
//                                         blurRadius: 20,
//                                         offset:     const Offset(0, 6),
//                                       ),
//                                     ],
//                                   ),
//                                   child: Center(
//                                     child: _isLoading
//                                         ? const SizedBox(
//                                       width:  22,
//                                       height: 22,
//                                       child:  CircularProgressIndicator(
//                                         color:       Colors.white,
//                                         strokeWidth: 2.5,
//                                       ),
//                                     )
//                                         : Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: const [
//                                         Text(
//                                           'SIGN IN',
//                                           style: TextStyle(
//                                             color:         Colors.white,
//                                             fontSize:      15,
//                                             fontWeight:    FontWeight.w800,
//                                             letterSpacing: 2.5,
//                                           ),
//                                         ),
//                                         SizedBox(width: 10),
//                                         Icon(
//                                           Icons.arrow_forward_rounded,
//                                           color: Colors.white,
//                                           size:  18,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       const SizedBox(height: 40),
//
//                       // ── Sign Up Button ─────────────────────────────────
//                       GestureDetector(
//                         onTap: () => Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                               builder: (_) => const SignUpScreen()),
//                         ),
//                         child: Container(
//                           width:   double.infinity,
//                           height:  52,
//                           decoration: BoxDecoration(
//                             color:        Colors.transparent,
//                             borderRadius: BorderRadius.circular(16),
//                             border:       Border.all(
//                               color: kBorder,
//                               width: 1.5,
//                             ),
//                           ),
//                           child: Center(
//                             child: RichText(
//                               text: const TextSpan(
//                                 text:  "Don't have an account?  ",
//                                 style: TextStyle(
//                                   color:    Color(0xFF4A6080),
//                                   fontSize: 14,
//                                 ),
//                                 children: [
//                                   TextSpan(
//                                     text: 'Sign Up',
//                                     style: TextStyle(
//                                       color:      kGreen,
//                                       fontWeight: FontWeight.w700,
//                                       fontSize:   14,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 24),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Reusable Field Builder ─────────────────────────────────────────────────
//   Widget _buildField({
//     required TextEditingController controller,
//     required FocusNode             focusNode,
//     required String                label,
//     required String                hint,
//     required IconData              icon,
//     required bool                  isFocused,
//     required Color                 accentColor,
//     bool          isPassword   = false,
//     TextInputType keyboardType = TextInputType.text,
//   }) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 250),
//       decoration: BoxDecoration(
//         color:        isFocused
//             ? accentColor.withOpacity(0.06)
//             : kSurface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: isFocused ? accentColor.withOpacity(0.6) : kBorder,
//           width: isFocused ? 1.5 : 1,
//         ),
//         boxShadow: isFocused
//             ? [
//           BoxShadow(
//             color:      accentColor.withOpacity(0.12),
//             blurRadius: 16,
//             spreadRadius: 1,
//           ),
//         ]
//             : [],
//       ),
//       child: TextField(
//         controller:    controller,
//         focusNode:     focusNode,
//         obscureText:   isPassword && !_isPasswordVisible,
//         keyboardType:  keyboardType,
//         cursorColor:   accentColor,
//         cursorWidth:   1.5,
//         style: const TextStyle(
//           color:    Colors.white,
//           fontSize: 15,
//           height:   1.4,
//         ),
//         decoration: InputDecoration(
//           contentPadding: const EdgeInsets.symmetric(
//               horizontal: 18, vertical: 18),
//           prefixIcon: Padding(
//             padding: const EdgeInsets.only(left: 14, right: 10),
//             child: Icon(
//               icon,
//               color: isFocused ? accentColor : Colors.white30,
//               size:  20,
//             ),
//           ),
//           prefixIconConstraints: const BoxConstraints(
//             minWidth:  0,
//             minHeight: 0,
//           ),
//           suffixIcon: isPassword
//               ? GestureDetector(
//             onTap: () => setState(
//                     () => _isPasswordVisible = !_isPasswordVisible),
//             child: Padding(
//               padding: const EdgeInsets.only(right: 14),
//               child: Icon(
//                 _isPasswordVisible
//                     ? Icons.visibility_rounded
//                     : Icons.visibility_off_rounded,
//                 color: Colors.white24,
//                 size:  20,
//               ),
//             ),
//           )
//               : null,
//           suffixIconConstraints: const BoxConstraints(
//             minWidth:  0,
//             minHeight: 0,
//           ),
//           labelText:  label,
//           hintText:   hint,
//           hintStyle:  TextStyle(
//             color:    Colors.white.withOpacity(0.15),
//             fontSize: 14,
//           ),
//           labelStyle: TextStyle(
//             color:    isFocused ? accentColor : Colors.white30,
//             fontSize: 13,
//           ),
//           floatingLabelStyle: TextStyle(
//             color:    accentColor,
//             fontSize: 12,
//           ),
//           border:        InputBorder.none,
//           focusedBorder: InputBorder.none,
//           enabledBorder: InputBorder.none,
//         ),
//       ),
//     );
//   }
// }
//
