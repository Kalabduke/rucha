import 'dart:math';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../core/theme.dart';

class RoutePainter extends CustomPainter {
  final List<TrackPoint> points;
  final Color? routeColor;
  final String activityType; // 'run' or 'ride'
  final bool showPoints;
  final bool isElevationGraded;

  RoutePainter({
    required this.points,
    this.routeColor,
    this.activityType = 'run',
    this.showPoints = true,
    this.isElevationGraded = false,
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

    final isRide = activityType.toLowerCase() == 'ride';
    final primaryColor = routeColor ?? (isRide ? const Color(0xFF00E676) : const Color(0xFFFC4C02));
    final secondaryColor = isRide ? const Color(0xFF00B0FF) : const Color(0xFFFF9100);

    if (points.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      final p = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 7, p);
      return;
    }

    // Compute geographic bounding box
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

    final dLat = max(0.0004, maxLat - minLat);
    final dLng = max(0.0004, maxLng - minLng);

    const padding = 28.0;
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

    final screenPoints = points.map(toOffset).toList();

    final path = Path();
    path.moveTo(screenPoints.first.dx, screenPoints.first.dy);
    for (int i = 1; i < screenPoints.length; i++) {
      path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
    }

    // 1. Strava-Style Dark Drop Shadow / Depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(path, shadowPaint);

    // 2. Strava Vibrant Outer Glow (Emulates PWA app.js line 489: 11px wide glow)
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.withOpacity(0.4), secondaryColor.withOpacity(0.4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 11.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glowPaint);

    // 3. Primary Route Polyline (4.2px vibrant line)
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // 4. Strava High-Contrast Core Highlight (1.4px white highlight)
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, corePaint);

    if (showPoints) {
      final startPt = screenPoints.first;
      final finishPt = screenPoints.last;

      // Start Pin (🟢 Strava Start Marker with white ring)
      canvas.drawCircle(startPt, 8.0, Paint()..color = Colors.black45);
      canvas.drawCircle(startPt, 7.0, Paint()..color = Colors.white);
      canvas.drawCircle(startPt, 5.0, Paint()..color = const Color(0xFF00C853));

      // Finish Pin (🏁 / 🔴 Strava Finish Marker with white ring)
      canvas.drawCircle(finishPt, 8.0, Paint()..color = Colors.black45);
      canvas.drawCircle(finishPt, 7.0, Paint()..color = Colors.white);
      canvas.drawCircle(finishPt, 5.0, Paint()..color = const Color(0xFFFF1744));
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.activityType != activityType;
  }
}
