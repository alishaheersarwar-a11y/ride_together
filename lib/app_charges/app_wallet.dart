import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppWalletScreen extends StatefulWidget {
  const AppWalletScreen({super.key});

  @override
  State<AppWalletScreen> createState() => _AppWalletScreenState();
}

class _AppWalletScreenState extends State<AppWalletScreen> {

  bool _isSigningOut = false;

  static const Color kBg    = Color(0xFF0A0F1E);
  static const Color kCyan  = Color(0xFF00C6A2);
  static const Color kRed   = Color(0xFFFF4B2B);

  Future<void> _onSignOutTapped() async {
    final confirmed = await showDialog<bool>(
      context:            context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF0E1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kRed.withOpacity(0.1),
                  border: Border.all(color: kRed.withOpacity(0.35), width: 1.5),
                ),
                child: const Icon(Icons.logout_rounded, color: kRed, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Sign Out',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Are you sure you want to\nsign out of App Wallet?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRed,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Sign Out',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _performSignOut();
  }

  Future<void> _performSignOut() async {
    setState(() => _isSigningOut = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance
            .ref('users/$uid')
            .update({'isOnline': false}).timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      }
      await Future.wait([
        FirebaseAuth.instance.signOut(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      debugPrint('Sign out error: $e');
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('App Wallet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 20, letterSpacing: 0.5)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                const _BalanceCard(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4, height: 16,
                        decoration: BoxDecoration(
                          color: kCyan,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Service Charge History',
                          style: TextStyle(color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Expanded(child: _TransactionList()),
              ],
            ),
          ),

          // ── Sign Out ────────────────────────────────────────────────
          Container(
            color: kBg,
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
            child: GestureDetector(
              onTap: _isSigningOut ? null : _onSignOutTapped,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSigningOut)
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: kRed, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.logout_rounded, color: kRed, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _isSigningOut ? 'Signing out...' : 'Sign Out',
                      style: TextStyle(
                        color: _isSigningOut ? kRed.withOpacity(0.5) : kRed,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
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

// ── BALANCE CARD ──────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref().child('appWallet').onValue,
      builder: (context, snapshot) {
        double balance  = 0;
        String currency = 'PKR';

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(
                snapshot.data!.snapshot.value as Map);
            balance  = (data['balance']  ?? 0).toDouble();
            currency = (data['currency'] ?? 'PKR').toString();
          } catch (_) {}
        }

        final formatted = NumberFormat('#,##0.00').format(balance);

        return Container(
          margin:  const EdgeInsets.fromLTRB(20, 20, 20, 8),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C6A2), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x4700C6A2), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Total Service Charges Collected',
                      style: TextStyle(color: Colors.white70, fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 22),
              Text('$currency $formatted',
                  style: const TextStyle(color: Colors.white, fontSize: 38,
                      fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Text('Auto-deducted from driver earnings',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ── TRANSACTION LIST ──────────────────────────────────────────────────────────
class _TransactionList extends StatelessWidget {
  const _TransactionList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('appWallet')
          .child('transactions')
          .orderByChild('createdAt')
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00C6A2), strokeWidth: 2),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.snapshot.value == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: Colors.white12, size: 56),
                SizedBox(height: 14),
                Text('No transactions yet',
                    style: TextStyle(color: Colors.white30, fontSize: 14)),
                SizedBox(height: 6),
                Text('Service charges will appear here\nafter rides are completed',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white12, fontSize: 12)),
              ],
            ),
          );
        }

        final rawMap = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map);

        final List<Map<String, dynamic>> txList = rawMap.entries
            .map((e) => Map<String, dynamic>.from(e.value as Map))
            .toList()
          ..sort((a, b) =>
              (b['createdAt'] as int).compareTo(a['createdAt'] as int));

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: txList.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Color(0xFF1E2D45), height: 1),
          itemBuilder: (_, index) =>
              _TransactionTile(data: txList[index]),
        );
      },
    );
  }
}

