import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates marker BitmapDescriptors at runtime via Canvas, so we don't
/// need to ship PNG assets. The canvas approach also gives us crisp icons
/// at any device pixel ratio.
class MarkerIcons {
  static BitmapDescriptor? _carIcon;
  static BitmapDescriptor? _personIcon;

  static Future<BitmapDescriptor> car() async {
    return _carIcon ??= await _drawCarIcon();
  }

  static Future<BitmapDescriptor> person() async {
    return _personIcon ??= await _drawPersonIcon();
  }

  static Future<BitmapDescriptor> _drawCarIcon() async {
    const double size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Outer halo
    final haloPaint = Paint()..color = const Color(0x3300D4FF);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, haloPaint);

    // Rounded square body — points "up" so rotation aligns with bearing.
    final bodyRect = RRect.fromLTRBR(
      size * 0.28, size * 0.18, size * 0.72, size * 0.82,
      const Radius.circular(10),
    );
    final bodyPaint = Paint()..color = const Color(0xFF00FFB3);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Direction arrow on top
    final arrowPath = Path()
      ..moveTo(size / 2, size * 0.06)
      ..lineTo(size * 0.38, size * 0.24)
      ..lineTo(size * 0.62, size * 0.24)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF00FFB3));

    // Windshield slot
    final glassRect = RRect.fromLTRBR(
      size * 0.34, size * 0.30, size * 0.66, size * 0.50,
      const Radius.circular(4),
    );
    canvas.drawRRect(glassRect, Paint()..color = const Color(0xFF1A1A2E));

    // Body outline
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 3;
    canvas.drawRRect(bodyRect, outline);

    return _renderToBitmap(recorder, size.toInt());
  }

  static Future<BitmapDescriptor> _drawPersonIcon() async {
    const double size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Halo
    final haloPaint = Paint()..color = const Color(0x33FF6B6B);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, haloPaint);

    // Body circle
    final bodyPaint = Paint()..color = const Color(0xFFFF6B6B);
    canvas.drawCircle(const Offset(size / 2, size / 2), size * 0.32, bodyPaint);

    // Outline
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(size / 2, size / 2), size * 0.32, outline);

    // Person glyph (head + shoulders)
    final glyph = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size * 0.42), size * 0.10, glyph);
    final shoulders = Path()
      ..moveTo(size * 0.32, size * 0.66)
      ..quadraticBezierTo(size / 2, size * 0.50, size * 0.68, size * 0.66)
      ..lineTo(size * 0.62, size * 0.70)
      ..quadraticBezierTo(size / 2, size * 0.58, size * 0.38, size * 0.70)
      ..close();
    canvas.drawPath(shoulders, glyph);

    return _renderToBitmap(recorder, size.toInt());
  }

  static Future<BitmapDescriptor> _renderToBitmap(
    ui.PictureRecorder recorder,
    int size,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      Uint8List.view(bytes!.buffer),
      width: size.toDouble(),
    );
  }
}
