import 'package:cloud_firestore/cloud_firestore.dart';

// ─── CONFIG ──────────────────────────────────────────────────────────────────
const double kServiceChargePercent = 15.0; // Change to your desired percentage
const String kAppWalletDocId = 'app_wallet'; // Single doc in "app_wallet" collection

// ─── MODELS ──────────────────────────────────────────────────────────────────
class FareBreakdown {
  final double totalFare;
  final double serviceChargePercent;
  final double serviceChargeAmount;
  final double driverNetEarning;

  FareBreakdown({
    required this.totalFare,
    required this.serviceChargePercent,
    required this.serviceChargeAmount,
    required this.driverNetEarning,
  });

  Map<String, dynamic> toMap() => {
    'totalFare': totalFare,
    'serviceChargePercent': serviceChargePercent,
    'serviceChargeAmount': serviceChargeAmount,
    'driverNetEarning': driverNetEarning,
  };
}

// ─── SERVICE ─────────────────────────────────────────────────────────────────
class RideCompletionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Call this when a ride is marked as completed.
  /// [rideId]   - Firestore document ID of the ride
  /// [driverId] - Firestore document ID of the driver
  /// [fare]     - Total fare amount paid by the passenger
  Future<FareBreakdown> completeRide({
    required String rideId,
    required String driverId,
    required double fare,
  }) async {
    // Calculate amounts
    final double serviceCharge =
    double.parse(((fare * kServiceChargePercent) / 100).toStringAsFixed(2));
    final double netEarning =
    double.parse((fare - serviceCharge).toStringAsFixed(2));

    final breakdown = FareBreakdown(
      totalFare: fare,
      serviceChargePercent: kServiceChargePercent,
      serviceChargeAmount: serviceCharge,
      driverNetEarning: netEarning,
    );

    // References
    final driverRef = _db.collection('drivers').doc(driverId);
    final rideRef = _db.collection('rides').doc(rideId);
    final appWalletRef = _db.collection('app_wallet').doc(kAppWalletDocId);
    final now = Timestamp.now();

    await _db.runTransaction((transaction) async {
      // ── Read phase (must come before writes) ────────────────────────────
      final driverSnap = await transaction.get(driverRef);
      final appWalletSnap = await transaction.get(appWalletRef);

      if (!driverSnap.exists) {
        throw Exception('Driver $driverId not found.');
      }

      final double currentDriverBalance =
      (driverSnap.data()?['walletBalance'] ?? 0).toDouble();
      final double currentAppBalance =
      (appWalletSnap.exists
          ? (appWalletSnap.data()?['balance'] ?? 0)
          : 0)
          .toDouble();

      final double newDriverBalance =
      double.parse((currentDriverBalance + netEarning).toStringAsFixed(2));
      final double newAppBalance =
      double.parse((currentAppBalance + serviceCharge).toStringAsFixed(2));

      // ── Write phase ──────────────────────────────────────────────────────

      // 1. Update driver wallet balance (net earning only)
      transaction.update(driverRef, {
        'walletBalance': newDriverBalance,
        'updatedAt': now,
      });

      // 2. Log driver earning transaction
      final driverEarningRef =
      driverRef.collection('transactions').doc();
      transaction.set(driverEarningRef, {
        'rideId': rideId,
        'type': 'ride_earning',
        'amount': fare,
        'description': 'Fare earned for ride $rideId',
        'createdAt': now,
      });

      // 3. Log driver service charge deduction transaction
      final driverDeductRef =
      driverRef.collection('transactions').doc();
      transaction.set(driverDeductRef, {
        'rideId': rideId,
        'type': 'service_charge',
        'amount': -serviceCharge,
        'description':
        'Service charge (${kServiceChargePercent.toInt()}%) for ride $rideId',
        'createdAt': now,
      });

      // 4. Update app wallet balance
      if (appWalletSnap.exists) {
        transaction.update(appWalletRef, {
          'balance': newAppBalance,
          'updatedAt': now,
        });
      } else {
        // Create app wallet doc if it doesn't exist yet
        transaction.set(appWalletRef, {
          'balance': newAppBalance,
          'currency': 'PKR', // Change to your currency
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // 5. Log app wallet incoming transaction
      final appWalletTxRef =
      _db.collection('app_wallet_transactions').doc();
      transaction.set(appWalletTxRef, {
        'rideId': rideId,
        'driverId': driverId,
        'type': 'service_charge_received',
        'amount': serviceCharge,
        'description':
        'Service charge (${kServiceChargePercent.toInt()}%) from driver $driverId for ride $rideId',
        'createdAt': now,
      });

      // 6. Update ride document with full fare breakdown
      transaction.update(rideRef, {
        'status': 'completed',
        'fareBreakdown': breakdown.toMap(),
        'paymentProcessedAt': now,
      });
    });

    return breakdown;
  }
}