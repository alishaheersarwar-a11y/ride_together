import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride_model.dart';
import 'dart:convert';

class RideService {
  static const String _storageKey = 'rides_list';

  // 1. SAVE RIDE (Driver Setup)
  Future<void> saveRide(Ride ride) async {
    final prefs = await SharedPreferences.getInstance();
    List<Ride> rides = await getAllRides();
    rides.add(ride);

    List<String> rideStrings = rides.map((e) => e.toJson()).toList();
    await prefs.setStringList(_storageKey, rideStrings);
  }

  // 2. FETCH ALL RIDES (Passenger Fetching)
  Future<List<Ride>> getAllRides() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? rideStrings = prefs.getStringList(_storageKey);

    if (rideStrings == null) return [];
    return rideStrings.map((e) => Ride.fromJson(e)).toList();
  }

  // 3. SEARCH LOGIC
  Future<List<Ride>> searchRides(String query) async {
    List<Ride> allRides = await getAllRides();
    if (query.isEmpty) return allRides;

    return allRides.where((ride) {
      final from = ride.from.toLowerCase();
      final to = ride.to.toLowerCase();
      final search = query.toLowerCase();
      return from.contains(search) || to.contains(search);
    }).toList();
  }

  // 4. SEAT MANAGEMENT (Booking)
  Future<bool> bookRide(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    List<Ride> rides = await getAllRides();

    int index = rides.indexWhere((r) => r.id == rideId);
    if (index != -1) {
      if (rides[index].availableSeats > 1) {
        // Decrement seat
        rides[index].availableSeats -= 1;
      } else {
        // Remove ride if seats are 0
        rides.removeAt(index);
      }

      // Update Storage
      List<String> rideStrings = rides.map((e) => e.toJson()).toList();
      await prefs.setStringList(_storageKey, rideStrings);
      return true;
    }
    return false;
  }
}