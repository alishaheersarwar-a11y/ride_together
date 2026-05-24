import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/landing_page.dart';
import 'package:ride_together/methods/common_methods.dart';
import 'package:ride_together/select_role_screen.dart';
import 'package:ride_together/widgets/loading.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _nameController     = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _phoneController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  bool _isPasswordVisible = false;
  bool _isLoading         = false;

  final CommonMethods _cMethods = CommonMethods();

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
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_nameController.text.trim().length < 3) {
      _cMethods.displaySnackBar('Name must be at least 3 characters.', context);
      return false;
    } else if (!_emailController.text.contains('@')) {
      _cMethods.displaySnackBar('Please enter a valid email.', context);
      return false;
    } else if (_phoneController.text.trim().length < 10) {
      _cMethods.displaySnackBar('Phone must be at least 10 digits.', context);
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
      if (isConnected) _registerNewUser();
    }
  }

  Future<void> _registerNewUser() async {
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder:            (_) => LoadingDialog(messageText: 'Creating your account...'),
    );
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;
      if (!context.mounted) return;

      if (user != null) {
        await FirebaseDatabase.instance.ref().child('users').child(user.uid).set({
          'name':        _nameController.text.trim(),
          'email':       _emailController.text.trim(),
          'phone':       _phoneController.text.trim(),
          'id':          user.uid,
          'blockStatus': 'no',
          'createdAt':   DateTime.now().toString(),
        });
        if (!context.mounted) return;
        Navigator.pop(context);
        _cMethods.displaySnackBar('Account created successfully!', context);
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const RoleSelection()));
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _cMethods.displaySnackBar(e.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kBg,
      body: Stack(
        children: [

          // ── Background gradient — same as role selection ───────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [kBg, kCard, kDeep],
              ),
            ),
          ),

          // ── Glowing orb top-right ──────────────────────────────────────
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kCyan.withOpacity(0.18), kCyan.withOpacity(0.0)],
                ),
              ),
            ),
          ),

          // ── Glowing orb bottom-left ────────────────────────────────────
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kGreen.withOpacity(0.12), kGreen.withOpacity(0.0)],
                ),
              ),
            ),
          ),

          // ── Small orb mid-left ─────────────────────────────────────────
          Positioned(
            top: 220, left: -50,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kCyan.withOpacity(0.08), kCyan.withOpacity(0.0)],
                ),
              ),
            ),
          ),

          // ── Main Content ───────────────────────────────────────────────
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

                      // ── Back Button — same cyan circle ─────────────────
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

                      const SizedBox(height: 32),

                      // ── Logo — same gradient glow circle ───────────────
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

                      // ── App name ───────────────────────────────────────
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
                        'Join the carpooling community',
                        style: TextStyle(
                          color:    Colors.white.withOpacity(0.45),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Divider ────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: Colors.white.withOpacity(0.08))),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'CREATE ACCOUNT',
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

                      // ── Form card ──────────────────────────────────────
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(
                              'YOUR DETAILS',
                              style: TextStyle(
                                color:         Colors.white.withOpacity(0.25),
                                fontSize:      10,
                                letterSpacing: 2.5,
                                fontWeight:    FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 18),

                            _buildField(
                              controller:  _nameController,
                              hint:        'Full Name',
                              icon:        Icons.person_outline_rounded,
                              accentColor: kCyan,
                            ),
                            const SizedBox(height: 14),

                            _buildField(
                              controller:   _emailController,
                              hint:         'Email address',
                              icon:         Icons.alternate_email_rounded,
                              accentColor:  kCyan,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),

                            _buildField(
                              controller:   _phoneController,
                              hint:         'Phone Number',
                              icon:         Icons.phone_outlined,
                              accentColor:  kCyan,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 14),

                            _buildField(
                              controller:  _passwordController,
                              hint:        'Password',
                              icon:        Icons.lock_outline_rounded,
                              accentColor: kGreen,
                              isPassword:  true,
                            ),

                            const SizedBox(height: 26),

                            // Sign Up button
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
                                      color:
                                      kCyan.withOpacity(0.4),
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons
                                              .person_add_rounded,
                                          color: Colors.black,
                                          size:  20),
                                      SizedBox(width: 10),
                                      Text(
                                        'CREATE ACCOUNT',
                                        style: TextStyle(
                                          color:      Colors.black,
                                          fontSize:   14,
                                          fontWeight:
                                          FontWeight.w900,
                                          letterSpacing: 1.5,
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

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
          prefixIcon:
          Icon(icon, color: accentColor.withOpacity(0.7), size: 20),
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






// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:ride_together/landing_page.dart';
// import 'package:ride_together/methods/common_methods.dart';
// import 'package:ride_together/select_role_screen.dart';
// import 'package:ride_together/widgets/loading.dart';
//
// class SignUpScreen extends StatefulWidget {
//   const SignUpScreen({super.key});
//
//   @override
//   State<SignUpScreen> createState() => _SignUpScreenState();
// }
//
// class _SignUpScreenState extends State<SignUpScreen> {
//
//   // ── Controllers ────────────────────────────────────────────────────
//   final TextEditingController _nameController     = TextEditingController();
//   final TextEditingController _emailController    = TextEditingController();
//   final TextEditingController _phoneController    = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//
//   // ── State ───────────────────────────────────────────────────────────
//   bool _isPasswordVisible = false;
//   bool _isLoading         = false;
//
//   final CommonMethods _cMethods = CommonMethods();
//
//   // ── Palette — 100% copied from login screen ─────────────────────────
//   static const Color kBg     = Color(0xFF0E1621);   // dark navy bg
//   static const Color kSurface = Color(0xFF0E1628);
//   static const Color kCard   = Color(0xFF131E2D);   // dark card
//   static const Color kField  = Color(0xFF1A2535);   // dark field bg
//   static const Color kCyan   = Color(0xFF00FFB3);   // cyan accent
//   static const Color kBorder  = Color(0xFF1E2D45);
//   //static const Color kBorder = Color(0xFF1E2D3D);   // subtle border
//   static const Color kIcon   = Color(0xFF4A6080);   // grey icon
//   static const Color kCyanG1 = Color(0xFF00D4FF);   // gradient start
//   static const Color kCyanG2 = Color(0xFF00FFB3);   // gradient end
//
//
//
//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
//
//   // ── Validation ──────────────────────────────────────────────────────
//   bool _validateForm() {
//     if (_nameController.text.trim().length < 3) {
//       _cMethods.displaySnackBar("Name must be at least 3 characters.", context);
//       return false;
//     } else if (!_emailController.text.contains("@")) {
//       _cMethods.displaySnackBar("Please enter a valid email.", context);
//       return false;
//     } else if (_phoneController.text.trim().length < 10) {
//       _cMethods.displaySnackBar("Phone must be at least 10 digits.", context);
//       return false;
//     } else if (_passwordController.text.trim().length < 6) {
//       _cMethods.displaySnackBar("Password must be at least 6 characters.", context);
//       return false;
//     }
//     return true;
//   }
//
//   Future<void> _checkNetwork() async {
//     if (_validateForm()) {
//       bool isConnected = await CommonMethods.checkConnectivity(context);
//       if (isConnected) _registerNewUser();
//     }
//   }
//
//   // ── Register ────────────────────────────────────────────────────────
//   Future<void> _registerNewUser() async {
//     showDialog(
//       context:            context,
//       barrierDismissible: false,
//       builder:            (_) => LoadingDialog(messageText: "Creating your account..."),
//     );
//
//     try {
//       final userCredential = await FirebaseAuth.instance
//           .createUserWithEmailAndPassword(
//         email:    _emailController.text.trim(),
//         password: _passwordController.text.trim(),
//       );
//
//       final User? user = userCredential.user;
//       if (!context.mounted) return;
//
//       if (user != null) {
//         await FirebaseDatabase.instance
//             .ref()
//             .child("users")
//             .child(user.uid)
//             .set({
//           "name":        _nameController.text.trim(),
//           "email":       _emailController.text.trim(),
//           "phone":       _phoneController.text.trim(),
//           "id":          user.uid,
//           "blockStatus": "no",
//           "createdAt":   DateTime.now().toString(),
//         });
//
//         if (!context.mounted) return;
//         Navigator.pop(context);
//         _cMethods.displaySnackBar("Account created successfully!", context);
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const RoleSelection()),
//         );
//       }
//     } catch (e) {
//       if (!context.mounted) return;
//       Navigator.pop(context);
//       _cMethods.displaySnackBar(e.toString(), context);
//     }
//   }
//
//   // ── BUILD ────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: kBg,
//       resizeToAvoidBottomInset: true,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           physics: const BouncingScrollPhysics(),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//
//                 const SizedBox(height: 20),
//
//                 // ── Top bar ──────────────────────────────────────
//                 Row(
//                   children: [
//                     // Back button
//                     GestureDetector(
//                       onTap: () => Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(
//                             builder: (_) => const LandingPage()),
//                       ),
//                       child: Container(
//                         width: 44, height: 44,
//                         decoration: BoxDecoration(
//                           shape:   BoxShape.circle,
//                           color:   kSurface,
//                           border:  Border.all(color: kBorder, width: 1.5),
//                           boxShadow: [
//                             BoxShadow(
//                               color:      kCyan.withOpacity(0.08),
//                               blurRadius: 12,
//                             ),
//                           ],
//                         ),
//                         child: const Icon(
//                           Icons.arrow_back_ios_new_rounded,
//                           color: kCyan, size: 18,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 25),
//
//                 // ── Glowing Logo ─────────────────────────────────────
//                 Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     // outer glow ring
//                     Container(
//                       width:  110,
//                       height: 110,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         gradient: RadialGradient(
//                           colors: [
//                             kCyan.withOpacity(0.18),
//                             kCyan.withOpacity(0.0),
//                           ],
//                         ),
//                       ),
//                     ),
//                     // inner circle
//                     Container(
//                       width:  82,
//                       height: 82,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: kCyan.withOpacity(0.15),
//                         border: Border.all(
//                             color: kCyan.withOpacity(0.45), width: 2),
//                         boxShadow: [
//                           BoxShadow(
//                             color:        kCyan.withOpacity(0.28),
//                             blurRadius:   24,
//                             spreadRadius: 2,
//                           ),
//                         ],
//                       ),
//                       child: const Icon(
//                         Icons.directions_car_rounded,
//                         color: kCyan,
//                         size:  38,
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 20),
//
//                 // ── Gradient Title ───────────────────────────────────
//                 ShaderMask(
//                   shaderCallback: (bounds) => const LinearGradient(
//                     colors: [kCyanG1, kCyanG2],
//                   ).createShader(bounds),
//                   child: const Text(
//                     'Ride Together',
//                     style: TextStyle(
//                       color:         Colors.white,
//                       fontSize:      28,
//                       fontWeight:    FontWeight.w900,
//                       letterSpacing: 0.3,
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(height: 6),
//
//                 Text(
//                   'Join the carpooling community',
//                   style: TextStyle(
//                     color:    Colors.white,
//                     fontSize: 14,
//                   ),
//                 ),
//
//                 const SizedBox(height: 36),
//
//                 // ── Dark Form Card ───────────────────────────────────
//                 Container(
//                   padding: const EdgeInsets.all(24),
//                   decoration: BoxDecoration(
//                     color:        kCard,
//                     borderRadius: BorderRadius.circular(24),
//                     border:       Border.all(color: kBorder),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//
//                       // Section label — same as login "YOUR CREDENTIALS"
//                       Text(
//                         'YOUR DETAILS',
//                         style: TextStyle(
//                           color:         Colors.white,
//                           fontSize:      10,
//                           letterSpacing: 2.5,
//                           fontWeight:    FontWeight.w700,
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // Full Name
//                       _buildField(
//                         controller: _nameController,
//                         hint:       'Full Name',
//                         icon:       Icons.person_outline_rounded,
//                       ),
//                       const SizedBox(height: 14),
//
//                       // Email
//                       _buildField(
//                         controller:   _emailController,
//                         hint:         'Email',
//                         icon:         Icons.alternate_email_rounded,
//                         keyboardType: TextInputType.emailAddress,
//                       ),
//                       const SizedBox(height: 14),
//
//                       // Phone
//                       _buildField(
//                         controller:   _phoneController,
//                         hint:         'Phone Number',
//                         icon:         Icons.phone_outlined,
//                         keyboardType: TextInputType.phone,
//                       ),
//                       const SizedBox(height: 14),
//
//                       // Password
//                       _buildField(
//                         controller: _passwordController,
//                         hint:       'Password',
//                         icon:       Icons.lock_outline_rounded,
//                         isPassword: true,
//                       ),
//
//                       const SizedBox(height: 28),
//
//                       // ── SIGN UP Button ─────────────────────────────
//                       SizedBox(
//                         width:  double.infinity,
//                         height: 56,
//                         child: ElevatedButton(
//                           onPressed: _isLoading ? null : _checkNetwork,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor:         kCyan,
//                             foregroundColor:         Colors.black,
//                             disabledBackgroundColor: kCyan.withOpacity(0.4),
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(14)),
//                             elevation:   0,
//                           ),
//                           child: _isLoading
//                               ? const SizedBox(
//                             width:  22,
//                             height: 22,
//                             child:  CircularProgressIndicator(
//                               color:       Colors.black,
//                               strokeWidth: 2.5,
//                             ),
//                           )
//                               : const Text(
//                             'SIGN UP',
//                             style: TextStyle(
//                               fontSize:      15,
//                               fontWeight:    FontWeight.w900,
//                               letterSpacing: 2,
//                               color:         Colors.black,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(height: 28),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Field Builder — exact copy from login screen ─────────────────────
//   Widget _buildField({
//     required TextEditingController controller,
//     required String                hint,
//     required IconData              icon,
//     bool          isPassword   = false,
//     TextInputType keyboardType = TextInputType.text,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color:        kField,
//         borderRadius: BorderRadius.circular(14),
//         border:       Border.all(color: kBorder),
//       ),
//       child: TextField(
//         controller:   controller,
//         obscureText:  isPassword && !_isPasswordVisible,
//         keyboardType: keyboardType,
//         cursorColor:  kCyan,
//         style: const TextStyle(
//           color:    Colors.white,
//           fontSize: 15,
//         ),
//         decoration: InputDecoration(
//           contentPadding: const EdgeInsets.symmetric(
//               horizontal: 18, vertical: 18),
//           prefixIcon: Icon(icon, color: kIcon, size: 20),
//           suffixIcon: isPassword
//               ? IconButton(
//             icon: Icon(
//               _isPasswordVisible
//                   ? Icons.visibility_rounded
//                   : Icons.visibility_off_rounded,
//               color: kIcon,
//               size:  20,
//             ),
//             onPressed: () => setState(
//                     () => _isPasswordVisible = !_isPasswordVisible),
//           )
//               : null,
//           hintText:  hint,
//           hintStyle: TextStyle(
//             color:    Colors.white.withOpacity(0.25),
//             fontSize: 14,
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
