import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Smooth, Uber-style marker animation.
///
/// RTDB delivers a fresh GPS point every ~3 s. Without interpolation the
/// marker would teleport. This helper pushes each new point into an
/// AnimationController and rebuilds the Marker every frame at
/// lerp(prev, next, t) — so the marker glides between updates and rotates
/// to face the direction of travel.
class AnimatedLiveMarker {
  AnimatedLiveMarker({
    required this.markerId,
    required this.icon,
    required this.vsync,
    required this.onUpdate,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _ac = AnimationController(vsync: vsync, duration: duration)
      ..addListener(_emitFrame);
  }

  final MarkerId markerId;
  final BitmapDescriptor icon;
  final TickerProvider vsync;
  final void Function(Marker marker) onUpdate;

  late final AnimationController _ac;
  LatLng? _prev;
  LatLng? _next;
  double _bearing = 0;

  LatLng? get currentPosition {
    if (_prev == null || _next == null) return _next;
    final t = Curves.easeInOut.transform(_ac.value);
    return LatLng(
      _prev!.latitude + (_next!.latitude - _prev!.latitude) * t,
      _prev!.longitude + (_next!.longitude - _prev!.longitude) * t,
    );
  }

  /// Call every time RTDB delivers a fresh (lat, lng) for the tracked party.
  void pushPoint(LatLng p) {
    if (_next != null && _next!.latitude == p.latitude && _next!.longitude == p.longitude) {
      return;
    }
    _prev = currentPosition ?? p;
    _next = p;
    if (_prev!.latitude != _next!.latitude || _prev!.longitude != _next!.longitude) {
      _bearing = _computeBearing(_prev!, _next!);
    }
    _emitFrame();
    _ac.forward(from: 0);
  }

  void _emitFrame() {
    final pos = currentPosition;
    if (pos == null) return;
    onUpdate(Marker(
      markerId: markerId,
      position: pos,
      icon: icon,
      rotation: _bearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    ));
  }

  double _computeBearing(LatLng a, LatLng b) {
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void dispose() => _ac.dispose();
}
