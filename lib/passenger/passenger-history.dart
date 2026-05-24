import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

const Color kNavy     = Color(0xFF0F1219);
const Color kCardNavy = Color(0xFF1C212B);
const Color kDeep     = Color(0xFF07090C);
const Color kCyan     = Color(0xFF00E5FF);
const Color kGreen    = Color(0xFF00C853);
const Color kAmber    = Color(0xFFFFB347);
const Color kError    = Color(0xFFFF4B2B);
const Color kGold     = Color(0xFFFFD700);

class PassengerHistory extends StatefulWidget {
  const PassengerHistory({super.key});

  @override
  State<PassengerHistory> createState() =>
      _PassengerHistoryState();
}

class _PassengerHistoryState
    extends State<PassengerHistory>
    with SingleTickerProviderStateMixin {

  List<Map<String, dynamic>> _allRides      = [];
  List<Map<String, dynamic>> _filteredRides = [];

  // ── Driver profile cache ─────────────────────────
  // key = driverId, value = {name, imageUrl, initials}
  final Map<String, Map<String, String>> _driverCache = {};

  bool   _isLoading    = true;
  String _activeFilter = 'All';

  int    _totalRides = 0;
  int    _completed  = 0;
  int    _pending    = 0;
  double _totalSpent = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final List<String> _filters = [
    'All', 'Completed', 'Accepted', 'Pending', 'Rejected'
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(
        parent: _fadeCtrl, curve: Curves.easeIn);
    _loadHistory();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════
  // LOAD HISTORY
  // ══════════════════════════════════════════════════
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snap = await FirebaseDatabase.instance
          .ref()
          .child('ride_requests')
          .orderByChild('passengerId')
          .equalTo(uid)
          .get();

      if (!snap.exists || snap.value == null) {
        setState(() => _isLoading = false);
        _fadeCtrl.forward();
        return;
      }

      final raw  = Map<String, dynamic>.from(snap.value as Map);
      final List<Map<String, dynamic>> rides = [];

      raw.forEach((key, val) {
        final r = Map<String, dynamic>.from(val as Map);
        r['_key'] = key;

        r['pickup'] = r['pickup']?.toString().isNotEmpty == true
            ? r['pickup'].toString()
            : r['pickupAddress']?.toString() ?? 'Pickup location';

        r['destination'] =
        r['destination']?.toString().isNotEmpty == true
            ? r['destination'].toString()
            : r['destAddress']?.toString() ??
            r['destinationAddress']?.toString() ??
            'Destination';

        r['driverName'] =
        r['driverName']?.toString().isNotEmpty == true
            ? r['driverName'].toString()
            : r['driver_name']?.toString() ?? 'Driver';

        rides.add(r);
      });

      // Sort newest first
      rides.sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      // Stats
      int    completed = 0, pending = 0;
      //double spent     = 0;
      for (final r in rides) {
        final s = r['status']?.toString() ?? '';
        if (s == 'completed' || s == 'accepted') {
          completed++;
        }
        if (s == 'pending') pending++;
      }

      setState(() {
        _allRides      = rides;
        _filteredRides = rides;
        _totalRides    = rides.length;
        _completed     = completed;
        _pending       = pending;
        _isLoading     = false;
      });

      _fadeCtrl.forward();

      // ✅ Fetch driver profiles in background
      await _fetchDriverProfiles(rides);

    } catch (e) {
      debugPrint('History error: $e');
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  // ══════════════════════════════════════════════════
  // FETCH DRIVER PROFILES (batch, cached)
  // ══════════════════════════════════════════════════
  Future<void> _fetchDriverProfiles(
      List<Map<String, dynamic>> rides) async {
    // Collect unique driverIds not yet cached
    final Set<String> ids = {};
    for (final r in rides) {
      final id = r['driverId']?.toString() ?? '';
      if (id.isNotEmpty && !_driverCache.containsKey(id)) {
        ids.add(id);
      }
    }

    if (ids.isEmpty) return;

    // Fetch each driver profile from Firebase
    for (final driverId in ids) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(driverId)
            .get();

        if (snap.exists && snap.value != null) {
          final d = Map<String, dynamic>.from(
              snap.value as Map);

          final name = d['name']?.toString()     ??
              d['fullName']?.toString()           ??
              d['driverName']?.toString()         ??
              'Driver';

          final photo = d['imageUrl']?.toString()   ??
              d['profileImage']?.toString()          ??
              d['photoUrl']?.toString()              ??
              d['driverImage']?.toString()           ??
              '';

          final initials = _getInitials(name);

          if (mounted) {
            setState(() {
              _driverCache[driverId] = {
                'name':     name,
                'imageUrl': photo,
                'initials': initials,
              };
            });
          }
        }
      } catch (e) {
        debugPrint('Driver fetch error for $driverId: $e');
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();
  }

  void _applyFilter(String f) {
    setState(() {
      _activeFilter  = f;
      _filteredRides = f == 'All'
          ? _allRides
          : _allRides
          .where((r) =>
      (r['status']?.toString().toLowerCase() ?? '')
          == f.toLowerCase())
          .toList();
    });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt   = DateTime.fromMillisecondsSinceEpoch(
          int.parse(ts.toString()));
      final now  = DateTime.now();
      final diff = now.difference(dt);
      final h    = dt.hour   .toString().padLeft(2, '0');
      final m    = dt.minute .toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';

      if (diff.inDays == 0) return 'Today, $h:$m $ampm';
      if (diff.inDays == 1) return 'Yesterday, $h:$m $ampm';
      const months = [
        '', 'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return ts.toString();
    }
  }

  Color    _sColor(String s) {
    switch (s) {
      case 'completed': return kGreen;
      case 'accepted':  return kCyan;
      case 'pending':   return kAmber;
      case 'rejected':  return kError;
      default:          return Colors.white38;
    }
  }

  IconData _sIcon(String s) {
    switch (s) {
      case 'completed': return Icons.check_circle_rounded;
      case 'accepted':  return Icons.directions_car_rounded;
      case 'pending':   return Icons.hourglass_top_rounded;
      case 'rejected':  return Icons.cancel_rounded;
      default:          return Icons.help_outline;
    }
  }

  String _sLabel(String s) => s.toUpperCase();

  // ══════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:        kNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Trip History',
            style: TextStyle(
              color:         Colors.white,
              fontWeight:    FontWeight.bold,
              letterSpacing: 1,
            )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: kCyan.withOpacity(0.8)),
            onPressed: () {
              _fadeCtrl.reset();
              _driverCache.clear();
              _loadHistory();
            },
          ),
        ],
      ),
      body: Container(
        width:  double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [kNavy, kDeep],
          ),
        ),
        child: _isLoading
            ? _buildLoader()
            : SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const SizedBox(height: 6),
                _buildStatsBanner(),
                if (_allRides.isNotEmpty)
                  _buildFilterChips(),
                Expanded(
                  child: _filteredRides.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
            color: kCyan, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Loading your trips...',
            style: TextStyle(
                color: Colors.white38, fontSize: 13)),
      ],
    ),
  );

  // ── Stats Banner ──────────────────────────────────
  Widget _buildStatsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            kCyan.withOpacity(0.10),
            Colors.white.withOpacity(0.03),
          ]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kCyan.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            _stat('$_totalRides',  'Total Rides',
                Icons.local_taxi_rounded,       kCyan),
            _vDiv(),
            _stat('$_completed',   'Completed',
                Icons.check_circle_rounded,     kGreen),
            _vDiv(),
            _stat('$_pending',     'Pending',
                Icons.hourglass_top_rounded,    kAmber),
            _vDiv(),
          ],
        ),
      ),
    );
  }

  Widget _stat(String val, String lbl,
      IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(val,
              style: TextStyle(
                color:      color,
                fontSize:   14,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 2),
          Text(lbl,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(
    width:  1,
    height: 36,
    color:  Colors.white10,
    margin: const EdgeInsets.symmetric(horizontal: 2),
  );

  // ── Filter Chips ──────────────────────────────────
  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f      = _filters[i];
          final active = _activeFilter == f;
          final count  = f == 'All'
              ? _allRides.length
              : _allRides
              .where((r) =>
          (r['status']?.toString().toLowerCase() ?? '')
              == f.toLowerCase())
              .length;

          return GestureDetector(
            onTap: () => _applyFilter(f),
            child: AnimatedContainer(
              duration:
              const Duration(milliseconds: 200),
              margin:  const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? kCyan.withOpacity(0.14)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? kCyan
                      : Colors.white.withOpacity(0.1),
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f,
                      style: TextStyle(
                        color: active
                            ? kCyan
                            : Colors.white38,
                        fontSize:   12,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      )),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? kCyan.withOpacity(0.2)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                            color: active
                                ? kCyan
                                : Colors.white24,
                            fontSize:   9,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────
  Widget _buildEmpty() {
    final bool filtered = _activeFilter != 'All';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color:  kCyan.withOpacity(0.05),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.07)),
            ),
            child: Icon(
              filtered
                  ? Icons.filter_list_off_rounded
                  : Icons.directions_car_filled_outlined,
              size:  65,
              color: kCyan.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            filtered ? 'No $_activeFilter Rides' : 'No Rides Yet',
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              filtered
                  ? 'No rides with this status found.'
                  : 'Your completed trips will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    Colors.white.withOpacity(0.4),
                fontSize: 14,
                height:   1.5,
              ),
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _applyFilter('All'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color:        kCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: kCyan.withOpacity(0.3)),
                ),
                child: const Text('Show All Rides',
                    style: TextStyle(
                      color:      kCyan,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────
  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: _filteredRides.length,
      itemBuilder: (_, i) => _buildCard(_filteredRides[i]),
    );
  }

  // ══════════════════════════════════════════════════
  // RIDE CARD
  // ══════════════════════════════════════════════════
  Widget _buildCard(Map<String, dynamic> ride) {
    final String status = ride['status']?.toString()    ?? 'unknown';
    final String pickup = ride['pickup']?.toString()    ?? 'Pickup';
    final String dest   = ride['destination']?.toString() ?? 'Destination';
    final double fare   = double.tryParse(
        ride['fare'].toString()) ?? 0;
    final int    seats  = int.tryParse(
        ride['seats']?.toString() ?? '1') ?? 1;
    final double total  = fare * seats;
    final String date   = _formatDate(ride['timestamp']);
    final bool   isPaid =
        ride['paymentStatus']?.toString() == 'paid';

    // ── Driver info — from cache or fallback ─────────
    final String driverId = ride['driverId']?.toString() ?? '';
    final Map<String, String>? cached = _driverCache[driverId];

    final String driverName  = cached?['name']     ??
        ride['driverName']?.toString()              ??
        'Driver';
    final String driverPhoto = cached?['imageUrl'] ?? '';
    final String driverInit  = cached?['initials'] ??
        _getInitials(driverName);

    final Color    sc = _sColor(status);
    final IconData si = _sIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        kCardNavy,
        borderRadius: BorderRadius.circular(24),
        border:       Border.all(
            color: sc.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset:     const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [

          // ── Top bar ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Row(children: [
              Icon(si, color: sc, size: 13),
              const SizedBox(width: 5),
              Text(_sLabel(status),
                  style: TextStyle(
                    color:         sc,
                    fontSize:      10,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 0.8,
                  )),
              const Spacer(),
              Text(date,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Rs ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ]),
          ),

          // ── Body ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [

                // Route
                Row(children: [
                  Column(children: [
                    Container(
                      width:  10,
                      height: 10,
                      decoration: BoxDecoration(
                        color:  kCyan,
                        shape:  BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color:
                              kCyan.withOpacity(0.4),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                    Container(
                      width:  1.5,
                      height: 30,
                      margin: const EdgeInsets.symmetric(
                          vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin:  Alignment.topCenter,
                          end:    Alignment.bottomCenter,
                          colors: [
                            kCyan.withOpacity(0.5),
                            kError.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width:  10,
                      height: 10,
                      decoration: BoxDecoration(
                        color:  kError,
                        shape:  BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color:
                              kError.withOpacity(0.4),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _locationText('FROM', pickup),
                        const SizedBox(height: 14),
                        _locationText('TO',   dest),
                      ],
                    ),
                  ),

                  if (seats > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kCyan.withOpacity(0.08),
                        borderRadius:
                        BorderRadius.circular(10),
                        border: Border.all(
                            color: kCyan.withOpacity(0.2)),
                      ),
                      child: Column(children: [
                        Text('×$seats',
                            style: const TextStyle(
                              color:      kCyan,
                              fontSize:   13,
                              fontWeight: FontWeight.bold,
                            )),
                        const Text('seats',
                            style: TextStyle(
                                color:    Colors.white38,
                                fontSize: 9)),
                      ]),
                    ),
                ]),

                const SizedBox(height: 14),
                Divider(
                    color:  Colors.white.withOpacity(0.06),
                    height: 1),
                const SizedBox(height: 12),

                // ✅ Driver info row ─────────────────────
                Row(children: [

                  // ✅ Driver avatar with real photo
                  _buildDriverAvatar(
                    driverPhoto: driverPhoto,
                    initials:    driverInit,
                    isLoading:   driverId.isNotEmpty &&
                        !_driverCache.containsKey(driverId),
                  ),

                  const SizedBox(width: 10),

                  // ✅ Driver name + label
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(driverName,
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow:
                            TextOverflow.ellipsis),
                        const Text('Your Driver',
                            style: TextStyle(
                                color:    Colors.white30,
                                fontSize: 10)),
                      ],
                    ),
                  ),

                  // Paid badge or status badge
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:        kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kGreen.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wallet_rounded,
                              color: kGreen, size: 10),
                          SizedBox(width: 4),
                          Text('Paid via Wallet',
                              style: TextStyle(
                                color:      kGreen,
                                fontSize:   9,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        sc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sc.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(si, color: sc, size: 10),
                          const SizedBox(width: 4),
                          Text(_sLabel(status),
                              style: TextStyle(
                                color:         sc,
                                fontSize:      9,
                                fontWeight:    FontWeight.bold,
                                letterSpacing: 0.5,
                              )),
                        ],
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // DRIVER AVATAR WIDGET
  // ══════════════════════════════════════════════════
  Widget _buildDriverAvatar({
    required String driverPhoto,
    required String initials,
    required bool   isLoading,
  }) {
    // Still fetching
    if (isLoading) {
      return Container(
        width:  42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kCardNavy,
          border: Border.all(
              color: kCyan.withOpacity(0.3), width: 1.5),
        ),
        child: const Center(
          child: SizedBox(
            width:  16,
            height: 16,
            child: CircularProgressIndicator(
                color: kCyan, strokeWidth: 2),
          ),
        ),
      );
    }

    // Has photo
    if (driverPhoto.isNotEmpty) {
      return Container(
        width:  42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: kCyan.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
                color:      kCyan.withOpacity(0.2),
                blurRadius: 8)
          ],
        ),
        child: ClipOval(
          child: Image.network(
            driverPhoto,
            width:  42,
            height: 42,
            fit:    BoxFit.cover,
            loadingBuilder: (_, child, prog) =>
            prog == null
                ? child
                : Container(
              color: kDeep,
              child: const Center(
                child: SizedBox(
                  width:  14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: kCyan, strokeWidth: 2),
                ),
              ),
            ),
            errorBuilder: (_, __, ___) =>
                _initialsAvatar(initials),
          ),
        ),
      );
    }

    // Fallback initials
    return _initialsAvatar(initials);
  }

  Widget _initialsAvatar(String initials) {
    return Container(
      width:  42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
            colors: [Color(0xFF0F3460), kCyan],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight),
        border: Border.all(
            color: kCyan.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color:      kCyan.withOpacity(0.15),
              blurRadius: 8)
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.bold,
            fontSize:   14,
          ),
        ),
      ),
    );
  }

  Widget _locationText(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color:         Colors.white24,
              fontSize:      8,
              letterSpacing: 1,
              fontWeight:    FontWeight.bold,
            )),
        const SizedBox(height: 2),
        Text(val,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   13,
              fontWeight: FontWeight.w500,
            ),
            maxLines:  1,
            overflow:  TextOverflow.ellipsis),
      ],
    );
  }
}

