import 'dart:math';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../core/theme.dart';

class RoutePainter extends CustomPainter {
  final List<TrackPoint> points;
  final Color routeColor;
  final bool showPoints;

  RoutePainter({
    required this.points,
    this.routeColor = RuchaTheme.accentCoral,
    this.showPoints = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final center = Offset(size.width / 2, size.height / 2);
      final p = Paint()
        ..color = RuchaTheme.surface2
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8, p);
      return;
    }

    if (points.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      final p = Paint()
        ..color = routeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 6, p);
      return;
    }

    // Compute bounding box
    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLng = points.first.lng;
    double maxLng = points.first.lng;

    for (final pt in points) {
      if (pt.lat < minLat) minLat = pt.lat;
      if (pt.lat > maxLat) maxLat = pt.lat;
      if (pt.lng < minLng) minLng = pt.lng;
      if (pt.lng > maxLng) maxLng = pt.lng;
    }

    final dLat = max(0.0005, maxLat - minLat);
    final dLng = max(0.0005, maxLng - minLng);

    const padding = 24.0;
    final drawW = size.width - (padding * 2);
    final drawH = size.height - (padding * 2);

    final scale = min(drawW / dLng, drawH / dLat);
    final offsetX = padding + (drawW - (dLng * scale)) / 2;
    final offsetY = padding + (drawH - (dLat * scale)) / 2;

    Offset toOffset(TrackPoint pt) {
      final x = offsetX + (pt.lng - minLng) * scale;
      final y = size.height - (offsetY + (pt.lat - minLat) * scale); // Invert Y for screen
      return Offset(x, y);
    }

    final path = Path();
    final first = toOffset(points.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < points.length; i++) {
      final off = toOffset(points[i]);
      path.lineTo(off.dx, off.dy);
    }

    // Glow effect
    final glowPaint = Paint()
      ..color = routeColor.withOpacity(0.35)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glowPaint);

    // Primary route line
    final linePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    if (showPoints) {
      // Start pin (green)
      final startPaint = Paint()
        ..color = RuchaTheme.accentGreen
        ..style = PaintingStyle.fill;
      canvas.drawCircle(first, 6.0, startPaint);

      // Finish pin (red/gold)
      final last = toOffset(points.last);
      final finishPaint = Paint()
        ..color = RuchaTheme.accentGold
        ..style = PaintingStyle.fill;
      canvas.drawCircle(last, 6.0, finishPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points.length != points.length || oldDelegate.routeColor != routeColor;
  }
}
