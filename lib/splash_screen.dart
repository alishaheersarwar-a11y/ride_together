import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_together/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLocationPermissionDeniedForeverFlag = 'location_perm_denied_forever';

Future<void> showLocationPermissionSnackbarIfDenied(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(kLocationPermissionDeniedForeverFlag) ?? false)) return;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Location permission is required for maps to work.'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Settings',
        onPressed: () => Geolocator.openAppSettings(),
      ),
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;
  late final AnimationController _ringController;
  late final AnimationController _shimmerController;
  late final AnimationController _floatController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoRotate;
  late final Animation<double> _titleFade;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset>  _taglineSlide;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _ringAnim;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _logoRotate = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));
    _taglineFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _ringAnim = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOut,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _logoController.forward().then((_) {
      _textController.forward();
    });

    _requestStartupPermissions();

    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OnboardingScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 700),
          ),
        );
      }
    });
  }

  Future<void> _requestStartupPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      kLocationPermissionDeniedForeverFlag,
      perm == LocationPermission.deniedForever,
    );

    // Notification permission for the foreground-service notification used
    // during live ride tracking. Asked here (not on ride confirm) so the
    // ride-confirm flow never triggers a system dialog — a known Android 14
    // crash trigger when chained after another permission request.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          await Permission.notification.request();
        }
      } catch (e) {
        debugPrint('Notification permission request failed: $e');
      }

      // Battery optimization exemption — without this, aggressive OEMs
      // (Samsung One UI, MIUI, OnePlus OxygenOS, etc.) kill the foreground
      // service mid-ride, causing live tracking to silently die. Requesting
      // here means it's a one-time prompt at first launch instead of a
      // mid-ride surprise.
      try {
        final batteryOptStatus =
            await Permission.ignoreBatteryOptimizations.status;
        if (!batteryOptStatus.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (e) {
        debugPrint('Battery optimization permission request failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF050C1A),
      body: Stack(
        children: [

          // ── Multi-layer background ─────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.25),
                radius: 1.4,
                colors: [
                  Color(0xFF0C2040),
                  Color(0xFF071020),
                  Color(0xFF050C1A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Secondary accent glow (bottom-right) ──
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00FFB3).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Grid background ───────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _GridPainter(),
            ),
          ),

          // ── Particles ─────────────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ParticlePainter(_particleController.value),
            ),
          ),

          // ── Expanding rings ───────────────────────
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) => Center(
              child: CustomPaint(
                size: size,
                painter: _RingPainter(_ringAnim.value),
              ),
            ),
          ),

          // ── Main Content ──────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Logo with glow ────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _logoController,
                    _pulseAnim,
                    _floatAnim,
                  ]),
                  builder: (_, __) {
                    return FadeTransition(
                      opacity: _logoFade,
                      child: Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: Transform.rotate(
                          angle: _logoRotate.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [

                                // ── Outermost ambient glow ──
                                Container(
                                  width:  310,
                                  height: 310,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00D4FF)
                                            .withOpacity(0.30 * _pulseAnim.value),
                                        blurRadius:   100,
                                        spreadRadius: 40,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF00FFB3)
                                            .withOpacity(0.18 * _pulseAnim.value),
                                        blurRadius:   70,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Rotating dashed ring ──
                                AnimatedBuilder(
                                  animation: _ringController,
                                  builder: (_, __) => Transform.rotate(
                                    angle: _ringController.value * 2 * pi,
                                    child: CustomPaint(
                                      size: const Size(296, 296),
                                      painter: _DashedRingPainter(
                                        color: const Color(0xFF00D4FF).withOpacity(0.4),
                                        radius: 148,
                                        dashCount: 24,
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Counter-rotating dashed ring ──
                                AnimatedBuilder(
                                  animation: _ringController,
                                  builder: (_, __) => Transform.rotate(
                                    angle: -_ringController.value * 2 * pi * 0.7,
                                    child: CustomPaint(
                                      size: const Size(270, 270),
                                      painter: _DashedRingPainter(
                                        color: const Color(0xFF00FFB3).withOpacity(0.3),
                                        radius: 135,
                                        dashCount: 16,
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Inner solid ring border ──
                                Container(
                                  width:  252,
                                  height: 252,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00D4FF)
                                          .withOpacity(0.25 * _pulseAnim.value),
                                      width: 1,
                                    ),
                                  ),
                                ),

                                // ── Logo background circle ──
                                Container(
                                  width:  244,
                                  height: 244,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF0D2040).withOpacity(0.9),
                                        const Color(0xFF060E1E).withOpacity(0.95),
                                      ],
                                    ),
                                  ),
                                ),

                                // ── Actual logo image ──────────
                                ClipOval(
                                  child: SizedBox(
                                    width:  240,
                                    height: 240,
                                    child: Image.asset(
                                      'assets/logo.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: const Color(0xFF0D2040),
                                          child: const Center(
                                            child: Icon(
                                              Icons.directions_car_rounded,
                                              color: Color(0xFF00D4FF),
                                              size: 80,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // ── Shimmer overlay on logo ──
                                ClipOval(
                                  child: SizedBox(
                                    width:  240,
                                    height: 240,
                                    child: AnimatedBuilder(
                                      animation: _shimmerAnim,
                                      builder: (_, __) => CustomPaint(
                                        painter: _ShimmerPainter(_shimmerAnim.value),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 52),

                // ── App Name with shimmer gradient ────
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment((_shimmerAnim.value - 1) * 0.5, 0),
                          end:   Alignment((_shimmerAnim.value + 1) * 0.5, 0),
                          colors: const [
                            Color(0xFFD0E8FF),
                            Color(0xFFFFFFFF),
                            Color(0xFF00D4FF),
                            Color(0xFF00FFB3),
                            Color(0xFFFFFFFF),
                          ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ).createShader(bounds),
                        child: const Text(
                          'Ride Together',
                          style: TextStyle(
                            color:         Colors.white,
                            fontSize:      42,
                            fontWeight:    FontWeight.w900,
                            letterSpacing: 1.2,
                            height:        1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Decorative line divider ────────────
                FadeTransition(
                  opacity: _taglineFade,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF00D4FF).withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'SHARE RIDES SAVE MONEY',
                          style: TextStyle(
                            color:         Color(0xFF6FA8C8),
                            fontSize:      11,
                            fontWeight:    FontWeight.w600,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 32,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00FFB3).withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Loading progress bar ───────────────────
          Positioned(
            bottom: 70,
            left:   0,
            right:  0,
            child: FadeTransition(
              opacity: _taglineFade,
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedBuilder(
                          animation: _particleController,
                          builder: (_, __) => Stack(
                            children: [
                              // Track
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // Fill
                              FractionallySizedBox(
                                widthFactor: _particleController.value,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF00D4FF),
                                        Color(0xFF00FFB3),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00D4FF).withOpacity(0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHIMMER PAINTER — sweeping gloss over logo
// ─────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double position; // -1.5 to 2.5
  _ShimmerPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final x  = position * size.width;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end:   Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(x - 60, 0, 120, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.position != position;
}

// ─────────────────────────────────────────────
//  DASHED RING PAINTER
// ─────────────────────────────────────────────
class _DashedRingPainter extends CustomPainter {
  final Color  color;
  final double radius;
  final int    dashCount;

  _DashedRingPainter({
    required this.color,
    required this.radius,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final step = (2 * pi) / dashCount;
    final arc  = step * 0.45;

    final paint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        arc,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}

// ─────────────────────────────────────────────
//  GRID PAINTER — subtle circuit grid bg
// ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ─────────────────────────────────────────────
//  RING PAINTER — expanding pulse rings
// ─────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2 - 55;

    for (int i = 0; i < 4; i++) {
      final t       = ((progress + i * 0.25) % 1.0);
      final radius  = 140.0 + t * 220;
      final opacity = (1.0 - t) * 0.07;

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = const Color(0xFF00D4FF).withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────
//  PARTICLE PAINTER
// ─────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;

  static const List<List<double>> _defs = [
    [0.10, 0.20, 0.60, 2.0, 0.0],
    [0.25, 0.70, 0.40, 1.5, 1.0],
    [0.40, 0.15, 0.80, 2.5, 0.0],
    [0.55, 0.85, 0.50, 1.8, 1.0],
    [0.70, 0.30, 0.70, 2.2, 0.0],
    [0.85, 0.60, 0.30, 1.2, 1.0],
    [0.15, 0.50, 0.90, 1.6, 0.0],
    [0.60, 0.45, 0.60, 2.8, 1.0],
    [0.90, 0.10, 0.40, 1.4, 0.0],
    [0.35, 0.90, 0.70, 1.8, 0.0],
    [0.78, 0.78, 0.50, 2.0, 1.0],
    [0.05, 0.65, 0.80, 1.5, 0.0],
    [0.50, 0.05, 0.60, 1.8, 1.0],
    [0.92, 0.45, 0.70, 1.2, 0.0],
    [0.20, 0.35, 0.55, 1.6, 1.0],
    [0.65, 0.18, 0.85, 2.0, 0.0],
  ];

  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final def in _defs) {
      final t       = (progress * def[2]) % 1.0;
      final x       = def[0] * size.width;
      final y       = (def[1] - t * 0.3) * size.height;
      final opacity = (sin(t * pi)).clamp(0.0, 1.0) * 0.45;

      // Glow halo
      canvas.drawCircle(
        Offset(x, y),
        def[3] * 3,
        Paint()
          ..color = (def[4] == 0.0
              ? const Color(0xFF00D4FF)
              : const Color(0xFF00FFB3))
              .withOpacity(opacity * 0.3),
      );

      // Core dot
      canvas.drawCircle(
        Offset(x, y),
        def[3],
        Paint()
          ..color = (def[4] == 0.0
              ? const Color(0xFF00D4FF)
              : const Color(0xFF00FFB3))
              .withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}