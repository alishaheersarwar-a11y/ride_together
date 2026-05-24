import 'dart:convert';

class Ride {
  String id;
  String userId;
  String driverName;
  String from;
  String to;
  int availableSeats;

  Ride({
    required this.id,
    required this.userId,
    required this.driverName,
    required this.from,
    required this.to,
    required this.availableSeats,
  });

  // Convert Ride to Map for JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'driverName': driverName,
      'from': from,
      'to': to,
      'availableSeats': availableSeats,
    };
  }

  // Create Ride from Map
  factory Ride.fromMap(Map<String, dynamic> map) {
    return Ride(
      id: map['id'],
      userId: map['userId'],
      driverName: map['driverName'],
      from: map['from'],
      to: map['to'],
      availableSeats: map['availableSeats'],
    );
  }

  String toJson() => json.encode(toMap());
  factory Ride.fromJson(String source) => Ride.fromMap(json.decode(source));
}