// ── TRANSACTION TILE — with driver photo + real name ─────────────────────────
class _TransactionTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const _TransactionTile({required this.data});

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile> {

  String? _driverName;
  String? _driverPhoto;
  bool    _loadingDriver = true;
  int     _rideNumber    = 0;

  static const Color kCyan = Color(0xFF00C6A2);

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    _loadRideNumber();
  }

  // ── Fetch driver name + photo from users/{driverId} ───────────────
  Future<void> _loadDriverInfo() async {
    final driverId = widget.data['driverId']?.toString() ?? '';
    if (driverId.isEmpty) {
      setState(() => _loadingDriver = false);
      return;
    }
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users')
          .child(driverId)
          .get();

      if (snap.exists && mounted) {
        final d = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _driverName  = d['name']?.toString();
          _driverPhoto = d['imageUrl']?.toString() ??
              d['photoUrl']?.toString() ??
              d['profileImage']?.toString();
          _loadingDriver = false;
        });
      } else {
        if (mounted) setState(() => _loadingDriver = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDriver = false);
    }
  }

  // ── Get ride serial number from ride_requests ─────────────────────
  Future<void> _loadRideNumber() async {
    final rideId = widget.data['rideId']?.toString() ?? '';
    if (rideId.isEmpty) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('ride_requests')
          .child(rideId)
          .child('rideNumber')
          .get();
      if (snap.exists && mounted) {
        setState(() => _rideNumber = (snap.value as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final double amount = (widget.data['amount']    ?? 0).toDouble();
    final int    ts     = (widget.data['createdAt'] ?? 0) as int;

    final String dateStr = ts > 0
        ? DateFormat('dd MMM yyyy  hh:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(ts))
        : '-';

    // Ride label — use serial number if available, else "Ride"
    final String rideLabel = _rideNumber > 0
        ? 'Ride #$_rideNumber'
        : 'Ride';

    // Driver label
    final String driverLabel = _loadingDriver
        ? 'Loading...'
        : (_driverName?.isNotEmpty == true ? _driverName! : 'Unknown Driver');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [

          // ── Driver avatar (photo or initials) ──────────────────────
          _DriverAvatar(
            photoUrl:  _driverPhoto,
            name:      _driverName,
            isLoading: _loadingDriver,
          ),

          const SizedBox(width: 14),

          // ── Text info ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Ride label
                Text(
                  rideLabel,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:   14,
                  ),
                ),

                const SizedBox(height: 3),

                // Driver name with small icon
                Row(
                  children: [
                    const Icon(Icons.drive_eta_rounded,
                        color: Colors.white38, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        driverLabel,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // Date
                Text(
                  dateStr,
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Amount badge ───────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kCyan.withOpacity(0.35)),
                ),
                child: Text(
                  '+${NumberFormat('#,##0.00').format(amount)}',
                  style: const TextStyle(
                    color:      kCyan,
                    fontWeight: FontWeight.bold,
                    fontSize:   13.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PKR',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── DRIVER AVATAR ─────────────────────────────────────────────────────────────
class _DriverAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final bool    isLoading;

  const _DriverAvatar({
    required this.photoUrl,
    required this.name,
    required this.isLoading,
  });

  // Returns initials from name e.g. "Ali Khan" → "AK"
  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF00C6A2).withOpacity(0.4),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: isLoading

        // Shimmer placeholder while loading
            ? Container(
          color: const Color(0xFF1A2535),
          child: const Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                color: Color(0xFF00C6A2),
                strokeWidth: 1.5,
              ),
            ),
          ),
        )

        // Real photo
            : (photoUrl != null && photoUrl!.isNotEmpty)
            ? Image.network(
          photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget,
        )

        // Initials fallback
            : _initialsWidget,
      ),
    );
  }

  Widget get _initialsWidget => Container(
    color: const Color(0xFF1A2535),
    child: Center(
      child: Text(
        _initials,
        style: const TextStyle(
          color:      Color(0xFF00C6A2),
          fontSize:   16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}






// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class AppWalletScreen extends StatefulWidget {
//   const AppWalletScreen({super.key});
//
//   @override
//   State<AppWalletScreen> createState() => _AppWalletScreenState();
// }
//
// class _AppWalletScreenState extends State<AppWalletScreen> {
//
//   bool _isSigningOut = false;
//
//   static const Color kBg    = Color(0xFF0A0F1E);
//   static const Color kBorder = Color(0xFF1E2D45);
//   static const Color kCyan  = Color(0xFF00C6A2);
//   static const Color kRed   = Color(0xFFFF4B2B);
//
//   Future<void> _onSignOutTapped() async {
//     final confirmed = await showDialog<bool>(
//       context:            context,
//       barrierDismissible: false,
//       builder: (dialogContext) => Dialog(
//         backgroundColor: const Color(0xFF0E1628),
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(28)),
//         child: Padding(
//           padding: const EdgeInsets.all(28),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(18),
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: kRed.withOpacity(0.1),
//                   border: Border.all(
//                       color: kRed.withOpacity(0.35), width: 1.5),
//                 ),
//                 child: const Icon(Icons.logout_rounded,
//                     color: kRed, size: 36),
//               ),
//               const SizedBox(height: 20),
//               const Text('Sign Out',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   )),
//               const SizedBox(height: 10),
//               const Text(
//                 'Are you sure you want to\nsign out of App Wallet?',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                     color: Colors.white54, fontSize: 13, height: 1.5),
//               ),
//               const SizedBox(height: 26),
//               Row(children: [
//                 Expanded(
//                   child: OutlinedButton(
//                     onPressed: () => Navigator.pop(dialogContext, false),
//                     style: OutlinedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(vertical: 13),
//                       side: BorderSide(
//                           color: Colors.white.withOpacity(0.2)),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14)),
//                     ),
//                     child: const Text('Cancel',
//                         style: TextStyle(
//                             color: Colors.white54,
//                             fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () => Navigator.pop(dialogContext, true),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: kRed,
//                       padding: const EdgeInsets.symmetric(vertical: 13),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14)),
//                       elevation: 0,
//                     ),
//                     child: const Text('Sign Out',
//                         style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 15)),
//                   ),
//                 ),
//               ]),
//             ],
//           ),
//         ),
//       ),
//     );
//     if (confirmed != true || !mounted) return;
//     await _performSignOut();
//   }
//
//   Future<void> _performSignOut() async {
//     setState(() => _isSigningOut = true);
//     try {
//       final uid = FirebaseAuth.instance.currentUser?.uid;
//       if (uid != null) {
//         await FirebaseDatabase.instance
//             .ref('users/$uid')
//             .update({'isOnline': false}).timeout(
//           const Duration(seconds: 3),
//           onTimeout: () {},
//         );
//       }
//       await Future.wait([
//         FirebaseAuth.instance.signOut(),
//         Future.delayed(const Duration(milliseconds: 1500)),
//       ]);
//       if (!mounted) return;
//       Navigator.of(context)
//           .pushNamedAndRemoveUntil('/login', (_) => false);
//     } catch (e) {
//       debugPrint('Sign out error: $e');
//       if (mounted) {
//         setState(() => _isSigningOut = false);
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Sign out failed: $e'),
//           backgroundColor: kRed,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12)),
//         ));
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: kBg,
//       appBar: AppBar(
//         backgroundColor: kBg,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.white),
//         // ✅ FIX 1 — remove red border / yellow debug lines by setting
//         //            scrolledUnderElevation to 0 and surfaceTintColor transparent
//         scrolledUnderElevation: 0,
//         surfaceTintColor: Colors.transparent,
//         title: const Text(
//           'App Wallet',
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 20,
//             letterSpacing: 0.5,
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//
//           // ── Balance + Transaction list ───────────────────────────────
//           Expanded(
//             child: Column(
//               children: [
//                 const _BalanceCard(),
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 4, height: 16,
//                         decoration: BoxDecoration(
//                           color: kCyan,
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       const Text(
//                         'Service Charge History',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 15,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Expanded(child: _TransactionList()),
//               ],
//             ),
//           ),
//
//           // ── Sign Out Button ──────────────────────────────────────────
//           // ✅ FIX 2 — no border, no red outline, clean minimal style
//           Container(
//             color: kBg,
//             padding: EdgeInsets.fromLTRB(
//               20, 12, 20,
//               12 + MediaQuery.of(context).padding.bottom,
//             ),
//             child: GestureDetector(
//               onTap: _isSigningOut ? null : _onSignOutTapped,
//               child: Container(
//                 height: 52,
//                 decoration: BoxDecoration(
//                   // ✅ Clean dark container — NO red border, NO yellow lines
//                   color: Colors.white.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // ✅ FIX 3 — show simple spinner, no overlay on list
//                     if (_isSigningOut)
//                       const SizedBox(
//                         width: 16, height: 16,
//                         child: CircularProgressIndicator(
//                           color: kRed, strokeWidth: 2,
//                         ),
//                       )
//                     else
//                       const Icon(Icons.logout_rounded,
//                           color: kRed, size: 18),
//                     const SizedBox(width: 10),
//                     Text(
//                       _isSigningOut ? 'Signing out...' : 'Sign Out',
//                       style: TextStyle(
//                         color: _isSigningOut
//                             ? kRed.withOpacity(0.5)
//                             : kRed,
//                         fontSize: 14.5,
//                         fontWeight: FontWeight.w600,
//                         letterSpacing: 0.3,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── BALANCE CARD ──────────────────────────────────────────────────────────────
// class _BalanceCard extends StatelessWidget {
//   const _BalanceCard();
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<DatabaseEvent>(
//       stream: FirebaseDatabase.instance.ref().child('appWallet').onValue,
//       builder: (context, snapshot) {
//         double balance  = 0;
//         String currency = 'PKR';
//
//         if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
//           try {
//             final data = Map<String, dynamic>.from(
//                 snapshot.data!.snapshot.value as Map);
//             balance  = (data['balance']  ?? 0).toDouble();
//             currency = (data['currency'] ?? 'PKR').toString();
//           } catch (_) {}
//         }
//
//         final formatted = NumberFormat('#,##0.00').format(balance);
//
//         return Container(
//           margin:  const EdgeInsets.fromLTRB(20, 20, 20, 8),
//           padding: const EdgeInsets.all(26),
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(
//               colors: [Color(0xFF00C6A2), Color(0xFF0072FF)],
//               begin:  Alignment.topLeft,
//               end:    Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.circular(24),
//             boxShadow: const [
//               BoxShadow(
//                 color:      Color(0x4700C6A2),
//                 blurRadius: 24,
//                 offset:     Offset(0, 8),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(children: [
//                 Container(
//                   padding: const EdgeInsets.all(9),
//                   decoration: BoxDecoration(
//                     color:        const Color(0x2EFFFFFF),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Icon(
//                       Icons.account_balance_wallet_rounded,
//                       color: Colors.white, size: 20),
//                 ),
//                 const SizedBox(width: 12),
//                 const Expanded(
//                   child: Text(
//                     'Total Service Charges Collected',
//                     style: TextStyle(
//                       color: Colors.white70,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ]),
//               const SizedBox(height: 22),
//               Text(
//                 '$currency $formatted',
//                 style: const TextStyle(
//                   color:         Colors.white,
//                   fontSize:      38,
//                   fontWeight:    FontWeight.w900,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Row(children: [
//                 Container(
//                   width: 8, height: 8,
//                   decoration: const BoxDecoration(
//                       shape: BoxShape.circle, color: Colors.white),
//                 ),
//                 const SizedBox(width: 6),
//                 const Text(
//                   'Auto-deducted from driver earnings',
//                   style: TextStyle(color: Colors.white60, fontSize: 12),
//                 ),
//               ]),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
//
// // ── TRANSACTION LIST ──────────────────────────────────────────────────────────
// class _TransactionList extends StatelessWidget {
//   const _TransactionList();
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<DatabaseEvent>(
//       stream: FirebaseDatabase.instance
//           .ref()
//           .child('appWallet')
//           .child('transactions')
//           .orderByChild('createdAt')
//           .onValue,
//       builder: (context, snapshot) {
//         // ✅ Loading — plain spinner, no yellow border
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(
//             child: CircularProgressIndicator(
//               color: Color(0xFF00C6A2),
//               strokeWidth: 2,
//             ),
//           );
//         }
//
//         // Empty / error
//         if (snapshot.hasError ||
//             !snapshot.hasData ||
//             snapshot.data!.snapshot.value == null) {
//           return const Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.receipt_long_outlined,
//                     color: Colors.white12, size: 56),
//                 SizedBox(height: 14),
//                 Text('No transactions yet',
//                     style: TextStyle(
//                         color: Colors.white30, fontSize: 14)),
//                 SizedBox(height: 6),
//                 Text(
//                   'Service charges will appear here\nafter rides are completed',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                       color: Colors.white12, fontSize: 12),
//                 ),
//               ],
//             ),
//           );
//         }
//
//         final rawMap = Map<String, dynamic>.from(
//             snapshot.data!.snapshot.value as Map);
//
//         final List<Map<String, dynamic>> txList = rawMap.entries
//             .map((e) => Map<String, dynamic>.from(e.value as Map))
//             .toList()
//           ..sort((a, b) =>
//               (b['createdAt'] as int).compareTo(a['createdAt'] as int));
//
//         return ListView.separated(
//           padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
//           itemCount: txList.length,
//           separatorBuilder: (_, __) =>
//           const Divider(color: Color(0xFF1E2D45), height: 1),
//           itemBuilder: (_, index) =>
//               _TransactionTile(data: txList[index]),
//         );
//       },
//     );
//   }
// }
//
// // ── TRANSACTION TILE ──────────────────────────────────────────────────────────
// class _TransactionTile extends StatelessWidget {
//   final Map<String, dynamic> data;
//   const _TransactionTile({required this.data});
//
//   @override
//   Widget build(BuildContext context) {
//     final double amount   = (data['amount']    ?? 0).toDouble();
//     final String rideId   = (data['rideId']    ?? '-').toString();
//     final String driverId = (data['driverId']  ?? '-').toString();
//     final int    ts       = (data['createdAt'] ?? 0) as int;
//
//     final String dateStr = ts > 0
//         ? DateFormat('dd MMM yyyy  hh:mm a')
//         .format(DateTime.fromMillisecondsSinceEpoch(ts))
//         : '-';
//
//     final String shortRide = rideId.length > 8
//         ? '...${rideId.substring(rideId.length - 8)}'
//         : rideId;
//     final String shortDriver = driverId.length > 8
//         ? '...${driverId.substring(driverId.length - 8)}'
//         : driverId;
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 14),
//       child: Row(children: [
//         Container(
//           width: 46, height: 46,
//           decoration: BoxDecoration(
//             color:        const Color(0x1A00C6A2),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: const Color(0x3300C6A2)),
//           ),
//           child: const Icon(Icons.arrow_downward_rounded,
//               color: Color(0xFF00C6A2), size: 20),
//         ),
//         const SizedBox(width: 14),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Ride  $shortRide',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13.5,
//                   )),
//               const SizedBox(height: 4),
//               Text('Driver $shortDriver',
//                   style: const TextStyle(
//                       color: Colors.white38, fontSize: 12)),
//               const SizedBox(height: 2),
//               Text(dateStr,
//                   style: const TextStyle(
//                       color: Colors.white24, fontSize: 11)),
//             ],
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.symmetric(
//               horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color:        const Color(0x1A00C6A2),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: const Color(0x4D00C6A2)),
//           ),
//           child: Text(
//             '+${NumberFormat('#,##0.00').format(amount)}',
//             style: const TextStyle(
//               color:      Color(0xFF00C6A2),
//               fontWeight: FontWeight.bold,
//               fontSize:   13.5,
//             ),
//           ),
//         ),
//       ]),
//     );
//   }
// }
//
//
//
//
