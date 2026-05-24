import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteResult {
  RouteResult({required this.points, this.distanceText, this.durationText});

  final List<LatLng> points;
  final String? distanceText;
  final String? durationText;
}

/// Wraps flutter_polyline_points to fetch a Directions-API route between two
/// LatLngs. Caches the result so we don't burn quota on every GPS tick.
class RouteService {
  RouteService({this.apiKey});

  final String? apiKey;
  final PolylinePoints _polylinePoints = PolylinePoints();

  LatLng? _lastFetchOrigin;
  LatLng? _lastFetchDestination;
  DateTime _lastFetchAt = DateTime.fromMillisecondsSinceEpoch(0);
  RouteResult? _cached;

  static const _refetchAfterSeconds = 30;
  static const _refetchAfterMeters = 50.0;

  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String googleApiKey,
  }) async {
    if (googleApiKey.isEmpty) return null;

    final now = DateTime.now();
    final originMoved = _lastFetchOrigin == null
        ? true
        : Geolocator.distanceBetween(
              _lastFetchOrigin!.latitude,
              _lastFetchOrigin!.longitude,
              origin.latitude,
              origin.longitude,
            ) >
            _refetchAfterMeters;
    final destMoved = _lastFetchDestination == null
        ? true
        : Geolocator.distanceBetween(
              _lastFetchDestination!.latitude,
              _lastFetchDestination!.longitude,
              destination.latitude,
              destination.longitude,
            ) >
            _refetchAfterMeters;
    final stale = now.difference(_lastFetchAt).inSeconds > _refetchAfterSeconds;

    if (_cached != null && !originMoved && !destMoved && !stale) {
      return _cached;
    }

    try {
      final result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleApiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) {
        return _cached;
      }

      final points = result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);

      final distanceMeters = _routeLengthMeters(points);
      _cached = RouteResult(
        points: points,
        distanceText: _formatDistance(distanceMeters),
        durationText: _estimateDuration(distanceMeters),
      );
      _lastFetchOrigin = origin;
      _lastFetchDestination = destination;
      _lastFetchAt = now;
      return _cached;
    } catch (_) {
      return _cached;
    }
  }

  void clear() {
    _cached = null;
    _lastFetchOrigin = null;
    _lastFetchDestination = null;
    _lastFetchAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _routeLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Rough urban driving speed (~30 km/h ≈ 8.33 m/s). Good enough for the
  // "X min away" label without an extra Directions-API field.
  static String _estimateDuration(double meters) {
    final mins = (meters / 500).round(); // 500 m/min ≈ 30 km/h
    if (mins <= 1) return '1 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}
