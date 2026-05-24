import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:ride_together/landing_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color bgTop   = Color(0xFF1A1A2E);
  static const Color bgMid   = Color(0xFF16213E);
  static const Color bgBot   = Color(0xFF0F3460);
  static const Color primary = Color(0xFF00D4FF);
  static const Color accent  = Color(0xFF00FFB3);

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Welcome to\nRide Together",
      "desc": "Smart carpooling for urban commuters.\nShare rides, save money every day.",
      "image": "assets/logo.png",
    },
    {
      "title": "Easy Booking",
      "desc": "Book your ride in seconds with a single tap.",
      "image": "assets/onboarding1.jpg",
    },
    {
      "title": "Fast Responses",
      "desc": "Get instant confirmations from trusted drivers.",
      "image": "assets/onboarding2.jpg",
    },
    {
      "title": "Quick Arrival",
      "desc": "Optimized routes to save you time every day.",
      "image": "assets/onboarding3.png",
    },
  ];

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage =
        _currentPage == _onboardingData.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgTop, bgMid, bgBot],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // ── Top Bar ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.end,
                  children: [

                    // ── Skip button top RIGHT ──
                    if (!isLastPage)
                      GestureDetector(
                        onTap: _finish,
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.07),
                            borderRadius:
                            BorderRadius.circular(20),
                            border: Border.all(
                              color: primary
                                  .withOpacity(0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                    // Placeholder to keep layout stable
                      const SizedBox(width: 70),
                  ],
                ),
              ),

              // ── Page View ────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _onboardingData.length,
                  itemBuilder: (_, index) =>
                      _buildSlide(index),
                ),
              ),

              // ── Dot Indicator ─────────────────────
              SmoothPageIndicator(
                controller: _pageController,
                count: _onboardingData.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: primary,
                  dotColor: Colors.white.withOpacity(0.2),
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 4,
                  spacing: 6,
                ),
              ),

              const SizedBox(height: 28),

              // ── Navigation Buttons ────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    24, 0, 24, 32),
                child: Row(
                  children: [

                    // Back button
                    if (_currentPage > 0) ...[
                      GestureDetector(
                        onTap: _prevPage,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white
                                .withOpacity(0.07),
                            border: Border.all(
                              color: primary
                                  .withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary
                                    .withOpacity(0.1),
                                blurRadius: 12,
                                offset:
                                const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons
                                .arrow_back_ios_new_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Next / Get Started button
                    Expanded(
                      child: GestureDetector(
                        onTap: isLastPage
                            ? _finish
                            : _nextPage,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: isLastPage
                                  ? [
                                accent,
                                const Color(
                                    0xFF00B4D8)
                              ]
                                  : [
                                primary,
                                const Color(
                                    0xFF0083B0)
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isLastPage
                                    ? accent
                                    : primary)
                                    .withOpacity(0.4),
                                blurRadius: 20,
                                offset:
                                const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage
                                    ? 'Get Started'
                                    : 'Next',
                                style:
                                GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastPage
                                    ? Icons
                                    .rocket_launch_rounded
                                    : Icons
                                    .arrow_forward_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Slide Builder ─────────────────────────────
  Widget _buildSlide(int index) {
    final bool isFirst = index == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // ── Visual ────────────────────────────
          if (isFirst)

          // Just logo centered with glow, transparent bg
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Center(
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [

                    // Glowing logo
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                            primary.withOpacity(0.3),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color:
                            accent.withOpacity(0.15),
                            blurRadius: 25,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          width: 200,
                          height: 200,
                          errorBuilder: (_, __, ___) =>
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                      0xFF0A1628),
                                  border: Border.all(
                                      color: primary,
                                      width: 2),
                                ),
                                child: const Icon(
                                  Icons
                                      .directions_car_rounded,
                                  color: primary,
                                  size: 80,
                                ),
                              ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                  ],
                ),
              ),
            )

          else

          // ✅ Other slides — with border + image
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  fit: StackFit.expand,
                  children: [

                    // Image
                    Image.asset(
                      _onboardingData[index]["image"]
                      as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(
                            color: const Color(0xFF0F2040),
                            child: Icon(
                              Icons.image_not_supported,
                              color: primary.withOpacity(0.4),
                              size: 50,
                            ),
                          ),
                    ),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            bgTop.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),

          // ── Page Pill ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${index + 1} of ${_onboardingData.length}',
              style: GoogleFonts.poppins(
                color: primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Title ──────────────────────────────
          Text(
            _onboardingData[index]["title"] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 14),

          // ── Description ────────────────────────
          Text(
            _onboardingData[index]["desc"] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.white.withOpacity(0.6),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
