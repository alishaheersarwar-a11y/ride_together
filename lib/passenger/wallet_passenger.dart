import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride_together/services/wallet_service.dart';

class WalletPassenger extends StatefulWidget {
  const WalletPassenger({super.key});

  @override
  State<WalletPassenger> createState() => _WalletPassengerState();
}

class _WalletPassengerState extends State<WalletPassenger>
    with TickerProviderStateMixin {

  // ── Colors ──────────────────────────────────────────────────
  static const Color kBg     = Color(0xFF0A1628);
  static const Color kCard   = Color(0xFF1A2340);
  static const Color kTeal   = Color(0xFF4ECDC4);
  static const Color kGreen  = Color(0xFF6BCB77);
  static const Color kRed    = Color(0xFFFF6B6B);
  static const Color kYellow = Color(0xFFFFD93D);

  late AnimationController _cardController;
  late AnimationController _balanceController;
  late Animation<double>   _cardAnimation;
  late Animation<double>   _balanceAnimation;
  late Animation<double>   _fadeAnimation;

  // Track the animated "count-up" target so we re-trigger on balance change
  double _animatedBalanceTarget = 0.0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _balanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve:  Curves.easeOutBack,
    );
    _balanceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _balanceController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _balanceController,
        curve:  const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _cardController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _balanceController.forward();
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  // ── Re-run the count-up animation whenever balance changes ──
  void _triggerBalanceAnim(double newBalance) {
    if (newBalance != _animatedBalanceTarget) {
      _animatedBalanceTarget = newBalance;
      _balanceController
        ..reset()
        ..forward();
    }
  }

  // ── Top-Up Sheet ─────────────────────────────────────────────
  void _showTopUpSheet() {
    final TextEditingController amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color:        kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Money',
                style: TextStyle(
                  color:         Colors.white,
                  fontSize:      22,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter amount to top up your wallet',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller:      amountController,
                keyboardType:    TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  prefixText:  'Rs ',
                  prefixStyle: const TextStyle(
                    color:      kTeal,
                    fontSize:   18,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText:  '0',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled:    true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:   BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                    const BorderSide(color: kTeal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Quick-amount chips
              Wrap(
                spacing: 10,
                children: [500, 1000, 2000, 5000].map((amt) {
                  return GestureDetector(
                    onTap: () =>
                    amountController.text = amt.toString(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border:       Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'Rs $amt',
                        style: const TextStyle(
                          color:      Colors.white70,
                          fontSize:   13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
                    foregroundColor: kBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final val =
                    double.tryParse(amountController.text);
                    if (val != null && val > 0 && _uid.isNotEmpty) {
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                      try {
                        // ✅ Write to Firebase via WalletService
                        await WalletService.topUp(
                          userId: _uid,
                          role:   'passenger',
                          amount: val,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Rs ${val.toStringAsFixed(0)} added!'),
                              backgroundColor: kGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Top-up failed: $e'),
                              backgroundColor: kRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text(
                    'Add Money',
                    style: TextStyle(
                      fontSize:      16,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Text('Not logged in',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Wallet',
          style: TextStyle(
            color:         Colors.white,
            fontSize:      18,
            fontWeight:    FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.more_horiz_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),

      // ── Real-time balance stream ────────────────────────────
      body: StreamBuilder<double>(
        stream: WalletService.balanceStream(_uid, 'passenger'),
        builder: (context, balanceSnap) {
          final double balance = balanceSnap.data ?? 0.0;

          // Kick off count-up animation on new balance value
          WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _triggerBalanceAnim(balance));

          return Column(
            children: [

              // ── Wallet Card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ScaleTransition(
                  scale: _cardAnimation,
                  child: Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D6FA4), Color(0xFF0E3F6E)],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:      const Color(0xFF1D6FA4)
                              .withOpacity(0.4),
                          blurRadius: 30,
                          offset:     const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:        Colors.white
                                        .withOpacity(0.15),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                    size:  18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'RideTogether Pay',
                                  style: TextStyle(
                                    color:         Colors.white70,
                                    fontSize:      13,
                                    fontWeight:    FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kTeal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: kTeal.withOpacity(0.4)),
                              ),
                              child: const Text(
                                '● Active',
                                style: TextStyle(
                                  color:      kTeal,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            color:         Colors.white54,
                            fontSize:      13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // ✅ Animated balance from Firebase stream
                        AnimatedBuilder(
                          animation: _balanceAnimation,
                          builder: (_, __) {
                            final displayed =
                                balance * _balanceAnimation.value;
                            return Text(
                              'Rs ${displayed.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color:         Colors.white,
                                fontSize:      38,
                                fontWeight:    FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Stats row — computed from real transactions
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: WalletService.transactionsStream(
                              _uid, 'passenger'),
                          builder: (ctx, txSnap) {
                            final txs = txSnap.data ?? [];

                            final totalSpent = txs
                                .where((t) => t['type'] == 'debit')
                                .fold<double>(
                                0,
                                    (sum, t) =>
                                sum +
                                    (double.tryParse(
                                        t['amount'].toString()) ??
                                        0));


                            final totalRides = txs
                                .where((t) => t['type'] == 'debit')
                                .length;

                            // Cashback = any credit that isn't a top-up
                            final cashback = txs
                                .where((t) =>
                            t['type'] == 'credit' &&
                                (t['title']?.toString() ?? '')
                                    .toLowerCase() !=
                                    'wallet top-up')
                                .fold<double>(
                                0,
                                    (sum, t) =>
                                sum +
                                    (double.tryParse(
                                        t['amount'].toString()) ??
                                        0));

                            return Row(
                              children: [
                                _cardStat('Total Spent',
                                    'Rs ${totalSpent.toStringAsFixed(0)}'),
                                _vDivider(),
                                _cardStat('Rides', '$totalRides'),
                                _vDivider(),
                                _cardStat('Cashback',
                                    'Rs ${cashback.toStringAsFixed(0)}'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // ── Transactions Header ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        color:         Colors.white,
                        fontSize:      17,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'See all',
                      style: TextStyle(
                        color:      kTeal.withOpacity(0.8),
                        fontSize:   13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Transactions List (real-time from Firebase) ──
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: WalletService.transactionsStream(
                        _uid, 'passenger'),
                    builder: (context, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: kTeal),
                        );
                      }

                      final txs = snap.data ?? [];

                      if (txs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_rounded,
                                  color: Colors.white12, size: 60),
                              const SizedBox(height: 12),
                              const Text('No transactions yet',
                                  style: TextStyle(
                                      color:    Colors.white38,
                                      fontSize: 15)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Your ride history will appear here',
                                  style: TextStyle(
                                      color:    Colors.white24,
                                      fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        itemCount: txs.length,
                        itemBuilder: (context, i) {
                          final tx       = txs[i];
                          final isCredit = tx['type'] == 'credit';
                          final amount   = double.tryParse(
                              tx['amount'].toString()) ??
                              0.0;
                          final ts   = tx['timestamp'] as int? ?? 0;
                          final date =
                          DateTime.fromMillisecondsSinceEpoch(ts);
                          final timeStr =
                              '${date.day}/${date.month}  '
                              '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

                          // Icon & color
                          final Color txColor =
                          isCredit ? kGreen : kRed;
                          final IconData txIcon = isCredit
                              ? Icons.add_circle_rounded
                              : Icons.directions_car_rounded;

                          // Subtitle: prefer stored subtitle, else timestamp
                          final String subtitle =
                          (tx['subtitle']?.toString().isNotEmpty ==
                              true)
                              ? tx['subtitle'].toString()
                              : timeStr;

                          return Container(
                            margin:  const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                // Icon bubble
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: txColor.withOpacity(0.12),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Icon(txIcon,
                                      color: txColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                // Title + subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx['title']?.toString() ??
                                            'Transaction',
                                        style: const TextStyle(
                                          color:      Colors.white,
                                          fontSize:   14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          color:    Colors.white38,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Amount
                                Text(
                                  '${isCredit ? '+' : '-'}Rs '
                                      '${amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color:      txColor,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // ── FAB ─────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       _showTopUpSheet,
        backgroundColor: kTeal,
        foregroundColor: kBg,
        elevation:       4,
        icon:  const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Money',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  Widget _cardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   14,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }

  Widget _vDivider() => Container(
    width:  1,
    height: 30,
    color:  Colors.white12,
    margin: const EdgeInsets.symmetric(horizontal: 20),
  );

  Widget _actionButton({
    required IconData   icon,
    required String     label,
    required Color      color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
