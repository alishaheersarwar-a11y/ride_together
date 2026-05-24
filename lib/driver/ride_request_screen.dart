import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/chat/chat_screen.dart';

class RideRequestsScreen extends StatefulWidget {
  const RideRequestsScreen({super.key});

  @override
  State<RideRequestsScreen> createState() =>
      _RideRequestsScreenState();
}

class _RideRequestsScreenState
    extends State<RideRequestsScreen> {

  // ── Colors ───────────────────────────────────────
  static const Color bgTop     = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kDeep     = Color(0xFF0F3460);
  static const Color kCyan     = Color(0xFF00FFB3);
  static const Color kBlue     = Color(0xFF00D4FF);
  static const Color kError    = Color(0xFFFF4B2B);
  static const Color kAmber    = Color(0xFFFFB347);
  static const Color kDark     = Color(0xFF0F0F1A);

  // ✅ Passenger photo cache: passengerId → imageUrl
  final Map<String, String> _photoCache = {};
  // Track which IDs are currently being fetched
  final Set<String> _fetching = {};

  String? get _uid =>
      FirebaseAuth.instance.currentUser?.uid;

  // ════════════════════════════════════════════════
  // ✅ FETCH PASSENGER PHOTO
  // ════════════════════════════════════════════════
  Future<void> _fetchPassengerPhoto(
      String passengerId) async {
    if (passengerId.isEmpty) return;
    if (_photoCache.containsKey(passengerId)) return;
    if (_fetching.contains(passengerId)) return;

    _fetching.add(passengerId);

    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(passengerId)
          .get();

      String photo = '';
      if (snap.exists && snap.value != null) {
        final d = Map<String, dynamic>.from(
            snap.value as Map);
        photo = d['imageUrl']?.toString()     ??
            d['photoUrl']?.toString()         ??
            d['profileImage']?.toString()     ??
            d['photo']?.toString()            ??
            '';
      }

      if (mounted) {
        setState(() {
          _photoCache[passengerId] = photo;
          _fetching.remove(passengerId);
        });
      }
    } catch (_) {
      _photoCache[passengerId] = '';
      _fetching.remove(passengerId);
    }
  }

  // ════════════════════════════════════════════════
  // ACCEPT
  // ════════════════════════════════════════════════
  Future<void> _acceptRequest(
      String requestId, String rideId, int seats) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('ride_requests')
          .child(requestId)
          .update({
        'status':     'accepted',
        'acceptedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (rideId.isNotEmpty) {
        final rideRef = FirebaseDatabase.instance
            .ref()
            .child('available_rides')
            .child(rideId);
        final snap = await rideRef.get();
        if (snap.exists && snap.value != null) {
          final data = Map<String, dynamic>.from(
              snap.value as Map);
          final int cur = int.tryParse(
              data['seats']?.toString() ?? '0') ??
              0;
          await rideRef.update(
              {'seats': (cur - seats).clamp(0, 99)});
        }
      }

      final pid =
      await _getPassengerIdForRequest(requestId);
      if (pid.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref()
            .child('notifications')
            .child(pid)
            .push()
            .set({
          'title':     'Ride Accepted! 🎉',
          'body':      'Your driver accepted your ride request.',
          'requestId': requestId,
          'status':    'accepted',
          'timestamp': ServerValue.timestamp,
        });
      }

      _showSnack('Request Accepted ✓', kCyan);
    } catch (e) {
      _showSnack('Error: $e', kError);
    }
  }

  // ════════════════════════════════════════════════
  // REJECT
  // ════════════════════════════════════════════════
  Future<void> _rejectRequest(String requestId) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('ride_requests')
          .child(requestId)
          .update({'status': 'rejected'});

      final pid =
      await _getPassengerIdForRequest(requestId);
      if (pid.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref()
            .child('notifications')
            .child(pid)
            .push()
            .set({
          'title':     'Ride Declined',
          'body':      'Your ride request was declined.',
          'requestId': requestId,
          'status':    'rejected',
          'timestamp': ServerValue.timestamp,
        });
      }

      _showSnack('Request Rejected', kError);
    } catch (e) {
      _showSnack('Error: $e', kError);
    }
  }

  Future<String> _getPassengerIdForRequest(
      String requestId) async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('ride_requests')
          .child(requestId)
          .child('passengerId')
          .get();
      return snap.value?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style:
          const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _openChat(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          requestId:     data['_key']          ?? '',
          otherUserId:   data['passengerId']   ?? '',
          otherUserName: data['passengerName'] ?? 'Passenger',
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: bgTop,
        body: Center(
            child: Text('Not logged in',
                style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: bgTop,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref()
                    .child('ride_requests')
                    .orderByChild('driverId')
                    .equalTo(uid)
                    .onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: kCyan));
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                                color: Colors.white)));
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value ==
                          null) {
                    return _emptyState();
                  }

                  final Map raw = Map.from(
                      snapshot.data!.snapshot.value
                      as Map);
                  final List<Map<String, dynamic>> requests = [];

                  raw.forEach((key, value) {
                    if (value == null) return;
                    final d = Map<String, dynamic>.from(
                        value as Map);
                    d['_key'] = key;
                    requests.add(d);

                    // ✅ Trigger photo fetch for each passenger
                    final pid =
                        d['passengerId']?.toString() ?? '';
                    if (pid.isNotEmpty) {
                      _fetchPassengerPhoto(pid);
                    }
                  });

                  requests.sort((a, b) {
                    final ta = int.tryParse(
                        a['timestamp']?.toString() ??
                            '0') ??
                        0;
                    final tb = int.tryParse(
                        b['timestamp']?.toString() ??
                            '0') ??
                        0;
                    return tb.compareTo(ta);
                  });

                  final pending  = requests.where((r) =>
                  r['status'] == 'pending').toList();
                  final accepted = requests.where((r) =>
                  r['status'] == 'accepted').toList();
                  final others   = requests.where((r) =>
                  r['status'] != 'pending' &&
                      r['status'] != 'accepted').toList();

                  if (requests.isEmpty) return _emptyState();

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    children: [
                      if (pending.isNotEmpty) ...[
                        _sectionLabel(
                            'NEW REQUESTS', kAmber,
                            pending.length),
                        const SizedBox(height: 12),
                        ...pending.map(_requestCard),
                      ],
                      if (accepted.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionLabel(
                            'ACCEPTED', kCyan,
                            accepted.length),
                        const SizedBox(height: 12),
                        ...accepted.map(_requestCard),
                      ],
                      if (others.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionLabel(
                            'HISTORY', Colors.white30,
                            others.length),
                        const SizedBox(height: 12),
                        ...others.map(_requestCard),
                      ],
                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // APP BAR
  // ════════════════════════════════════════════════
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: kDark,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.3),
              blurRadius: 10)
        ],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            'RIDE REQUESTS',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color:         Colors.white,
              fontSize:      16,
              fontWeight:    FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        kCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: kCyan.withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(
              width:  6,
              height: 6,
              decoration: const BoxDecoration(
                  color:  kCyan,
                  shape:  BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text('LIVE',
                style: TextStyle(
                  color:      kCyan,
                  fontSize:   9,
                  fontWeight: FontWeight.bold,
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(
      String label, Color color, int count) {
    return Row(children: [
      Text(label,
          style: TextStyle(
            color:         color,
            fontSize:      11,
            fontWeight:    FontWeight.bold,
            letterSpacing: 1.5,
          )),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: TextStyle(
              color:      color,
              fontSize:   10,
              fontWeight: FontWeight.bold,
            )),
      ),
    ]);
  }

  // ════════════════════════════════════════════════
  // REQUEST CARD
  // ════════════════════════════════════════════════
  Widget _requestCard(Map<String, dynamic> data) {
    final String requestId  = data['_key']          ?? '';
    final String rideId     = data['rideId']         ?? '';
    final String name       = data['passengerName']  ?? 'Passenger';
    final String pid        = data['passengerId']?.toString() ?? '';

    final String pickup = data['pickup']?.toString()
        .isNotEmpty == true
        ? data['pickup'].toString()
        : data['pickupAddress']?.toString() ?? '';

    final String destination =
    data['destination']?.toString().isNotEmpty == true
        ? data['destination'].toString()
        : data['destinationAddress']?.toString() ?? '';

    final String fare   = data['fare']?.toString()  ?? '0';
    final int    seats  = int.tryParse(
        data['seats']?.toString() ?? '1') ?? 1;
    final String status = data['status']            ?? 'pending';
    final String date   = data['date']?.toString()  ?? '';
    final String time   = data['time']?.toString()  ?? '';

    final bool isPending  = status == 'pending';
    final bool isAccepted = status == 'accepted';

    final Color statusColor = status == 'accepted'
        ? kCyan
        : status == 'rejected'
        ? kError
        : kAmber;

    // ✅ Get cached photo
    final String photo = _photoCache[pid] ?? '';
    final bool   isLoadingPhoto =
        pid.isNotEmpty &&
            !_photoCache.containsKey(pid);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        kCardNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: statusColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color:      statusColor.withOpacity(0.05),
              blurRadius: 12,
              offset:     const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [

          // ── Header ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kDeep.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(children: [

              // ✅ Passenger avatar — real photo or initial
              _buildPassengerAvatar(
                name:          name,
                photo:         photo,
                statusColor:   statusColor,
                isLoading:     isLoadingPhoto,
              ),

              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   15,
                        )),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.event_seat,
                          color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                          '$seats seat${seats > 1 ? 's' : ''}',
                          style: TextStyle(
                              color:    statusColor,
                              fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.access_time,
                          color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Text(
                          time.isNotEmpty ? time : 'N/A',
                          style: const TextStyle(
                              color:    Colors.white38,
                              fontSize: 11)),
                    ]),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color:         statusColor,
                    fontSize:      9,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ]),
          ),

          // ── Body ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _routeRow(pickup, destination),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _infoTile(
                      Icons.payments_rounded,
                      'FARE',
                      'PKR $fare',
                      kCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoTile(
                      Icons.calendar_today,
                      'DATE',
                      date.isNotEmpty ? date : 'N/A',
                      kBlue,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Accept / Reject
                if (isPending)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _rejectRequest(requestId),
                        icon: const Icon(Icons.close,
                            size: 16),
                        label: const Text('REJECT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kError,
                          side: const BorderSide(
                              color: kError),
                          padding: const EdgeInsets
                              .symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptRequest(
                            requestId, rideId, seats),
                        icon: const Icon(Icons.check,
                            size: 16),
                        label: const Text('ACCEPT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:  kCyan,
                          foregroundColor:  Colors.black,
                          padding: const EdgeInsets
                              .symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12)),
                          elevation:   4,
                          shadowColor: kCyan.withOpacity(
                              0.4),
                        ),
                      ),
                    ),
                  ]),

                // Chat button
                if (isAccepted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openChat(data),
                      icon: const Icon(
                          Icons.chat_bubble_rounded,
                          size: 18),
                      label: const Text(
                        'CHAT WITH PASSENGER',
                        style: TextStyle(
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets
                            .symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(14)),
                        elevation:   6,
                        shadowColor: kCyan.withOpacity(0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ✅ PASSENGER AVATAR WIDGET
  // ════════════════════════════════════════════════
  Widget _buildPassengerAvatar({
    required String name,
    required String photo,
    required Color  statusColor,
    required bool   isLoading,
  }) {
    final String initial =
    name.isNotEmpty ? name[0].toUpperCase() : 'P';

    // Still loading photo from Firebase
    if (isLoading) {
      return Container(
        width:  50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kDeep,
          border: Border.all(
              color: statusColor.withOpacity(0.5),
              width: 2),
        ),
        child: const Center(
          child: SizedBox(
            width:  18,
            height: 18,
            child: CircularProgressIndicator(
                color:       kCyan,
                strokeWidth: 2),
          ),
        ),
      );
    }

    // ✅ Has a real photo — show it
    if (photo.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: statusColor, width: 2.5),
          boxShadow: [
            BoxShadow(
                color:      statusColor.withOpacity(0.35),
                blurRadius: 10)
          ],
        ),
        child: ClipOval(
          child: Image.network(
            photo,
            width:  50,
            height: 50,
            fit:    BoxFit.cover,
            loadingBuilder: (_, child, prog) =>
            prog == null
                ? child
                : Container(
              width:  50,
              height: 50,
              color:  kDeep,
              child: const Center(
                child: SizedBox(
                  width:  16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color:       kCyan,
                      strokeWidth: 2),
                ),
              ),
            ),
            errorBuilder: (_, __, ___) =>
                _initialAvatar(initial, statusColor),
          ),
        ),
      );
    }

    // ✅ No photo — show initial letter
    return _initialAvatar(initial, statusColor);
  }

  // ✅ Initial letter avatar
  Widget _initialAvatar(String initial, Color color) {
    return Container(
      width:  50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color:      color.withOpacity(0.3),
              blurRadius: 8)
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color:      Colors.black,
            fontWeight: FontWeight.bold,
            fontSize:   20,
          ),
        ),
      ),
    );
  }

  Widget _routeRow(String pickup, String destination) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        kDeep.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Column(children: [
          const Icon(Icons.radio_button_checked,
              color: kCyan, size: 14),
          Container(
              width: 1, height: 22, color: Colors.white12),
          const Icon(Icons.location_on,
              color: Colors.redAccent, size: 14),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Text(destination,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _infoTile(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    color:         Colors.white30,
                    fontSize:      8,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 1,
                  )),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                    color:      color,
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width:  90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kCyan.withOpacity(0.06),
              border: Border.all(
                  color: kCyan.withOpacity(0.15), width: 2),
            ),
            child: Icon(Icons.inbox_rounded,
                color: kCyan.withOpacity(0.4), size: 40),
          ),
          const SizedBox(height: 20),
          Text('No Requests Yet',
              style: GoogleFonts.poppins(
                color:      Colors.white,
                fontSize:   18,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 8),
          const Text(
            'Ride requests will appear here\nonce passengers book your ride',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
