import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/theme.dart';
import '../models/activity.dart';
import 'route_path.dart';

const double _osmTileSize = 256.0;
const double _mercatorLatLimit = 85.05112878;

@visibleForTesting
double lngToTileX(double lng, int z) => (lng + 180.0) / 360.0 * (1 << z);

@visibleForTesting
double latToTileY(double lat, int z) {
  final clamped = lat.clamp(-_mercatorLatLimit, _mercatorLatLimit);
  final rad = clamped * pi / 180.0;
  return (1.0 - log(tan(rad) + 1.0 / cos(rad)) / pi) / 2.0 * (1 << z);
}

/// Chooses the highest integer zoom that keeps every point of the geographic
/// bounds inside [viewport]. It is used for any route length, so a track is
/// never clipped at a fixed number of kilometres.
@visibleForTesting
int fitZoomForTrackBounds({
  required double minLat,
  required double maxLat,
  required double minLng,
  required double maxLng,
  required Size viewport,
  double padding = 38.0,
}) {
  final availableW = max(40.0, viewport.width - padding * 2);
  final availableH = max(40.0, viewport.height - padding * 2);

  for (var z = 18; z >= 2; z--) {
    final spanX =
        (lngToTileX(maxLng, z) - lngToTileX(minLng, z)).abs() * _osmTileSize;
    final spanY =
        (latToTileY(minLat, z) - latToTileY(maxLat, z)).abs() * _osmTileSize;
    if (spanX <= availableW && spanY <= availableH) return z;
  }
  return 2;
}

// ─── OSM Tile Cache ───────────────────────────────────────────────────────────
//
// Tiles are stored in <cacheDir>/osm_tiles/z/x/y.png.
// A tile older than 30 days is re-fetched; valid tiles load from disk instantly.
// This makes the last-viewed map area available fully offline.
//
// Public API used by other screens:
//   OsmTileCache.cacheSize()   → int bytes used
//   OsmTileCache.purgeExpired() → deletes tiles older than 30 days

class OsmTileCache {
  static const int _maxAgeDays = 30;
  static const String _userAgent = 'RuchaFitnessApp/1.0';
  static Directory? _cacheDir;

  static Future<Directory> _dir() async {
    if (_cacheDir != null) return _cacheDir!;
    try {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}/osm_tiles');
      await dir.create(recursive: true);
      _cacheDir = dir;
      return dir;
    } catch (_) {
      // Fallback to support directory if cache directory fails
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/osm_tiles');
      await dir.create(recursive: true);
      _cacheDir = dir;
      return dir;
    }
  }

  static String _tilePath(Directory dir, int z, int x, int y) =>
      '${dir.path}/$z/$x/$y.png';

  static Future<Uint8List?> get(int z, int x, int y) async {
    // Try disk cache first
    try {
      final dir = await _dir();
      final file = File(_tilePath(dir, z, x, y));
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age.inDays < _maxAgeDays) {
          return await file.readAsBytes();
        }
      }
    } catch (_) {}

    // Fetch from network — try up to 2 times
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          // Save to disk cache (best-effort)
          try {
            final dir = await _dir();
            await File(_tilePath(dir, z, x, y)).parent.create(recursive: true);
            await File(_tilePath(dir, z, x, y)).writeAsBytes(res.bodyBytes);
          } catch (_) {}
          return res.bodyBytes;
        }
      } catch (_) {
        if (attempt == 0) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  /// Pre-fetch a tile in the background without awaiting.
  static void prefetch(int z, int x, int y) {
    get(z, x, y); // fire and forget
  }

  /// Remove all cached tiles older than [_maxAgeDays]. Called from Settings.
  static Future<void> purgeExpired() async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(const Duration(days: _maxAgeDays));
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        }
      }
    } catch (_) {}
  }

  /// Total bytes used by the tile cache. Shown in the Settings screen.
  static Future<int> cacheSize() async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}

// ─── Cached tile widget ───────────────────────────────────────────────────────

class _CachedTile extends StatefulWidget {
  final int z, x, y;
  final bool darkMode;
  const _CachedTile(
      {required this.z,
      required this.x,
      required this.y,
      required this.darkMode});

