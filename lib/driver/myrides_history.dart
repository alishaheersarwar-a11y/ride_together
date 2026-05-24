import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ── Colors ────────────────────────────────────────────────────
const Color kBg      = Color(0xFF0F1219);
const Color kBgDeep  = Color(0xFF07090C);
const Color kCard    = Color(0xFF1C212B);
const Color kDeep    = Color(0xFF0F1A2E);
const Color kCyan    = Color(0xFF00E5FF);
const Color kGreen   = Color(0xFF00C853);
const Color kAmber   = Color(0xFFFFB300);
const Color kError   = Color(0xFFFF4B2B);
const Color kPurple  = Color(0xFF7C4DFF);
const Color kGold    = Color(0xFFFFD700);

class DriverHistory extends StatefulWidget {
  const DriverHistory({super.key});

  @override
  State<DriverHistory> createState() => _DriverHistoryState();
}

class _DriverHistoryState extends State<DriverHistory>
    with SingleTickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allRides      = [];
  List<Map<String, dynamic>> _filteredRides = [];
  final Map<String, Map<String, String>> _passengerCache = {};
  final Map<String, List<Map<String, dynamic>>> _ratingsCache = {};

  bool   _isLoading    = true;
  String _activeFilter = 'All';
  String _activeSort   = 'Newest';

  // ── Stats ─────────────────────────────────────────────────────
  int    _totalRides   = 0;
  int    _completed    = 0;
  int    _cancelled    = 0;
  double _avgRating    = 0;
  int    _ratingCount  = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final List<String> _filters = [
    'All', 'Completed', 'Accepted', 'Pending', 'Rejected'
  ];
  final List<String> _sorts = [
    'Newest', 'Oldest', 'Highest Fare', 'Lowest Fare'
  ];

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(
        parent: _fadeCtrl, curve: Curves.easeIn);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // LOAD DATA
  // ══════════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadRides(),
        _loadDriverRatings(),
      ]);
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadRides() async {
    if (_uid.isEmpty) return;

    final snap = await FirebaseDatabase.instance
        .ref('ride_requests')
        .orderByChild('driverId')
        .equalTo(_uid)
        .get();

    if (!snap.exists || snap.value == null) return;

    final raw  = Map<String, dynamic>.from(snap.value as Map);
    final List<Map<String, dynamic>> rides = [];

    raw.forEach((key, val) {
      final r = Map<String, dynamic>.from(val as Map);
      r['_key'] = key;

      r['pickup'] = r['pickup']?.toString().isNotEmpty == true
          ? r['pickup'].toString()
          : r['pickupAddress']?.toString() ?? 'Pickup';

      r['destination'] =
      r['destination']?.toString().isNotEmpty == true
          ? r['destination'].toString()
          : r['destAddress']?.toString() ?? 'Destination';

      r['passengerName'] =
      r['passengerName']?.toString().isNotEmpty == true
          ? r['passengerName'].toString()
          : r['passenger_name']?.toString() ?? 'Passenger';

      rides.add(r);
    });

    _sortList(rides, _activeSort);

    // Stats
    int    completed = 0, cancelled = 0;

    for (final r in rides) {
      final s = r['status']?.toString().toLowerCase() ?? '';
      if (s == 'completed') {
        completed++;
      }
      if (s == 'rejected' || s == 'cancelled') cancelled++;
    }

    if (mounted) {
      setState(() {
        _allRides      = rides;
        _filteredRides = rides;
        _totalRides    = rides.length;
        _completed     = completed;
        _cancelled     = cancelled;
      });
    }

    // Fetch passenger profiles in background
    await _fetchPassengerProfiles(rides);
  }

  Future<void> _loadDriverRatings() async {
    if (_uid.isEmpty) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('driver_reviews')
          .child(_uid)
          .get();

      if (!snap.exists || snap.value == null) return;

      final raw     = Map<String, dynamic>.from(snap.value as Map);
      double total  = 0;
      int    count  = 0;
      final List<Map<String, dynamic>> reviews = [];

      raw.forEach((key, val) {
        final r = Map<String, dynamic>.from(val as Map);
        r['_key'] = key;
        final stars = double.tryParse(
            r['rating']?.toString() ?? '0') ??
            0;
        total += stars;
        count++;
        reviews.add(r);
      });

      reviews.sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      if (mounted) {
        setState(() {
          _avgRating   = count > 0 ? total / count : 0;
          _ratingCount = count;
          _ratingsCache[_uid] = reviews;
        });
      }
    } catch (e) {
      debugPrint('Ratings error: $e');
    }
  }

  Future<void> _fetchPassengerProfiles(
      List<Map<String, dynamic>> rides) async {
    final Set<String> ids = {};
    for (final r in rides) {
      final id = r['passengerId']?.toString() ?? '';
      if (id.isNotEmpty && !_passengerCache.containsKey(id)) {
        ids.add(id);
      }
    }

    for (final pid in ids) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref('users')
            .child(pid)
            .get();

        if (snap.exists && snap.value != null) {
          final d = Map<String, dynamic>.from(snap.value as Map);
          final name = d['name']?.toString()     ??
              d['fullName']?.toString()           ??
              'Passenger';
          final photo = d['imageUrl']?.toString()   ??
              d['photoUrl']?.toString()              ??
              d['profileImage']?.toString()          ??
              '';

          if (mounted) {
            setState(() {
              _passengerCache[pid] = {
                'name':     name,
                'imageUrl': photo,
                'initials': _initials(name),
              };
            });
          }
        }
      } catch (_) {}
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  double _calcFare(Map r) {
    final fare  = double.tryParse(r['fare']?.toString()  ?? '0') ?? 0;
    final seats = int.tryParse(r['seats']?.toString()    ?? '1') ?? 1;
    return fare * seats;
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return '?';
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : p[0][0].toUpperCase();
  }

  void _applyFilter(String f) {
    setState(() {
      _activeFilter  = f;
      final base     = f == 'All'
          ? _allRides
          : _allRides.where((r) =>
      (r['status']?.toString().toLowerCase() ?? '')
          == f.toLowerCase()).toList();
      _filteredRides = base;
      _sortList(_filteredRides, _activeSort);
    });
  }

  void _applySort(String s) {
    setState(() {
      _activeSort = s;
      _sortList(_filteredRides, s);
    });
  }

  void _sortList(List<Map<String, dynamic>> list, String s) {
    switch (s) {
      case 'Oldest':
        list.sort((a, b) =>
            (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
        break;
      case 'Highest Fare':
        list.sort((a, b) =>
            _calcFare(b).compareTo(_calcFare(a)));
        break;
      case 'Lowest Fare':
        list.sort((a, b) =>
            _calcFare(a).compareTo(_calcFare(b)));
        break;
      default: // Newest
        list.sort((a, b) =>
            (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    }
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
        '','Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return ts.toString();
    }
  }

  Color _sColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return kGreen;
      case 'accepted':  return kCyan;
      case 'pending':   return kAmber;
      case 'rejected':
      case 'cancelled': return kError;
      default:          return Colors.white38;
    }
  }

  IconData _sIcon(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return Icons.check_circle_rounded;
      case 'accepted':  return Icons.directions_car_rounded;
      case 'pending':   return Icons.hourglass_top_rounded;
      case 'rejected':
      case 'cancelled': return Icons.cancel_rounded;
      default:          return Icons.help_outline;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:        kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ride History',
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
              _passengerCache.clear();
              _loadData();
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
            colors: [kBg, kBgDeep],
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
                _buildRatingBanner(),
                if (_allRides.isNotEmpty)
                  _buildControlsRow(),
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
        Text('Loading your rides...',
            style: TextStyle(
                color: Colors.white38, fontSize: 13)),
      ],
    ),
  );

  // ── Stats Banner ──────────────────────────────────────────────
  Widget _buildStatsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
            _stat('$_totalRides',  'Total',
                Icons.local_taxi_rounded,        kCyan),
            _vDiv(),
            _stat('$_completed',   'Completed',
                Icons.check_circle_rounded,      kGreen),
            _vDiv(),
            _stat('$_cancelled',   'Rejected',
                Icons.cancel_rounded,            kError),
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
                fontSize:   13,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(lbl,
              style: const TextStyle(
                  color:    Colors.white38,
                  fontSize: 9),
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

  // ── Rating Banner ─────────────────────────────────────────────
  Widget _buildRatingBanner() {
    if (_ratingCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            kGold.withOpacity(0.12),
            kAmber.withOpacity(0.06),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kGold.withOpacity(0.3)),
        ),
        child: Row(children: [
          // Stars display
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        kGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded,
                color: kGold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Passenger Ratings',
                    style: TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize:   13,
                    )),
                const SizedBox(height: 4),
                Row(children: [
                  // Star bar
                  ...List.generate(5, (i) {
                    final filled = i < _avgRating.floor();
                    final half   = !filled &&
                        i < _avgRating &&
                        _avgRating - i >= 0.5;
                    return Icon(
                      filled
                          ? Icons.star_rounded
                          : half
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                      color:  kGold,
                      size:   14,
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    '${_avgRating.toStringAsFixed(1)} · $_ratingCount ${_ratingCount == 1 ? 'review' : 'reviews'}',
                    style: const TextStyle(
                        color:    Colors.white54,
                        fontSize: 11),
                  ),
                ]),
              ],
            ),
          ),
          // View reviews button
          if (_ratingsCache[_uid]?.isNotEmpty == true)
            GestureDetector(
              onTap: () => _showReviewsSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:        kGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: kGold.withOpacity(0.3)),
                ),
                child: const Text('View All',
                    style: TextStyle(
                      color:      kGold,
                      fontSize:   11,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Reviews Bottom Sheet ──────────────────────────────────────
  void _showReviewsSheet() {
    final reviews = _ratingsCache[_uid] ?? [];
    showModalBottomSheet(
      context:          context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12192B),
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: kGold, size: 20),
              const SizedBox(width: 8),
              const Text('Passenger Reviews',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        kGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_avgRating.toStringAsFixed(1)} avg',
                  style: const TextStyle(
                      color:      kGold,
                      fontWeight: FontWeight.bold,
                      fontSize:   12),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 360,
              child: ListView.builder(
                itemCount: reviews.length,
                itemBuilder: (_, i) {
                  final rev    = reviews[i];
                  final stars  = double.tryParse(
                      rev['rating']?.toString() ?? '0') ??
                      0;
                  final name   = rev['passengerName']
                      ?.toString() ??
                      'Passenger';
                  final fb     = rev['feedback']?.toString() ?? '';
                  final ts     = _formatDate(rev['timestamp']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius:          18,
                            backgroundColor: kDeep,
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                  color:      kCyan,
                                  fontSize:   12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:   13,
                                    )),
                                Text(ts,
                                    style: const TextStyle(
                                        color:    Colors.white30,
                                        fontSize: 10)),
                              ],
                            ),
                          ),
                          Row(children: List.generate(5, (j) =>
                              Icon(
                                j < stars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: kGold,
                                size:  14,
                              ))),
                        ]),
                        if (fb.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width:   double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Text('"$fb"',
                                style: const TextStyle(
                                  color:      Colors.white60,
                                  fontSize:   12,
                                  fontStyle:  FontStyle.italic,
                                  height:     1.4,
                                )),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Controls Row (Filter + Sort) ──────────────────────────────
  Widget _buildControlsRow() {
    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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
                  duration: const Duration(milliseconds: 200),
                  margin:   const EdgeInsets.only(right: 8),
                  padding:  const EdgeInsets.symmetric(
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
                            borderRadius:
                            BorderRadius.circular(8),
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
        ),
        const SizedBox(height: 6),

        // Sort row
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            itemCount: _sorts.length,
            itemBuilder: (_, i) {
              final s      = _sorts[i];
              final active = _activeSort == s;
              return GestureDetector(
                onTap: () => _applySort(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin:   const EdgeInsets.only(right: 8),
                  padding:  const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? kPurple.withOpacity(0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active
                          ? kPurple
                          : Colors.white.withOpacity(0.08),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (active)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.sort_rounded,
                              color: kPurple, size: 12),
                        ),
                      Text(s,
                          style: TextStyle(
                            color: active
                                ? kPurple
                                : Colors.white24,
                            fontSize:   11,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ── Empty ─────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final filtered = _activeFilter != 'All';
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
                  : Icons.drive_eta_outlined,
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
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              filtered
                  ? 'No rides with this status.'
                  : 'Accepted rides will appear here.',
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
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────
  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: _filteredRides.length,
      itemBuilder: (_, i) => _buildCard(_filteredRides[i]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // RIDE CARD
  // ══════════════════════════════════════════════════════════════
  Widget _buildCard(Map<String, dynamic> ride) {
    final String status  = ride['status']?.toString()          ?? 'unknown';
    final String pickup  = ride['pickup']?.toString()          ?? 'Pickup';
    final String dest    = ride['destination']?.toString()     ?? 'Destination';
    final double fare    = double.tryParse(
        ride['fare']?.toString() ?? '0') ?? 0;
    final int    seats   = int.tryParse(
        ride['seats']?.toString() ?? '1') ?? 1;
    final double total   = fare * seats;
    final String date    = _formatDate(ride['timestamp']);
    final bool   isPaid  =
        ride['paymentStatus']?.toString() == 'paid';
    final bool isCompleted =
        status.toLowerCase() == 'completed';

    // Passenger info
    final String pid   = ride['passengerId']?.toString() ?? '';
    final Map<String, String>? cached = _passengerCache[pid];
    final String pName  = cached?['name']     ??
        ride['passengerName']?.toString()      ??
        'Passenger';
    final String pPhoto = cached?['imageUrl'] ?? '';
    final String pInit  = cached?['initials'] ??
        _initials(pName);

    // Rating given for this ride
    final String requestId = ride['_key']?.toString() ?? '';
    final Map<String, dynamic>? rideReview =
    _ratingsCache[_uid]?.firstWhere(
            (r) => r['requestId'] == requestId,
        orElse: () => <String, dynamic>{});
    final double rideStars = rideReview != null && rideReview.isNotEmpty
        ? (double.tryParse(rideReview['rating']?.toString() ?? '0') ?? 0)
        : 0;

    final Color    sc = _sColor(status);
    final IconData si = _sIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [

          // ── Top bar ─────────────────────────────────────────
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
              Text(status.toUpperCase(),
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
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? kAmber.withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: isCompleted
                      ? Border.all(
                      color: kAmber.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompleted) ...[
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: kAmber, size: 10),
                      const SizedBox(width: 4),
                    ],
                    Text('Rs ${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isCompleted
                              ? kAmber
                              : Colors.white70,
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ]),
          ),

          // ── Body ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [

                // Route
                Row(children: [
                  Column(children: [
                    Container(
                      width:  10, height: 10,
                      decoration: BoxDecoration(
                        color: kCyan, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color:      kCyan.withOpacity(0.4),
                            blurRadius: 6)],
                      ),
                    ),
                    Container(
                      width: 1.5, height: 28,
                      margin:
                      const EdgeInsets.symmetric(vertical: 4),
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
                      width:  10, height: 10,
                      decoration: BoxDecoration(
                        color: kError, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color:      kError.withOpacity(0.4),
                            blurRadius: 6)],
                      ),
                    ),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _locText('FROM', pickup),
                        const SizedBox(height: 12),
                        _locText('TO',   dest),
                      ],
                    ),
                  ),
                  if (seats > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
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
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                const SizedBox(height: 12),

                // ✅ Passenger info row ────────────────────────
                Row(children: [
                  // Avatar
                  _buildPassengerAvatar(
                    photo:     pPhoto,
                    initials:  pInit,
                    isLoading: pid.isNotEmpty &&
                        !_passengerCache.containsKey(pid),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(pName,
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis),
                        const Text('Passenger',
                            style: TextStyle(
                                color:    Colors.white30,
                                fontSize: 10)),
                      ],
                    ),
                  ),

                  // ✅ Rating given for THIS ride
                  if (rideStars > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:        kGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: kGold, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            rideStars.toStringAsFixed(0),
                            style: const TextStyle(
                              color:      kGold,
                              fontSize:   11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

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
                          Text('Paid',
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
                          horizontal: 8, vertical: 4),
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
                          const SizedBox(width: 3),
                          Text(status.toUpperCase(),
                              style: TextStyle(
                                color:      sc,
                                fontSize:   9,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                ]),

                // ── Fare breakdown ────────────────────────────
                if (seats > 1 && fare > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: kAmber.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: kAmber.withOpacity(0.12)),
                    ),
                    child: Row(children: [
                      Icon(Icons.receipt_long_rounded,
                          color: kAmber.withOpacity(0.6),
                          size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'Rs ${fare.toStringAsFixed(0)} × $seats seats',
                        style: TextStyle(
                            color:    Colors.white.withOpacity(0.4),
                            fontSize: 11),
                      ),
                      const Spacer(),
                      Text('= Rs ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color:      kAmber,
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                  ),
                ],

                // ── Paid indicator ────────────────────────────
                if (isPaid) ...[
                  const SizedBox(height: 8),
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:        kGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: kGreen.withOpacity(0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.check_circle_rounded,
                          color: kGreen, size: 13),
                      SizedBox(width: 6),
                      Text('Payment received via Wallet',
                          style: TextStyle(
                            color:      kGreen,
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                ],

                // ── Review text if rated ──────────────────────
                if (rideStars > 0 &&
                    (rideReview?['feedback']?.toString() ?? '')
                        .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: kGold.withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.format_quote_rounded,
                          color: kGold, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rideReview!['feedback'].toString(),
                          style: const TextStyle(
                            color:      Colors.white54,
                            fontSize:   11,
                            fontStyle:  FontStyle.italic,
                          ),
                          maxLines:  2,
                          overflow:  TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Passenger Avatar ──────────────────────────────────────────
  Widget _buildPassengerAvatar({
    required String photo,
    required String initials,
    required bool   isLoading,
  }) {
    if (isLoading) {
      return Container(
        width:  40, height: 40,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          color:  kCard,
          border: Border.all(
              color: kCyan.withOpacity(0.3), width: 1.5),
        ),
        child: const Center(
          child: SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                color: kCyan, strokeWidth: 2),
          ),
        ),
      );
    }

    if (photo.isNotEmpty) {
      return Container(
        width:  40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: kCyan.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
                color:      kCyan.withOpacity(0.15),
                blurRadius: 6)
          ],
        ),
        child: ClipOval(
          child: Image.network(
            photo,
            width: 40, height: 40,
            fit:   BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _initialsAvatar(initials),
          ),
        ),
      );
    }

    return _initialsAvatar(initials);
  }

  Widget _initialsAvatar(String initials) {
    return Container(
      width:  40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
            colors: [kDeep, Color(0xFF1A4080)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight),
        border: Border.all(
            color: kCyan.withOpacity(0.3), width: 1.5),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
              color:      kCyan,
              fontWeight: FontWeight.bold,
              fontSize:   13,
            )),
      ),
    );
  }

  Widget _locText(String label, String val) {
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
