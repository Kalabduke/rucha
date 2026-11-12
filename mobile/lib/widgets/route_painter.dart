import 'dart:math';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../core/theme.dart';
import 'route_path.dart';

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
    final primaryColor = routeColor ??
        (isRide ? const Color(0xFF00E676) : const Color(0xFFFC4C02));

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
      final y = size.height -
          (offsetY + (pt.lat - minLat) * scale); // Invert Y for screen
      return Offset(x, y);
    }

    final screenPoints = points.map(toOffset).toList();
    final path = buildSmoothRoutePath(screenPoints);

    // Strava-style glow route on the card
    drawStravaRoute(canvas, path, primaryColor, strokeWidth: 4.6);

    if (showPoints) {
      final startPt = screenPoints.first;
      final finishPt = screenPoints.last;

      // Start marker (green with a white ring).
      canvas.drawCircle(startPt, 8.0, Paint()..color = Colors.black26);
      canvas.drawCircle(startPt, 7.0, Paint()..color = Colors.white);
      canvas.drawCircle(startPt, 5.0, Paint()..color = const Color(0xFF00C853));

      // Finish marker (red with a white ring).
      canvas.drawCircle(finishPt, 8.0, Paint()..color = Colors.black26);
      canvas.drawCircle(finishPt, 7.0, Paint()..color = Colors.white);
      canvas.drawCircle(
          finishPt, 5.0, Paint()..color = const Color(0xFFFF1744));
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.activityType != activityType;
  }
}
