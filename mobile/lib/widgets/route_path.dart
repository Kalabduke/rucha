import 'package:flutter/material.dart';

/// Builds a smooth path through GPS points using a Catmull-Rom spline
/// converted to cubic Bézier segments. The route follows every recorded GPS
/// fix with smooth curves — identical to how Strava draws routes.
///
/// Each recorded point is a vertex. The spline passes *through* every point,
/// so a turn at km 3.2 appears exactly where you turned, not smoothed away.
Path buildSmoothRoutePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;

  // Deduplicate points that are sub-pixel apart — prevents cubic artefacts.
  final pts = <Offset>[];
  for (final p in points) {
    if (pts.isEmpty || (p - pts.last).distanceSquared > 0.25) {
      pts.add(p);
    }
  }
  if (pts.isEmpty) return path;
  if (pts.length == 1) {
    path.moveTo(pts.first.dx, pts.first.dy);
    return path;
  }

  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 2) {
    path.lineTo(pts[1].dx, pts[1].dy);
    return path;
  }

  for (int i = 0; i < pts.length - 1; i++) {
    final p0 = i == 0 ? pts[i] : pts[i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = i + 2 < pts.length ? pts[i + 2] : p2;

    // Uniform Catmull-Rom → cubic Bézier (tension = 1/6).
    // Lower tension keeps the curve glued to the GPS trace without overshoot.
    final c1 = p1 + (p2 - p0) / 6.0;
    final c2 = p2 - (p3 - p1) / 6.0;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// Draws a Strava-style route onto [canvas] with a soft glow bloom.
///
/// Layers (bottom to top):
///   1. Wide semi-transparent bloom  — the signature "glow" around the route
///   2. Dark casing                   — separates the route from map background
///   3. Coloured main stroke          — the route itself
void drawStravaRoute(
  Canvas canvas,
  Path path,
  Color routeColor, {
  double strokeWidth = 4.2,
}) {
  // 1. Glow bloom — 3 layers fading outward, blurred via multiple passes
  for (int i = 3; i >= 1; i--) {
    final glowPaint = Paint()
      ..color = routeColor.withOpacity(0.07 * i)
      ..strokeWidth = strokeWidth + i * 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 3.0);
    canvas.drawPath(path, glowPaint);
  }

  // 2. Dark casing — thin dark outline so the coloured line reads on any tile
  final casingPaint = Paint()
    ..color = const Color(0xCC0B111A)
    ..strokeWidth = strokeWidth + 3.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  canvas.drawPath(path, casingPaint);

  // 3. Main coloured stroke
  final linePaint = Paint()
    ..color = routeColor
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  canvas.drawPath(path, linePaint);
}