  @override
  State<_CachedTile> createState() => _CachedTileState();
}

class _CachedTileState extends State<_CachedTile> {
  Uint8List? _bytes;
  bool _failed = false;
  int _retries = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CachedTile old) {
    super.didUpdateWidget(old);
    if (old.z != widget.z || old.x != widget.x || old.y != widget.y) {
      _retryTimer?.cancel();
      setState(() {
        _bytes = null;
        _failed = false;
        _retries = 0;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await OsmTileCache.get(widget.z, widget.x, widget.y);
    if (!mounted) return;
    if (bytes != null) {
      setState(() {
        _bytes = bytes;
        _failed = false;
      });
      return;
    }
    // Failed — retry up to 4 times with increasing delays
    if (_retries < 4) {
      _retries++;
      final delay = Duration(seconds: _retries * 3);
      _retryTimer = Timer(delay, () {
        if (mounted) _load();
      });
    } else {
      setState(() {
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      final img =
          Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
      if (!widget.darkMode) return img;
      return ColorFiltered(
          colorFilter: _OsmMapWidgetState.darkFilter, child: img);
    }
    // Show a subtle grid placeholder while loading or after failure
    return CustomPaint(
      painter: _TilePlaceholderPainter(failed: _failed),
    );
  }
}

/// Draws a subtle grid that looks like an unloaded map tile.
/// Much more informative than a solid dark rectangle.
class _TilePlaceholderPainter extends CustomPainter {
  final bool failed;
  const _TilePlaceholderPainter({required this.failed});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = failed ? const Color(0xFF0F1520) : const Color(0xFF111827);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final linePaint = Paint()
      ..color = failed ? const Color(0xFF1A2235) : const Color(0xFF1C2740)
      ..strokeWidth = 0.5;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_TilePlaceholderPainter old) => old.failed != failed;
}

class OsmMapMarker {
  final double lat;
  final double lng;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const OsmMapMarker({
    required this.lat,
    required this.lng,
    this.color = RuchaTheme.accentCoral,
    this.label = '',
    this.selected = false,
    this.onTap,
  });
}

class OsmMapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final int initialZoom;
  final List<TrackPoint> track;
  final Color routeColor;
  final bool isInteractive;
  final bool isDarkMode;
  final TrackPoint? currentPosition;
  final List<OsmMapMarker> markers;

  /// When a track is present, keep the entire route inside the viewport by
  /// choosing a zoom that fits every recorded point. Long runs and rides are
  /// therefore never visually cut off at a fixed distance.
  final bool autoFitTrack;

  /// When true, caps the tile zoom to 14 (fewer tiles, less data) and skips
  /// fetching tiles more than 2 zoom levels below the current view.
  final bool dataSaver;

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
    this.markers = const [],
    this.autoFitTrack = true,
    this.dataSaver = false,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late double _centerLat;
  late double _centerLng;
  late double _zoom;
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;
  Size _viewportSize = Size.zero;
  bool _userAdjusted = false;
  bool _fitScheduled = false;

  static const double tileSize = 256.0;

  // Dark mode color matrix — inverts and desaturates OSM tiles to dark slate.
  // Values tuned to keep roads readable while matching the RUCHA dark theme.
  static const ColorFilter darkFilter = ColorFilter.matrix([
    -0.6,
    0.0,
    0.0,
    0.0,
    180.0,
    0.0,
    -0.6,
    0.0,
    0.0,
    180.0,
    0.0,
    0.0,
    -0.6,
    0.0,
    180.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
  ]);

  @override
  void initState() {
    super.initState();
    _centerLat = widget.centerLat;
    _centerLng = widget.centerLng;
    _zoom = widget.initialZoom.toDouble();

    // Pulsing ring animation for the live position dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: false);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    if (widget.autoFitTrack && widget.track.length > 1) {
      _scheduleFit();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final last = widget.track.isNotEmpty ? widget.track.last : null;
    final oldLast = oldWidget.track.isNotEmpty ? oldWidget.track.last : null;
    final trackChanged = widget.track.length != oldWidget.track.length ||
        last?.lat != oldLast?.lat ||
        last?.lng != oldLast?.lng;

    if (widget.autoFitTrack && trackChanged && !_userAdjusted) {
      _scheduleFit();
    } else if (!widget.autoFitTrack) {
      // Live recording mode: follow GPS unless user manually panned
      if (!_userAdjusted &&
          widget.currentPosition != null &&
          (oldWidget.currentPosition == null ||
              oldWidget.currentPosition!.lat != widget.currentPosition!.lat ||
              oldWidget.currentPosition!.lng != widget.currentPosition!.lng)) {
        _centerLat = widget.currentPosition!.lat;
        _centerLng = widget.currentPosition!.lng;
        _panOffsetX = 0;
        _panOffsetY = 0;
      } else if (oldWidget.centerLat != widget.centerLat ||
          oldWidget.centerLng != widget.centerLng) {
        _centerLat = widget.centerLat;
        _centerLng = widget.centerLng;
        _panOffsetX = 0;
        _panOffsetY = 0;
      }
    }

    // Always center on first GPS fix (track empty → first point arrives)
    if (widget.track.isEmpty &&
        widget.currentPosition != null &&
        (oldWidget.currentPosition == null ||
            oldWidget.currentPosition!.lat != widget.currentPosition!.lat ||
            oldWidget.currentPosition!.lng != widget.currentPosition!.lng)) {
      // No recorded line yet: keep the preview fix centered.
      _centerLat = widget.currentPosition!.lat;
      _centerLng = widget.currentPosition!.lng;
      _panOffsetX = 0;
      _panOffsetY = 0;
    }
  }

  void _scheduleFit() {
    if (_fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (mounted) _fitTrackToViewport();
    });
  }

  /// Fits every point of the track (not a fixed number of kilometres) inside
  /// the map, with room for the route stroke and its end pins.
  void _fitTrackToViewport() {
    final track = widget.track;
    if (!mounted || track.isEmpty || _viewportSize.isEmpty) return;

    if (track.length == 1) {
      setState(() {
        _centerLat = track.first.lat;
        _centerLng = track.first.lng;
        _zoom = 16;
        _panOffsetX = 0;
        _panOffsetY = 0;
      });
      return;
    }

    var minLat = track.first.lat;
    var maxLat = track.first.lat;
    var minLng = track.first.lng;
    var maxLng = track.first.lng;
    for (final point in track) {
      if (point.lat < minLat) minLat = point.lat;
      if (point.lat > maxLat) maxLat = point.lat;
      if (point.lng < minLng) minLng = point.lng;
      if (point.lng > maxLng) maxLng = point.lng;
    }

    final fitZoom = fitZoomForTrackBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      viewport: _viewportSize,
    );

    setState(() {
      _centerLat = (minLat + maxLat) / 2;
      _centerLng = (minLng + maxLng) / 2;
      _zoom = fitZoom.toDouble();
      _panOffsetX = 0;
      _panOffsetY = 0;
      _userAdjusted = false;
    });
  }

  static double _latToY(double lat, int z) => latToTileY(lat, z);

  static double _lngToX(double lng, int z) => lngToTileX(lng, z);

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
    // Data saver caps tiles at zoom 14 to reduce network usage
    final maxZ = widget.dataSaver ? 14 : 19;
    final z = _zoom.round().clamp(2, maxZ);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewportSize != size) {
          _viewportSize = size;
          if (widget.autoFitTrack &&
              widget.track.length > 1 &&
              !_userAdjusted) {
            _scheduleFit();
          }
        }

        // Calculate visible tile range
        final centerTileX = _lngToX(_centerLng, z);
        final centerTileY = _latToY(_centerLat, z);

        final tilesAcross = (size.width / tileSize).ceil() + 2;
        final tilesDown = (size.height / tileSize).ceil() + 2;

        final minTx =
            (centerTileX - (tilesAcross / 2) - (_panOffsetX / tileSize))
                .floor();
        final maxTx =
            (centerTileX + (tilesAcross / 2) - (_panOffsetX / tileSize)).ceil();
        final minTy =
            (centerTileY - (tilesDown / 2) - (_panOffsetY / tileSize)).floor();
        final maxTy =
            (centerTileY + (tilesDown / 2) - (_panOffsetY / tileSize)).ceil();

        final maxCoord = (1 << z) - 1;

        final List<Widget> tileWidgets = [];

        for (int tx = minTx; tx <= maxTx; tx++) {
          for (int ty = minTy; ty <= maxTy; ty++) {
            if (ty < 0 || ty > maxCoord) continue;
            final wrappedTx =
                ((tx % (maxCoord + 1)) + (maxCoord + 1)) % (maxCoord + 1);

            final left = (size.width / 2) +
                ((tx - centerTileX) * tileSize) +
                _panOffsetX;
            final top = (size.height / 2) +
                ((ty - centerTileY) * tileSize) +
                _panOffsetY;

            tileWidgets.add(
              Positioned(
                left: left,
                top: top,
                width: tileSize,
                height: tileSize,
                child: _CachedTile(
                  z: z,
                  x: wrappedTx,
                  y: ty,
                  darkMode: widget.isDarkMode,
                ),
              ),
            );
          }
        }

        // Pre-fetch a 1-tile border beyond the visible viewport so panning
        // reveals cached tiles instantly instead of waiting for a download.
        for (int tx = minTx - 1; tx <= maxTx + 1; tx++) {
          for (int ty = minTy - 1; ty <= maxTy + 1; ty++) {
            final inView =
                tx >= minTx && tx <= maxTx && ty >= minTy && ty <= maxTy;
            if (inView || ty < 0 || ty > maxCoord) continue;
            final wx =
                ((tx % (maxCoord + 1)) + (maxCoord + 1)) % (maxCoord + 1);
            OsmTileCache.prefetch(z, wx, ty);
          }
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onScaleUpdate: widget.isInteractive
                ? (details) {
                    setState(() {
                      _userAdjusted = true;
                      if (details.scale != 1.0) {
                        _zoom = (_zoom + (details.scale > 1.0 ? 0.08 : -0.08))
                            .clamp(2.0, 18.0);
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
                        isLiveRecording: widget.currentPosition != null,
                      ),
                    ),
                  ),

                // 3. Discovered training-area markers
                ...widget.markers.map((marker) {
                  final pos = _geoToScreen(marker.lat, marker.lng, z, size);
                  if (pos.dx < -60 ||
                      pos.dx > size.width + 60 ||
                      pos.dy < -60 ||
                      pos.dy > size.height + 60) {
                    return const SizedBox.shrink();
                  }
                  final iconSize = marker.selected ? 38.0 : 28.0;
                  return Positioned(
                    left: pos.dx - (iconSize / 2),
                    top: pos.dy - iconSize,
                    child: GestureDetector(
                      onTap: marker.onTap,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (marker.selected && marker.label.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xEE151B26),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: marker.color),
                              ),
                              child: Text(
                                marker.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Icon(
                            Icons.location_on,
                            size: iconSize,
                            color: marker.color,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 5),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // 4. Live Position Marker (Pulsing Dot like Google Maps)
                if (widget.currentPosition != null)
                  _buildLiveMarker(
                    _geoToScreen(widget.currentPosition!.lat,
                        widget.currentPosition!.lng, z, size),
                  ),

                // 4. Map Controls (Recenter & Zoom)
                if (widget.isInteractive)
                  Positioned(
                    right: 12,
                    bottom: 24,
                    child: Column(
                      children: [
                        _mapControlBtn(Icons.zoom_out_map, () {
                          setState(() => _userAdjusted = false);
                          if (widget.track.isNotEmpty) {
                            _fitTrackToViewport();
                          } else {
                            setState(() {
                              _centerLat = widget.centerLat;
                              _centerLng = widget.centerLng;
                              _panOffsetX = 0;
                              _panOffsetY = 0;
                            });
                          }
                        }),
                        const SizedBox(height: 6),
                        _mapControlBtn(Icons.add, () {
                          setState(() {
                            _userAdjusted = true;
                            _zoom = (_zoom + 1).clamp(2.0, 18.0);
                          });
                        }),
                        const SizedBox(height: 6),
                        _mapControlBtn(Icons.remove, () {
                          setState(() {
                            _userAdjusted = true;
                            _zoom = (_zoom - 1).clamp(2.0, 18.0);
                          });
                        }),
                        const SizedBox(height: 6),
                        _mapControlBtn(Icons.my_location, () {
                          setState(() {
                            _panOffsetX = 0;
                            _panOffsetY = 0;
                            _userAdjusted = false; // resume GPS following
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(
                          fontSize: 8.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600),
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
    // Animated pulsing ring exactly like Google Maps / Strava live dot.
    // The outer ring expands and fades out on each beat.
    return Positioned(
      left: pos.dx - 22,
      top: pos.dy - 22,
      width: 44,
      height: 44,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) {
          final scale = _pulseAnim.value;
          final opacity = (1.0 - scale).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring
              Transform.scale(
                scale: 0.4 + scale * 1.2,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RuchaTheme.accentGreen.withOpacity(opacity * 0.35),
                    border: Border.all(
                      color: RuchaTheme.accentGreen.withOpacity(opacity * 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Static white halo
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
              ),
              // Solid green core
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: RuchaTheme.accentGreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OsmRoutePainter extends CustomPainter {
  final List<TrackPoint> track;
  final Offset Function(double lat, double lng) toScreen;
  final Color routeColor;
  final bool isLiveRecording;

  _OsmRoutePainter({
    required this.track,
    required this.toScreen,
    required this.routeColor,
    this.isLiveRecording = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (track.isEmpty) return;

    final screenPts = <Offset>[];
    for (int i = 0; i < track.length; i++) {
      screenPts.add(toScreen(track[i].lat, track[i].lng));
    }

    final path = buildSmoothRoutePath(screenPts);

    // Strava-style glow route
    drawStravaRoute(canvas, path, routeColor);

    // ── Kilometer markers ────────────────────────────────────────────────────
    // Scan for the first point that crosses each whole-km threshold.
    // We draw a small numbered circle right on the route line.
    int nextKm = 1;
    for (int i = 1; i < track.length; i++) {
      if (track[i].d >= nextKm) {
        final pos = screenPts[i];
        // Skip if off-screen
        if (pos.dx >= -20 &&
            pos.dx <= size.width + 20 &&
            pos.dy >= -20 &&
            pos.dy <= size.height + 20) {
          _drawKmMarker(canvas, pos, nextKm, routeColor);
        }
        nextKm++;
      }
    }

    // Start pin (green circle with white border) + START label.
    final first = screenPts.first;
    canvas.drawCircle(first, 6.5, Paint()..color = RuchaTheme.accentGreen);
    canvas.drawCircle(
      first,
      6.5,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
    _drawLabel(canvas, first, 'START', RuchaTheme.accentGreen);

    // Finish pin shown only for completed routes; live recordings use the
    // animated position dot instead.
    if (screenPts.length > 1 && !isLiveRecording) {
      final last = screenPts.last;
      canvas.drawCircle(last, 6.5, Paint()..color = RuchaTheme.accentCoral);
      canvas.drawCircle(
        last,
        6.5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );
      _drawLabel(canvas, last, 'FINISH', RuchaTheme.accentCoral);
    }
  }

  void _drawKmMarker(Canvas canvas, Offset pos, int km, Color routeColor) {
    const r = 9.0;

    // Filled circle with route color tint
    canvas.drawCircle(
      pos,
      r,
      Paint()..color = const Color(0xFF0D1117),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = routeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Km number text
    final tp = TextPainter(
      text: TextSpan(
        text: '$km',
        style: TextStyle(
          color: routeColor,
          fontSize: km >= 10 ? 7.5 : 9.0,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(
                color: Colors.black87, offset: Offset(0, 0.5), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelX = pos.dx - (textPainter.width / 2);
    final labelY = pos.dy + 10; // Position below the pin

    // Background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - 4,
        labelY - 1,
        textPainter.width + 8,
        textPainter.height + 2,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = color.withOpacity(0.85),
    );

    textPainter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant _OsmRoutePainter oldDelegate) {
    return oldDelegate.track.length != track.length ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.isLiveRecording != isLiveRecording ||
        (track.isNotEmpty &&
            oldDelegate.track.isNotEmpty &&
            (oldDelegate.track.last.lat != track.last.lat ||
                oldDelegate.track.last.lng != track.last.lng));
  }
}
