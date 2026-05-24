import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_together/chat/chat_screen.dart';
import 'package:ride_together/services/location_share_service.dart';
import 'package:ride_together/services/wallet_service.dart';

class MyRideStatusScreen extends StatefulWidget {
  final String requestId;
  final String driverName;

  const MyRideStatusScreen({
    super.key,
    required this.requestId,
    required this.driverName,
  });

  @override
  State<MyRideStatusScreen> createState() => _MyRideStatusScreenState();
}

class _MyRideStatusScreenState extends State<MyRideStatusScreen>
    with SingleTickerProviderStateMixin {

  // ── Palette ─────────────────────────────────────────────────────────
  static const Color kBg          = Color(0xFF0F0F1A);
  static const Color kCardNavy    = Color(0xFF16213E);
  static const Color kAccentCyan  = Color(0xFF00FFB3);
  static const Color kAccentBlue  = Color(0xFF00D4FF);
  static const Color kErrorRed    = Color(0xFFFF4B2B);
  static const Color kWarningGold = Color(0xFFFFB347);
  static const Color kGreen       = Color(0xFF00C853);

  // ── State ────────────────────────────────────────────────────────────
  String? _driverPhotoUrl;
  String  _driverRealName = '';
  bool    _profileLoaded  = false;
  String  _driverIdCache  = '';

  // ── End Ride state ───────────────────────────────────────────────────
  bool   _isEnding       = false;
  bool   _paymentDone    = false;
  double _transferredAmt = 0;

  // ── Pulse animation for pending state ───────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // LOAD DRIVER PROFILE
  // ════════════════════════════════════════════════════════════════════
  Future<void> _loadDriverProfile(String driverId) async {
    if (driverId.isEmpty || driverId == _driverIdCache) return;
    _driverIdCache = driverId;

    for (final node in ['users', 'drivers', 'Drivers', 'Users']) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref('$node/$driverId')
            .get();
        if (snap.exists && snap.value != null) {
          final d = Map<String, dynamic>.from(snap.value as Map);
          final name = d['name']?.toString()        ??
              d['fullName']?.toString()              ??
              d['displayName']?.toString()           ??
              d['driverName']?.toString()            ??
              widget.driverName;
          final photo = d['photoUrl']?.toString()   ??
              d['profileImage']?.toString()          ??
              d['imageUrl']?.toString()              ??
              d['photo']?.toString()                 ??
              d['driverImage']?.toString();
          if (mounted) {
            setState(() {
              _driverRealName = name;
              _driverPhotoUrl = (photo != null && photo.isNotEmpty)
                  ? photo : null;
              _profileLoaded  = true;
            });
          }
          return;
        }
      } catch (_) { continue; }
    }
    if (mounted) {
      setState(() {
        _driverRealName = widget.driverName;
        _profileLoaded  = true;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // END RIDE + WALLET TRANSFER
  // ════════════════════════════════════════════════════════════════════
  Future<void> _endRide() async {
    // ── Confirm dialog ───────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardNavy,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('End this ride?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'The fare will be automatically deducted from your wallet and sent to the driver.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('END & PAY',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isEnding = true);

    try {
      // ── 1. Stop location sharing ──────────────────────────────────
      await LocationShareService.stop();

      // ── 2. Fetch ride request data ────────────────────────────────
      final snap = await FirebaseDatabase.instance
          .ref('ride_requests')
          .child(widget.requestId)
          .get();

      if (!snap.exists || snap.value == null) {
        _showSnack('Ride data not found.', kErrorRed);
        setState(() => _isEnding = false);
        return;
      }

      final data        = Map<String, dynamic>.from(snap.value as Map);
      final passengerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final driverId    = data['driverId']?.toString()  ??
          data['driver_id']?.toString() ?? '';
      final double fare  = double.tryParse(
          data['fare'].toString()) ?? 0;
      final int seats    = int.tryParse(
          data['seats'].toString()) ?? 1;
      final double total = fare * seats;
      final pickup       = data['pickup']?.toString()      ?? '';
      final destination  = data['destination']?.toString() ?? '';

      if (passengerId.isEmpty || driverId.isEmpty) {
        _showSnack('Missing passenger or driver info.', kErrorRed);
        setState(() => _isEnding = false);
        return;
      }

      // ── 3. Transfer wallet: passenger → driver ────────────────────
      final result = await WalletService.transferFare(
        passengerId: passengerId,
        driverId:    driverId,
        fare:        total,
        requestId:   widget.requestId,
        pickup:      pickup,
        destination: destination,
      );

      // ── 4. Mark ride completed ────────────────────────────────────
      await FirebaseDatabase.instance
          .ref('ride_requests')
          .child(widget.requestId)
          .update({
        'status':        'completed',
        'endedAt':       ServerValue.timestamp,
        'endedBy':       'passenger',
        'paymentStatus': result['success'] == true
            ? 'paid'
            : 'insufficient_balance',
      });

      // ── 5. Notify driver ──────────────────────────────────────────
      await FirebaseDatabase.instance
          .ref('notifications')
          .child(driverId)
          .push()
          .set({
        'message':   result['success'] == true
            ? '✅ Ride completed! Rs ${total.toStringAsFixed(0)} added to your wallet.'
            : '⚠️ Ride completed. Passenger had insufficient balance.',
        'type':      'ride_completed',
        'requestId': widget.requestId,
        'isRead':    false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _paymentDone    = true;
          _transferredAmt = total;
          _isEnding       = false;
        });
        // Show success sheet then pop
        await _showPaymentSuccessSheet(total);
      } else {
        setState(() => _isEnding = false);
        _showSnack(
          '⚠️ Ride ended. Insufficient wallet balance — please top up.',
          Colors.orange,
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isEnding = false);
        _showSnack('Error ending ride: $e', kErrorRed);
      }
    }
  }

  // ── Payment success bottom sheet ─────────────────────────────────
  Future<void> _showPaymentSuccessSheet(double amount) async {
    await showModalBottomSheet(
      context:         context,
      isDismissible:   false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A2340),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kGreen.withOpacity(0.15),
                border: Border.all(color: kGreen.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: kGreen, size: 52),
            ),
            const SizedBox(height: 20),
            const Text('Payment Successful!',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 8),
            Text(
              'Rs ${amount.toStringAsFixed(0)} has been sent to your driver.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Amount pill
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color:        kGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                    color: kGreen.withOpacity(0.3), width: 1.5),
              ),
              child: Text(
                '− Rs ${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color:      kGreen,
                  fontSize:   28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width:  double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('DONE',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize:   16,
                        letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref('ride_requests')
            .child(widget.requestId)
            .onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kAccentCyan));
          }
          if (!snapshot.hasData ||
              snapshot.data!.snapshot.value == null) {
            return _buildErrorState('Request not found or deleted.');
          }

          final data     = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map);
          final status   = data['status']?.toString()   ?? 'pending';
          final driverId = data['driverId']?.toString() ??
              data['driver_id']?.toString()              ??
              data['driverUid']?.toString()              ?? '';

          if (driverId.isNotEmpty && !_profileLoaded) {
            WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _loadDriverProfile(driverId));
          }

          final resolvedName = _driverRealName.isNotEmpty
              ? _driverRealName
              : widget.driverName;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(status),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStatusHeader(status),
                      const SizedBox(height: 24),
                      _buildMainStatusCard(data, status, resolvedName),
                      const SizedBox(height: 20),
                      _buildRouteDetails(data),
                      const SizedBox(height: 20),
                      if (status == 'completed') _buildPaymentSummary(data),
                      const SizedBox(height: 30),
                      _buildBottomAction(data, status, resolvedName),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SLIVER APP BAR
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSliverAppBar(String status) {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: kBg,
      floating: false,
      pinned:   true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text('RIDE STATUS',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize:   14,
              letterSpacing: 2,
              color: Colors.white,
            )),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
              colors: [kAccentBlue.withOpacity(0.15), kBg],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATUS STEPPER
  // ════════════════════════════════════════════════════════════════════
  Widget _buildStatusHeader(String status) {
    int step = 0;
    if (status == 'pending')   step = 1;
    if (status == 'accepted')  step = 2;
    if (status == 'completed') step = 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot('Sent',    step >= 0, step == 0),
        _stepLine(step >= 1),
        _stepDot('Review',  step >= 1, step == 1),
        _stepLine(step >= 2),
        _stepDot('Ready',   step >= 2, step == 2),
        _stepLine(step >= 3),
        _stepDot('Done',    step >= 3, step == 3),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // MAIN STATUS CARD
  // ════════════════════════════════════════════════════════════════════
  Widget _buildMainStatusCard(
      Map<String, dynamic> data, String status, String resolvedName) {
    final Color statusColor = status == 'accepted'
        ? kAccentCyan
        : status == 'rejected'
        ? kErrorRed
        : status == 'completed'
        ? kGreen
        : kWarningGold;

    final IconData statusIcon = status == 'accepted'
        ? Icons.verified_user_rounded
        : status == 'rejected'
        ? Icons.cancel_rounded
        : status == 'completed'
        ? Icons.flag_circle_rounded
        : Icons.hourglass_empty_rounded;

    final String statusMsg = status == 'pending'
        ? 'Waiting for $resolvedName to respond...'
        : status == 'accepted'
        ? 'Pack your bags! Ride confirmed.'
        : status == 'completed'
        ? 'Your ride has been completed. Thanks for riding!'
        : 'This request was declined.';

    final initial = resolvedName.isNotEmpty
        ? resolvedName[0].toUpperCase()
        : 'D';

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        kCardNavy.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color:      statusColor.withOpacity(0.1),
              blurRadius: 20,
              offset:     const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          // Pulsing icon for pending
          status == 'pending'
              ? ScaleTransition(
            scale: _pulseAnim,
            child: _statusIconWidget(statusIcon, statusColor),
          )
              : _statusIconWidget(statusIcon, statusColor),

          const SizedBox(height: 16),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color:        statusColor,
              fontWeight:   FontWeight.w900,
              fontSize:     24,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(statusMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13)),

          // Driver row — shown when accepted
          if (status == 'accepted') ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child:   Divider(color: Colors.white10),
            ),
            Row(
              children: [
                Container(
                  width:  52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: kAccentCyan, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color:      kAccentCyan.withOpacity(0.3),
                          blurRadius: 10)
                    ],
                  ),
                  child: ClipOval(
                      child: _buildDriverAvatar(52, initial)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileLoaded
                          ? Text(resolvedName,
                          style: const TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:   16),
                          overflow: TextOverflow.ellipsis)
                          : _shimmerBar(width: 120, height: 14),
                      const SizedBox(height: 4),
                      const Text('Professional Driver',
                          style: TextStyle(
                              color: kAccentCyan, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.star,
                    color: kWarningGold, size: 16),
                const Text(' 4.9',
                    style: TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIconWidget(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
      ),
      child: Icon(icon, color: color, size: 48),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ROUTE DETAILS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildRouteDetails(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        kCardNavy.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _locationRow(Icons.radio_button_checked, kAccentCyan,
              data['pickup']?.toString()      ?? 'Unknown'),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  width: 1, height: 20,
                  color: Colors.white10),
            ),
          ),
          _locationRow(Icons.location_on, kErrorRed,
              data['destination']?.toString() ?? 'Unknown'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // PAYMENT SUMMARY (shown after ride completed)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildPaymentSummary(Map<String, dynamic> data) {
    final payStatus = data['paymentStatus']?.toString() ?? '';
    final double fare  = double.tryParse(
        data['fare'].toString()) ?? 0;
    final int seats    = int.tryParse(
        data['seats'].toString()) ?? 1;
    final double total = fare * seats;
    final isPaid       = payStatus == 'paid';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isPaid ? kGreen : kWarningGold).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isPaid ? kGreen : kWarningGold).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPaid ? kGreen : kWarningGold).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
              color: isPaid ? kGreen : kWarningGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaid ? 'Payment Completed' : 'Payment Pending',
                  style: TextStyle(
                    color:      isPaid ? kGreen : kWarningGold,
                    fontWeight: FontWeight.w700,
                    fontSize:   14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPaid
                      ? 'Rs ${total.toStringAsFixed(0)} sent to driver'
                      : 'Please top up your wallet',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${total.toStringAsFixed(0)}',
            style: TextStyle(
              color:      isPaid ? kGreen : kWarningGold,
              fontWeight: FontWeight.w800,
              fontSize:   16,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // BOTTOM ACTIONS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildBottomAction(
      Map<String, dynamic> data, String status, String resolvedName) {
    if (status != 'accepted') return const SizedBox.shrink();

    return Column(
      children: [
        // Chat button
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
                colors: [kAccentCyan, kAccentBlue]),
            boxShadow: [
              BoxShadow(
                  color:      kAccentCyan.withOpacity(0.3),
                  blurRadius: 15,
                  offset:     const Offset(0, 5)),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    requestId:    widget.requestId,
                    otherUserId:  data['driverId']?.toString() ?? '',
                    otherUserName: resolvedName,
                  ),
                ),
              );
            },
            icon:  const Icon(Icons.chat_bubble_rounded, size: 20),
            label: const Text('OPEN CONVERSATION',
                style: TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              shadowColor:     Colors.transparent,
              minimumSize:     const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── END RIDE button with loading state ───────────────────
        SizedBox(
          width:  double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isEnding ? null : _endRide,
            style: ElevatedButton.styleFrom(
              backgroundColor:        kErrorRed,
              foregroundColor:        Colors.white,
              disabledBackgroundColor: kErrorRed.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: kErrorRed.withOpacity(0.4),
            ),
            icon: _isEnding
                ? const SizedBox(
              width:  20,
              height: 20,
              child:  CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2.5),
            )
                : const Icon(Icons.flag_rounded, size: 20),
            label: Text(
              _isEnding ? 'Processing Payment...' : 'END RIDE',
              style: const TextStyle(
                fontWeight:    FontWeight.w900,
                fontSize:      16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        const Text(
          'Fare will be deducted from your wallet automatically',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DRIVER AVATAR
  // ════════════════════════════════════════════════════════════════════
  Widget _buildDriverAvatar(double size, String initial) {
    if (!_profileLoaded) {
      return Container(
        color: kCardNavy,
        child: const Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: kAccentCyan),
          ),
        ),
      );
    }
    if (_driverPhotoUrl != null && _driverPhotoUrl!.isNotEmpty) {
      return Image.network(
        _driverPhotoUrl!,
        width:  size,
        height: size,
        fit:    BoxFit.cover,
        loadingBuilder: (_, child, prog) => prog == null
            ? child
            : Container(
          color: kCardNavy,
          child: const Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kAccentCyan),
            ),
          ),
        ),
        errorBuilder: (_, __, ___) => _initialAvatar(initial, size),
      );
    }
    return _initialAvatar(initial, size);
  }

  Widget _initialAvatar(String initial, double size) {
    return Container(
      width:  size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [kAccentCyan, kAccentBlue]),
      ),
      child: Center(
        child: Text(initial,
            style: TextStyle(
              color:      Colors.black,
              fontWeight: FontWeight.bold,
              fontSize:   size * 0.35,
            )),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════
  Widget _stepDot(String label, bool isActive, bool isCurrent) {
    return Column(
      children: [
        Container(
          width:  12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? kAccentCyan
                : isActive
                ? kAccentCyan.withOpacity(0.4)
                : Colors.white12,
            boxShadow: isCurrent
                ? [const BoxShadow(color: kAccentCyan, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
              color:      isActive ? Colors.white : Colors.white24,
              fontSize:   10,
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }

  Widget _stepLine(bool isActive) {
    return Container(
      width:  40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color:  isActive
          ? kAccentCyan.withOpacity(0.4)
          : Colors.white12,
    );
  }

  Widget _locationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 15),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildErrorState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: kErrorRed, size: 50),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.white54)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back',
                style: TextStyle(color: kAccentCyan)),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBar({required double width, required double height}) {
    return Container(
      width:  width,
      height: height,
      decoration: BoxDecoration(
        color:        Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
