import 'dart:math';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../core/theme.dart';

class OsmMapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final int initialZoom;
  final List<TrackPoint> track;
  final Color routeColor;
  final bool isInteractive;
  final bool isDarkMode;
  final TrackPoint? currentPosition;

  const OsmMapWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.initialZoom = 15,
    this.track = const [],
    this.routeColor = RuchaTheme.accentCoral,
    this.isInteractive = true,
    this.isDarkMode = true,
    this.currentPosition,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> {
  late double _centerLat;
  late double _centerLng;
  late double _zoom;
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;

  static const double tileSize = 256.0;

  // Dark mode color matrix for OpenStreetMap tiles to match RUCHA aesthetic
  static const ColorFilter darkFilter = ColorFilter.matrix([
    -0.80, 0.0, 0.0, 0.0, 240.0,
    0.0, -0.80, 0.0, 0.0, 240.0,
    0.0, -0.80, 0.0, 0.0, 240.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ]);

  @override
  void initState() {
    super.initState();
    _centerLat = widget.centerLat;
    _centerLng = widget.centerLng;
    _zoom = widget.initialZoom.toDouble();
  }

  @override
  void didUpdateWidget(covariant OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != null &&
        (oldWidget.currentPosition == null ||
            oldWidget.currentPosition!.lat != widget.currentPosition!.lat ||
            oldWidget.currentPosition!.lng != widget.currentPosition!.lng)) {
      _centerLat = widget.currentPosition!.lat;
      _centerLng = widget.currentPosition!.lng;
      _panOffsetX = 0;
      _panOffsetY = 0;
    } else if (oldWidget.centerLat != widget.centerLat || oldWidget.centerLng != widget.centerLng) {
      _centerLat = widget.centerLat;
      _centerLng = widget.centerLng;
      _panOffsetX = 0;
      _panOffsetY = 0;
    }
  }

  static double _latToY(double lat, int z) {
    final rad = lat * pi / 180.0;
    return (1.0 - log(tan(rad) + 1.0 / cos(rad)) / pi) / 2.0 * (1 << z);
  }

  static double _lngToX(double lng, int z) {
    return (lng + 180.0) / 360.0 * (1 << z);
  }

  Offset _geoToScreen(double lat, double lng, int z, Size size) {
    final centerX = _lngToX(_centerLng, z) * tileSize;
    final centerY = _latToY(_centerLat, z) * tileSize;

    final ptX = _lngToX(lng, z) * tileSize;
    final ptY = _latToY(lat, z) * tileSize;

    final screenX = (size.width / 2) + (ptX - centerX) + _panOffsetX;
    final screenY = (size.height / 2) + (ptY - centerY) + _panOffsetY;

    return Offset(screenX, screenY);
  }

  @override
  Widget build(BuildContext context) {
    final z = _zoom.round().clamp(2, 19);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Calculate visible tile range
        final centerTileX = _lngToX(_centerLng, z);
        final centerTileY = _latToY(_centerLat, z);

        final tilesAcross = (size.width / tileSize).ceil() + 2;
        final tilesDown = (size.height / tileSize).ceil() + 2;

        final minTx = (centerTileX - (tilesAcross / 2) - (_panOffsetX / tileSize)).floor();
        final maxTx = (centerTileX + (tilesAcross / 2) - (_panOffsetX / tileSize)).ceil();
        final minTy = (centerTileY - (tilesDown / 2) - (_panOffsetY / tileSize)).floor();
        final maxTy = (centerTileY + (tilesDown / 2) - (_panOffsetY / tileSize)).ceil();

        final maxCoord = (1 << z) - 1;

        final List<Widget> tileWidgets = [];

        for (int tx = minTx; tx <= maxTx; tx++) {
          for (int ty = minTy; ty <= maxTy; ty++) {
            if (ty < 0 || ty > maxCoord) continue;
            final wrappedTx = ((tx % (maxCoord + 1)) + (maxCoord + 1)) % (maxCoord + 1);

            final left = (size.width / 2) + ((tx - centerTileX) * tileSize) + _panOffsetX;
            final top = (size.height / 2) + ((ty - centerTileY) * tileSize) + _panOffsetY;

            final tileUrl = 'https://tile.openstreetmap.org/$z/$wrappedTx/$ty.png';

            tileWidgets.add(
              Positioned(
                left: left,
                top: top,
                width: tileSize,
                height: tileSize,
                child: widget.isDarkMode
                    ? ColorFiltered(
                        colorFilter: darkFilter,
                        child: Image.network(
                          tileUrl,
                          fit: BoxFit.cover,
                          headers: const {'User-Agent': 'RuchaFitnessApp/1.0'},
                          errorBuilder: (_, __, ___) => Container(
                            color: RuchaTheme.surface,
                            child: const Center(
                              child: Icon(Icons.map_outlined, color: RuchaTheme.border, size: 24),
                            ),
                          ),
                        ),
                      )
                    : Image.network(
                        tileUrl,
                        fit: BoxFit.cover,
                        headers: const {'User-Agent': 'RuchaFitnessApp/1.0'},
                        errorBuilder: (_, __, ___) => Container(
                          color: RuchaTheme.surface,
                        ),
                      ),
              ),
            );
          }
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onScaleUpdate: widget.isInteractive
                ? (details) {
                    setState(() {
                      if (details.scale != 1.0) {
                        _zoom = (_zoom + (details.scale > 1.0 ? 0.08 : -0.08)).clamp(10.0, 18.0);
                      } else {
                        _panOffsetX += details.focalPointDelta.dx;
                        _panOffsetY += details.focalPointDelta.dy;
                      }
                    });
                  }
                : null,
            child: Stack(
              children: [
                // 1. OpenStreetMap Raster Tiles
                ...tileWidgets,

                // 2. Custom Route Polyline Overlay
                if (widget.track.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OsmRoutePainter(
                        track: widget.track,
                        toScreen: (lat, lng) => _geoToScreen(lat, lng, z, size),
                        routeColor: widget.routeColor,
                      ),
                    ),
                  ),

                // 3. Live Position Marker (Pulsing Dot)
                if (widget.currentPosition != null)
                  _buildLiveMarker(
                    _geoToScreen(widget.currentPosition!.lat, widget.currentPosition!.lng, z, size),
                  ),

                // 4. Map Controls (Recenter & Zoom)
                if (widget.isInteractive)
                  Positioned(
                    right: 12,
                    bottom: 24,
                    child: Column(
                      children: [
                        _mapControlBtn(Icons.add, () {
                          setState(() => _zoom = (_zoom + 1).clamp(10.0, 18.0));
                        }),
                        const SizedBox(height: 6),
                        _mapControlBtn(Icons.remove, () {
                          setState(() => _zoom = (_zoom - 1).clamp(10.0, 18.0));
                        }),
                        const SizedBox(height: 6),
                        _mapControlBtn(Icons.my_location, () {
                          setState(() {
                            _panOffsetX = 0;
                            _panOffsetY = 0;
                            if (widget.currentPosition != null) {
                              _centerLat = widget.currentPosition!.lat;
                              _centerLng = widget.currentPosition!.lng;
                            } else {
                              _centerLat = widget.centerLat;
                              _centerLng = widget.centerLng;
                            }
                          });
                        }),
                      ],
                    ),
                  ),

                // 5. OpenStreetMap Attribution
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 8.5, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mapControlBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: RuchaTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RuchaTheme.border),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: RuchaTheme.textPrimary),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildLiveMarker(Offset pos) {
    return Positioned(
      left: pos.dx - 10,
      top: pos.dy - 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: RuchaTheme.accentGreen.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: RuchaTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _OsmRoutePainter extends CustomPainter {
  final List<TrackPoint> track;
  final Offset Function(double lat, double lng) toScreen;
  final Color routeColor;

  _OsmRoutePainter({
    required this.track,
    required this.toScreen,
    required this.routeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (track.isEmpty) return;

    final path = Path();
    final first = toScreen(track.first.lat, track.first.lng);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < track.length; i++) {
      final off = toScreen(track[i].lat, track[i].lng);
      path.lineTo(off.dx, off.dy);
    }

    // Outer Glow
    final glowPaint = Paint()
      ..color = routeColor.withOpacity(0.3)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glowPaint);

    // Polyline
    final linePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Green Start Pin
    final startPaint = Paint()
      ..color = RuchaTheme.accentGreen
      ..style = PaintingStyle.fill;
    canvas.drawCircle(first, 5.5, startPaint);

    // Red/Gold Finish Pin
    if (track.length > 1) {
      final last = toScreen(track.last.lat, track.last.lng);
      final finishPaint = Paint()
        ..color = RuchaTheme.accentGold
        ..style = PaintingStyle.fill;
      canvas.drawCircle(last, 5.5, finishPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OsmRoutePainter oldDelegate) => true;
}
