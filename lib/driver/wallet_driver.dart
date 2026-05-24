import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride_together/services/wallet_service.dart';

class WalletDriver extends StatefulWidget {
  const WalletDriver({super.key});

  @override
  State<WalletDriver> createState() => _WalletDriverState();
}

class _WalletDriverState extends State<WalletDriver>
    with TickerProviderStateMixin {

  // ── Colors ──────────────────────────────────────────────────
  static const Color kBg      = Color(0xFF0A1628);
  static const Color kCard    = Color(0xFF1A2340);
  static const Color kGreen   = Color(0xFF4ECDC4);
  static const Color kYellow  = Color(0xFFFFD93D);
  static const Color kRed     = Color(0xFFFF6B6B);
  static const Color kBlue    = Color(0xFF4D9DE0);

  late AnimationController _cardCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _cardAnim;
  late Animation<double>   _fadeAnim;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _cardAnim = CurvedAnimation(
        parent: _cardCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(
        parent: _fadeCtrl, curve: Curves.easeIn);

    _cardCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400),
            () => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Withdraw Sheet ──────────────────────────────────────────
  void _showWithdrawSheet(double currentBalance) {
    final TextEditingController amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: kCard,
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Withdraw Earnings',
                  style: TextStyle(
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w700, letterSpacing: -0.5,
                  )),
              const SizedBox(height: 6),
              Text(
                'Available: Rs ${currentBalance.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  prefixText: 'Rs ',
                  prefixStyle: const TextStyle(
                      color: kGreen, fontSize: 18, fontWeight: FontWeight.w600),
                  hintText: '0',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: kBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final val = double.tryParse(amountCtrl.text);
                    if (val != null && val > 0 && val <= currentBalance) {
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Rs ${val.toStringAsFixed(0)} withdrawal requested!'),
                          backgroundColor: kGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: const Text('Request Withdrawal',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

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
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Driver Wallet',
            style: TextStyle(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w700, letterSpacing: -0.3,
            )),
        centerTitle: true,
      ),

      body: StreamBuilder<double>(
        stream: WalletService.balanceStream(_uid, 'driver'),
        builder: (context, balanceSnap) {
          final double balance = balanceSnap.data ?? 0.0;

          return Column(
            children: [

              // ── Earnings Card ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ScaleTransition(
                  scale: _cardAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E3B), Color(0xFF0D3321)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Text('RideTogether Earnings',
                                    style: TextStyle(
                                      color: Colors.white70, fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: kGreen.withOpacity(0.4)),
                              ),
                              child: const Text('● Active',
                                  style: TextStyle(
                                    color: kGreen, fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text('Total Earnings',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Text(
                          'Rs ${balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 38,
                            fontWeight: FontWeight.w800, letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Stats ──────────────────────────
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: WalletService.transactionsStream(
                              _uid, 'driver'),
                          builder: (ctx, txSnap) {
                            final txs = txSnap.data ?? [];
                            final totalRides = txs
                                .where((t) => t['type'] == 'credit')
                                .length;
                            final todayEarnings = txs.where((t) {
                              final ts = t['timestamp'] as int? ?? 0;
                              final d = DateTime.fromMillisecondsSinceEpoch(ts);
                              final now = DateTime.now();
                              return t['type'] == 'credit' &&
                                  d.day == now.day &&
                                  d.month == now.month &&
                                  d.year == now.year;
                            }).fold<double>(
                                0,
                                    (sum, t) =>
                                sum +
                                    (double.tryParse(
                                        t['amount'].toString()) ??
                                        0));

                            return Row(
                              children: [
                                _cardStat('Total Rides',
                                    '$totalRides'),
                                _divider(),
                                _cardStat('Today',
                                    'Rs ${todayEarnings.toStringAsFixed(0)}'),
                                _divider(),
                                _cardStat('Status', 'Online'),
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

              // ── Transactions Header ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ride Earnings',
                        style: TextStyle(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w700, letterSpacing: -0.3,
                        )),
                    Text('See all',
                        style: TextStyle(
                          color: kGreen.withOpacity(0.8), fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Transactions List ─────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: WalletService.transactionsStream(_uid, 'driver'),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: kGreen));
                      }

                      final txs = snap.data ?? [];

                      if (txs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  color: Colors.white12, size: 60),
                              const SizedBox(height: 12),
                              const Text('No earnings yet',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 15)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Complete rides to see earnings here',
                                  style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: txs.length,
                        itemBuilder: (context, i) {
                          final tx = txs[i];
                          final isCredit = tx['type'] == 'credit';
                          final amount = double.tryParse(
                              tx['amount'].toString()) ??
                              0;
                          final ts = tx['timestamp'] as int? ?? 0;
                          final date =
                          DateTime.fromMillisecondsSinceEpoch(ts);
                          final timeStr =
                              '${date.day}/${date.month}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                  Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isCredit ? kGreen : kRed)
                                        .withOpacity(0.12),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isCredit
                                        ? Icons.directions_car_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isCredit ? kGreen : kRed,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx['title']?.toString() ??
                                            'Transaction',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        tx['subtitle']?.toString()
                                            .isNotEmpty ==
                                            true
                                            ? tx['subtitle'].toString()
                                            : timeStr,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isCredit ? '+' : '-'}Rs ${amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: isCredit ? kGreen : kRed,
                                    fontSize: 14,
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
    );
  }

  Widget _cardStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          )),
    ],
  );

  Widget _divider() => Container(
    width: 1, height: 30, color: Colors.white12,
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      );
}