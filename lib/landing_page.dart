import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ride_together/login_screen.dart';
import 'package:ride_together/signup_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController _pageController       = PageController();
  final ScrollController _homeScrollController = ScrollController();
  int    _selectedIndex  = 0;
  String _activeFilter   = "All Rides";
  bool   _showScrollHint = true;

  // ── Colors ────────────────────────────────────────────────
  static const Color primary  = Color(0xFF00D4FF);
  static const Color accent   = Color(0xFF00FFB3);
  static const Color bgDark   = Color(0xFF0D1B2A);
  static const Color bgCard   = Color(0xFF1A1A2E);
  static const Color bgDeep   = Color(0xFF0F3460);

  @override
  void initState() {
    super.initState();
    _homeScrollController.addListener(() {
      if (_homeScrollController.offset > 40 && _showScrollHint) {
        setState(() => _showScrollHint = false);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────
  final List<Map<String, dynamic>> _nearbyRides = const [
    {"name": "Zain Ahmed",    "car": "Toyota Corolla",   "price": "Rs 400",  "rating": "4.9", "trips": "120", "image": "https://i.pravatar.cc/150?img=12"},
    {"name": "Sarah Khan",    "car": "Honda Civic",      "price": "Rs 600",  "rating": "4.8", "trips": "85",  "image": "https://i.pravatar.cc/150?img=5"},
    {"name": "Nasir Ud Din",  "car": "Suzuki Swift",     "price": "Rs 200",  "rating": "4.7", "trips": "210", "image": "https://i.pravatar.cc/150?img=8"},
    {"name": "Abdul Haseeb",  "car": "Kia Sportage",     "price": "Rs 1000", "rating": "4.9", "trips": "45",  "image": "https://i.pravatar.cc/150?img=3"},
    {"name": "Alishba Khan",  "car": "Hyundai Elantra",  "price": "Rs 200",  "rating": "5.0", "trips": "150", "image": "https://i.pravatar.cc/150?img=45"},
  ];

  final List<Map<String, dynamic>> _myRidesData = const [
    {"route": "Islamabad to Lahore",         "date": "Today, 05:00 PM",     "status": "Active",    "price": "Rs 3000", "color": Color(0xFF00D4FF)},
    {"route": "G-11 to Blue Area",           "date": "Yesterday, 09:00 AM", "status": "Completed", "price": "Rs 500",  "color": Color(0xFF00FFB3)},
    {"route": "University Road to Saddar",   "date": "Friday, 10:15 AM",    "status": "Completed", "price": "Rs 300",  "color": Color(0xFF00FFB3)},
    {"route": "DHA Phase 2 to Airport",      "date": "10 April, 02:00 PM",  "status": "Cancelled", "price": "Rs 0",    "color": Colors.redAccent},
    {"route": "Gulberg to Mall Road",        "date": "8 April, 11:00 AM",   "status": "Completed", "price": "Rs 450",  "color": Color(0xFF00FFB3)},
  ];

  final List<Map<String, dynamic>> _chatsData = const [
    {"name": "Zain Ahmed",   "msg": "I am waiting at the gate.",         "time": "2m ago",   "unread": true,  "img": "12"},
    {"name": "Sarah Khan",   "msg": "Okay, see you then!",               "time": "1h ago",   "unread": false, "img": "5"},
    {"name": "Nasir Ud Din", "msg": "I'm near the signal, 5 mins away.", "time": "3h ago",   "unread": true,  "img": "8"},
    {"name": "Abdul Haseeb", "msg": "Can you share your live location?", "time": "Yesterday","unread": false, "img": "3"},
    {"name": "Alishba Khan", "msg": "Thanks for the ride today!",        "time": "Yesterday","unread": false, "img": "45"},
  ];

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,

      // ── Bottom Nav ───────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgCard,
          border: Border(
              top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            _pageController.animateToPage(index,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut);
          },
          backgroundColor: Colors.transparent,
          selectedItemColor:   primary,
          unselectedItemColor: Colors.white30,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
          GoogleFonts.poppins(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.directions_car),
                label: "My Rides"),
            BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                label: "Chat"),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: "Profile"),
          ],
        ),
      ),

      // ── Bottom Sheet ─────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            if (_showScrollHint && _selectedIndex == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Text(
                      "Explore active carpools near you",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                        Icons
                            .keyboard_double_arrow_down_rounded,
                        color: Colors.white24,
                        size: 18),
                  ],
                ),
              ),

            // Get Started Button
            Container(
              width:  double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primary, accent],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius:   12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const SignUpScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor:     Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14)),
                ),
                child: Text(
                  "Get Started",
                  style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:   16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Login Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account? ",
                  style: GoogleFonts.poppins(
                      color:    Colors.white38,
                      fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                        const LoginScreen()),
                  ),
                  child: Text(
                    "Log In",
                    style: GoogleFonts.poppins(
                      color:      primary,
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                      decoration:
                      TextDecoration.underline,
                      decorationColor: primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // ── Page View ────────────────────────────────────────
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) =>
            setState(() => _selectedIndex = i),
        children: [
          _buildHomeScreen(),
          _buildMyRidesScreen(),
          _buildChatScreen(),
          _buildProfileScreen(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 1 — HOME
  // ─────────────────────────────────────────────────────────
  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      controller: _homeScrollController,
      child: Column(
        children: [
          // Header
          Container(
            padding:
            const EdgeInsets.fromLTRB(20, 60, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [bgDark, bgDeep],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text("Ride Together",
                            style: GoogleFonts.poppins(
                              color:      Colors.white,
                              fontSize:   22,
                              fontWeight: FontWeight.bold,
                            )),
                        Text(
                          "Eco-Traveler Level 4 🌿",
                          style: GoogleFonts.poppins(
                              color:    Colors.white38,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: primary
                                .withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage(
                            "https://i.pravatar.cc/150?img=11"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white
                            .withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                    children: [
                      _statBox(Icons.eco_rounded,
                          "12.4kg", "CO₂ Saved",
                          Colors.greenAccent),
                      _vDivider(),
                      _statBox(
                          Icons.account_balance_wallet,
                          "Rs 120k",
                          "Cash Saved",
                          Colors.orangeAccent),
                      _vDivider(),
                      _statBox(Icons.emoji_events,
                          "12", "Trips",
                          Colors.yellowAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Card
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white
                        .withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _searchRow(Icons.my_location,
                      "Pickup Location", primary),
                  Divider(
                      height: 24,
                      color: Colors.white
                          .withOpacity(0.08)),
                  _searchRow(Icons.location_on,
                      "Where to?", Colors.redAccent),
                  const SizedBox(height: 16),
                  Container(
                    width:  double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [primary, accent]),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Find Rides Now",
                        style: GoogleFonts.poppins(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            child: Row(
              children: [
                _filterChip("All Rides"),
                _filterChip("Female Only 👩"),
                _filterChip("With AC ❄️"),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section header
          _sectionHeader("Recommended for you"),

          // Ride Cards
          ListView.builder(
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            itemCount: _nearbyRides.length,
            itemBuilder: (_, i) =>
                _rideCard(_nearbyRides[i]),
          ),

          const SizedBox(height: 220),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 2 — MY RIDES
  // ─────────────────────────────────────────────────────────
  Widget _buildMyRidesScreen() {
    return Column(
      children: [
        _pageHeader("Ride History"),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _myRidesData.length,
            itemBuilder: (_, i) {
              final r = _myRidesData[i];
              final Color c = r['color'] as Color;
              return Container(
                margin:
                const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius:
                  BorderRadius.circular(16),
                  border: Border.all(
                      color: c.withOpacity(0.25),
                      width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width:  44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.history,
                          color: c, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(r['route'],
                              style: GoogleFonts.poppins(
                                color:      Colors.white,
                                fontWeight:
                                FontWeight.w600,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 3),
                          Text(r['date'],
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.12),
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                          child: Text(
                            r['status'],
                            style: TextStyle(
                                color:    c,
                                fontSize: 11,
                                fontWeight:
                                FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(r['price'],
                            style: const TextStyle(
                              color:      Colors.white70,
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 3 — CHAT
  // ─────────────────────────────────────────────────────────
  Widget _buildChatScreen() {
    return Column(
      children: [
        _pageHeader("My Messages"),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatsData.length,
            itemBuilder: (_, i) {
              final c = _chatsData[i];
              return Container(
                margin:
                const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius:
                  BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white
                          .withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(
                              "https://i.pravatar.cc/150?img=${c['img']}"),
                        ),
                        if (c['unread'] as bool)
                          Positioned(
                            right: 0,
                            top:   0,
                            child: Container(
                              width:  10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: bgCard,
                                    width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(c['name'],
                              style: GoogleFonts.poppins(
                                color:      Colors.white,
                                fontWeight:
                                FontWeight.w600,
                                fontSize: 14,
                              )),
                          const SizedBox(height: 2),
                          Text(c['msg'],
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color:    Colors.white38,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(c['time'],
                        style: const TextStyle(
                            color:    Colors.white24,
                            fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TAB 4 — PROFILE
  // ─────────────────────────────────────────────────────────
  Widget _buildProfileScreen() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _pageHeader("Account Settings"),
          const SizedBox(height: 24),

          // Avatar
          Center(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color:
                        primary.withOpacity(0.25),
                        blurRadius:   16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 48,
                    backgroundImage: NetworkImage(
                        "https://i.pravatar.cc/150?img=11"),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right:  0,
                  child: Container(
                    width:  28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:  primary,
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: bgDark, width: 2),
                    ),
                    child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size:  14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text("John",
              style: GoogleFonts.poppins(
                color:      Colors.white,
                fontSize:   20,
                fontWeight: FontWeight.bold,
              )),
          Text("john@gmail.com",
              style: const TextStyle(
                  color:    Colors.white38,
                  fontSize: 13)),

          const SizedBox(height: 8),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: primary.withOpacity(0.3)),
            ),
            child: Text("Eco-Traveler Level 4 🌿",
                style: TextStyle(
                    color:    primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),

          const SizedBox(height: 24),

          // Profile options
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            child: Column(
              children: [
                _profileTile(
                    Icons.account_balance_wallet,
                    "Wallet Balance",
                    "Rs 120,000",
                    Colors.orangeAccent),
                _profileTile(
                    Icons.star_rounded,
                    "Your Rating",
                    "4.95 ⭐",
                    Colors.yellowAccent),
                _profileTile(
                    Icons.card_giftcard,
                    "Refer & Earn",
                    "Get free rides",
                    Colors.pinkAccent),
                _profileTile(
                    Icons.notifications_active,
                    "Notifications",
                    "On",
                    accent),
                _profileTile(
                    Icons.help_center_outlined,
                    "Support Center",
                    "",
                    primary),
                const SizedBox(height: 8),

                // Sign Out
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.red
                          .withOpacity(0.08),
                      borderRadius:
                      BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.red
                              .withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout,
                            color: Colors.redAccent,
                            size: 20),
                        SizedBox(width: 10),
                        Text("Sign Out",
                            style: TextStyle(
                              color:      Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize:   15,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 220),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _pageHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [bgDark, bgDeep],
        ),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color:      Colors.white,
          fontSize:   22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statBox(IconData icon, String value,
      String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
              color:      Colors.white,
              fontWeight: FontWeight.bold,
              fontSize:   13,
            )),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _vDivider() => Container(
    width:  1,
    height: 40,
    color:  Colors.white12,
  );

  Widget _searchRow(
      IconData icon, String hint, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 14),
        Text(hint,
            style: const TextStyle(
                color: Colors.white38, fontSize: 14)),
      ],
    );
  }

  Widget _filterChip(String label) {
    final bool selected = _activeFilter == label;
    return GestureDetector(
      onTap: () =>
          setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withOpacity(0.15)
              : bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? primary
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? primary
                : Colors.white38,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          16, 4, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color:      Colors.white,
            fontSize:   16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _rideCard(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: primary.withOpacity(0.4),
                  width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundImage:
              NetworkImage(d['image']),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(d['name'],
                    style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize:   14,
                    )),
                Text(
                  "${d['car']}  •  ⭐ ${d['rating']}  •  ${d['trips']} trips",
                  style: const TextStyle(
                      color:    Colors.white38,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius:
              BorderRadius.circular(8),
              border: Border.all(
                  color: primary.withOpacity(0.3)),
            ),
            child: Text(
              d['price'],
              style: const TextStyle(
                color:      primary,
                fontWeight: FontWeight.bold,
                fontSize:   13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(IconData icon, String title,
      String trailing, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width:  38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                )),
          ),
          Text(trailing,
              style: TextStyle(
                  color:    color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios,
              color: Colors.white24, size: 13),
        ],
      ),
    );
  }
}
