import 'package:firebase_database/firebase_database.dart';

// ── Service charge config ─────────────────────────────────────────────────────
const double kServiceChargePercent = 15.0; // ← change this anytime
// ─────────────────────────────────────────────────────────────────────────────

class WalletService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Get wallet balance ────────────────────────────────────────────────────
  static Future<double> getBalance(String userId, String role) async {
    final snap = await _db
        .child('wallets')
        .child(role)
        .child(userId)
        .child('balance')
        .get();

    if (snap.exists) {
      return double.tryParse(snap.value.toString()) ?? 0.0;
    }

    // First time: create wallet with default balance
    final double defaultBalance = role == 'passenger' ? 10000.0 : 0.0;
    await _db.child('wallets').child(role).child(userId).set({
      'balance':   defaultBalance,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return defaultBalance;
  }

  // ── Top up wallet ─────────────────────────────────────────────────────────
  static Future<void> topUp({
    required String userId,
    required String role,
    required double amount,
  }) async {
    final current = await getBalance(userId, role);
    await _db
        .child('wallets')
        .child(role)
        .child(userId)
        .child('balance')
        .set(current + amount);

    await _addTransaction(
      userId: userId,
      role:   role,
      title:  'Wallet Top-Up',
      amount: amount,
      type:   'credit',
    );
  }

  // ── Transfer fare: passenger → driver (with service charge) ──────────────
  static Future<Map<String, dynamic>> transferFare({
    required String passengerId,
    required String driverId,
    required double fare,
    required String requestId,
    required String pickup,
    required String destination,
  }) async {

    // ── Calculate service charge & net earning ──────────────────────────────
    final double serviceCharge = double.parse(
        ((fare * kServiceChargePercent) / 100).toStringAsFixed(2));
    final double driverNet =
    double.parse((fare - serviceCharge).toStringAsFixed(2));

    final int now = DateTime.now().millisecondsSinceEpoch;

    // ── 1. Check passenger balance ──────────────────────────────────────────
    final double passengerBalance = await getBalance(passengerId, 'passenger');
    if (passengerBalance < fare) {
      return {'success': false, 'error': 'Insufficient balance'};
    }

    // ── 2. Read current driver & app wallet balances ────────────────────────
    final double driverBalance  = await getBalance(driverId, 'driver');
    final appBalSnap = await _db.child('appWallet').child('balance').get();
    final double appBalance =
    appBalSnap.exists ? double.tryParse(appBalSnap.value.toString()) ?? 0.0 : 0.0;

    // ── 3. Atomic multi-path write ──────────────────────────────────────────
    // All five updates go out in a single RTDB call — either all succeed
    // or all fail. No partial state possible.
    final String passengerTxKey = _db
        .child('wallets').child('passenger').child(passengerId)
        .child('transactions').push().key!;
    final String driverTxKey = _db
        .child('wallets').child('driver').child(driverId)
        .child('transactions').push().key!;
    final String appTxKey =
    _db.child('appWallet').child('transactions').push().key!;

    await _db.update({
      // Passenger — deduct full fare
      'wallets/passenger/$passengerId/balance':
      double.parse((passengerBalance - fare).toStringAsFixed(2)),

      // Passenger transaction log
      'wallets/passenger/$passengerId/transactions/$passengerTxKey': {
        'txId':      passengerTxKey,
        'title':     'Ride Payment',
        'subtitle':  '$pickup → $destination',
        'amount':    fare,
        'type':      'debit',
        'requestId': requestId,
        'timestamp': now,
      },

      // Driver — credit NET earning only (fare minus service charge)
      'wallets/driver/$driverId/balance':
      double.parse((driverBalance + driverNet).toStringAsFixed(2)),

      // Driver transaction log — shows full fare, service charge, and net
      'wallets/driver/$driverId/transactions/$driverTxKey': {
        'txId':          driverTxKey,
        'title':         'Ride Earnings',
        'subtitle':      '$pickup → $destination',
        'amount':        driverNet,        // ← net shown in driver wallet
        'totalFare':     fare,
        'serviceCharge': serviceCharge,
        'type':          'credit',
        'requestId':     requestId,
        'timestamp':     now,
      },

      // App wallet — add service charge
      'appWallet/balance':
      double.parse((appBalance + serviceCharge).toStringAsFixed(2)),
      'appWallet/currency': 'PKR',

      // App wallet transaction log
      'appWallet/transactions/$appTxKey': {
        'rideId':      requestId,
        'driverId':    driverId,
        'passengerId': passengerId,
        'type':        'service_charge_received',
        'amount':      serviceCharge,
        'totalFare':   fare,
        'description':
        'Service charge (${kServiceChargePercent.toInt()}%) — $pickup → $destination',
        'createdAt':   now,
      },

      // Mark ride as paid
      'ride_requests/$requestId/paymentStatus': 'paid',
      'ride_requests/$requestId/paidAt':        now,
      'ride_requests/$requestId/fareBreakdown': {
        'totalFare':            fare,
        'serviceChargePercent': kServiceChargePercent,
        'serviceChargeAmount':  serviceCharge,
        'driverNetEarning':     driverNet,
      },
    });

    debugPrint('✅ Fare transferred');
    debugPrint('   Total fare    : $fare');
    debugPrint('   Service charge: $serviceCharge (${kServiceChargePercent.toInt()}%)');
    debugPrint('   Driver net    : $driverNet');
    debugPrint('   App wallet    : ${appBalance + serviceCharge}');

    return {
      'success':       true,
      'totalFare':     fare,
      'serviceCharge': serviceCharge,
      'driverNet':     driverNet,
    };
  }

  // ── Add transaction log (used by topUp) ───────────────────────────────────
  static Future<void> _addTransaction({
    required String userId,
    required String role,
    required String title,
    String? subtitle,
    required double amount,
    required String type,
    String? requestId,
  }) async {
    final txRef = _db
        .child('wallets')
        .child(role)
        .child(userId)
        .child('transactions')
        .push();

    await txRef.set({
      'txId':      txRef.key,
      'title':     title,
      'subtitle':  subtitle ?? '',
      'amount':    amount,
      'type':      type,
      'requestId': requestId ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── Stream balance (real-time) ────────────────────────────────────────────
  static Stream<double> balanceStream(String userId, String role) {
    return _db
        .child('wallets')
        .child(role)
        .child(userId)
        .child('balance')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      }
      return role == 'passenger' ? 10000.0 : 0.0;
    });
  }

  // ── Stream transactions (real-time) ──────────────────────────────────────
  static Stream<List<Map<String, dynamic>>> transactionsStream(
      String userId, String role) {
    return _db
        .child('wallets')
        .child(role)
        .child(userId)
        .child('transactions')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final data =
      Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> list = data.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      list.sort((a, b) =>
          (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      return list;
    });
  }
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);






// import 'package:firebase_database/firebase_database.dart';
//
// class WalletService {
//   static final DatabaseReference _db = FirebaseDatabase.instance.ref();
//
//   // ── Get wallet balance ──────────────────────────────────────
//   static Future<double> getBalance(String userId, String role) async {
//     // role = 'passenger' or 'driver'
//     final snap =
//     await _db.child('wallets').child(role).child(userId).child('balance').get();
//     if (snap.exists) {
//       return double.tryParse(snap.value.toString()) ?? 0.0;
//     }
//     // First time: create wallet with default balance
//     final double defaultBalance = role == 'passenger' ? 10000.0 : 0.0;
//     await _db
//         .child('wallets')
//         .child(role)
//         .child(userId)
//         .set({'balance': defaultBalance, 'createdAt': DateTime.now().millisecondsSinceEpoch});
//     return defaultBalance;
//   }
//
//   // ── Top up wallet ───────────────────────────────────────────
//   static Future<void> topUp({
//     required String userId,
//     required String role,
//     required double amount,
//   }) async {
//     final current = await getBalance(userId, role);
//     await _db
//         .child('wallets')
//         .child(role)
//         .child(userId)
//         .child('balance')
//         .set(current + amount);
//
//     await _addTransaction(
//       userId: userId,
//       role: role,
//       title: 'Wallet Top-Up',
//       amount: amount,
//       type: 'credit',
//     );
//   }
//
//   // ── Transfer fare: passenger → driver ──────────────────────
//   static Future<Map<String, dynamic>> transferFare({
//     required String passengerId,
//     required String driverId,
//     required double fare,
//     required String requestId,
//     required String pickup,
//     required String destination,
//   }) async {
//     // 1. Check passenger balance
//     final passengerBalance = await getBalance(passengerId, 'passenger');
//     if (passengerBalance < fare) {
//       return {'success': false, 'error': 'Insufficient balance'};
//     }
//
//     // 2. Deduct from passenger
//     await _db
//         .child('wallets')
//         .child('passenger')
//         .child(passengerId)
//         .child('balance')
//         .set(passengerBalance - fare);
//
//     // 3. Credit driver
//     final driverBalance = await getBalance(driverId, 'driver');
//     await _db
//         .child('wallets')
//         .child('driver')
//         .child(driverId)
//         .child('balance')
//         .set(driverBalance + fare);
//
//     // 4. Log transaction for passenger (debit)
//     await _addTransaction(
//       userId: passengerId,
//       role: 'passenger',
//       title: 'Ride Payment',
//       subtitle: '$pickup → $destination',
//       amount: fare,
//       type: 'debit',
//       requestId: requestId,
//     );
//
//     // 5. Log transaction for driver (credit)
//     await _addTransaction(
//       userId: driverId,
//       role: 'driver',
//       title: 'Ride Earnings',
//       subtitle: '$pickup → $destination',
//       amount: fare,
//       type: 'credit',
//       requestId: requestId,
//     );
//
//     // 6. Mark ride request as paid
//     await _db
//         .child('ride_requests')
//         .child(requestId)
//         .update({'paymentStatus': 'paid', 'paidAt': DateTime.now().millisecondsSinceEpoch});
//
//     return {'success': true};
//   }
//
//   // ── Add transaction log ─────────────────────────────────────
//   static Future<void> _addTransaction({
//     required String userId,
//     required String role,
//     required String title,
//     String? subtitle,
//     required double amount,
//     required String type, // 'credit' or 'debit'
//     String? requestId,
//   }) async {
//     final txRef = _db
//         .child('wallets')
//         .child(role)
//         .child(userId)
//         .child('transactions')
//         .push();
//
//     await txRef.set({
//       'txId': txRef.key,
//       'title': title,
//       'subtitle': subtitle ?? '',
//       'amount': amount,
//       'type': type,
//       'requestId': requestId ?? '',
//       'timestamp': DateTime.now().millisecondsSinceEpoch,
//     });
//   }
//
//   // ── Stream balance (real-time) ──────────────────────────────
//   static Stream<double> balanceStream(String userId, String role) {
//     return _db
//         .child('wallets')
//         .child(role)
//         .child(userId)
//         .child('balance')
//         .onValue
//         .map((event) {
//       if (event.snapshot.exists) {
//         return double.tryParse(event.snapshot.value.toString()) ?? 0.0;
//       }
//       return role == 'passenger' ? 10000.0 : 0.0;
//     });
//   }
//
//   // ── Stream transactions (real-time) ────────────────────────
//   static Stream<List<Map<String, dynamic>>> transactionsStream(
//       String userId, String role) {
//     return _db
//         .child('wallets')
//         .child(role)
//         .child(userId)
//         .child('transactions')
//         .onValue
//         .map((event) {
//       if (!event.snapshot.exists) return [];
//       final data = Map<String, dynamic>.from(event.snapshot.value as Map);
//       final List<Map<String, dynamic>> list = data.values
//           .map((v) => Map<String, dynamic>.from(v as Map))
//           .toList();
//       list.sort((a, b) =>
//           (b['timestamp'] as int).compareTo(a['timestamp'] as int));
//       return list;
//     });
//   }
// }