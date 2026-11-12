import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/activity.dart';
import '../models/legend_ghost.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/route_painter.dart';
import '../services/media_share_service.dart';

enum CardThemeStyle { sunset, midnight, ember, highland }

// Preset route colours the user can pick for the drawn path on the card
const List<Color> _routeColorPresets = [
  Color(0xFFFC4C02), // Strava orange
  Color(0xFF00E676), // RUCHA green
  Color(0xFFF2B705), // Gold
  Color(0xFFFF1744), // Red
  Color(0xFF40C4FF), // Sky blue
  Color(0xFFE040FB), // Purple
  Color(0xFFFFFFFF), // White
];

class RunCardScreen extends StatefulWidget {
  final Activity activity;
  final LegendGhost? ghostLegend;

  const RunCardScreen({super.key, required this.activity, this.ghostLegend});

  @override
  State<RunCardScreen> createState() => _RunCardScreenState();
}

class _RunCardScreenState extends State<RunCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  CardThemeStyle _currentStyle = CardThemeStyle.sunset;
  String? _customPhotoPath;
  bool _isExporting = false;

  // Background blur — 0.0 = no blur, 20.0 = heavily blurred
  double _blurAmount = 8.0;

  // Route / path colour on the card
  Color _routeColor = _routeColorPresets[0];

  bool get _isRide => widget.activity.type.toLowerCase() == 'ride';

  @override
  void initState() {
    super.initState();
    // Default route colour by activity type
    _routeColor = _isRide ? const Color(0xFF00E676) : const Color(0xFFFC4C02);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: Row(
            children: [
              Expanded(
                  child: Container(height: 2.5, color: RuchaTheme.accentGreen)),
              Expanded(
                  child: Container(height: 2.5, color: RuchaTheme.accentGold)),
              Expanded(
                  child: Container(height: 2.5, color: RuchaTheme.accentRed)),
            ],
          ),
        ),
        title: Text(_isRide ? 'Ride Card Studio' : 'Run Card Studio'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.share),
            tooltip: 'Share Card',
            onPressed: _isExporting ? null : _shareCard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Background panel ─────────────────────────────────────────
            _panel(
              icon: CupertinoIcons.photo_camera_solid,
              iconColor: RuchaTheme.accentGold,
              title: 'Card Background',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera / Photos / Clear row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openCamera,
                          icon: const Icon(CupertinoIcons.camera_fill,
                              size: 16, color: RuchaTheme.accentGreen),
                          label: const Text('Camera',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: _customPhotoPath != null
                                  ? RuchaTheme.accentGreen
                                  : RuchaTheme.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromPhotos,
                          icon: const Icon(
                              CupertinoIcons.photo_fill_on_rectangle_fill,
                              size: 16,
                              color: RuchaTheme.accentGold),
                          label: const Text('Photos',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: _customPhotoPath != null
                                  ? RuchaTheme.accentGold
                                  : RuchaTheme.border,
                            ),
                          ),
                        ),
                      ),
                      if (_customPhotoPath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid,
                              color: RuchaTheme.accentRed, size: 22),
                          tooltip: 'Remove Custom Photo',
                          onPressed: () =>
                              setState(() => _customPhotoPath = null),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Gradient presets (shown when no photo is selected)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _styleChip('Sunset Flame', CardThemeStyle.sunset,
                            const Color(0xFFFF7A42)),
                        const SizedBox(width: 8),
                        _styleChip('Midnight Run', CardThemeStyle.midnight,
                            const Color(0xFF5FD6A8)),
                        const SizedBox(width: 8),
                        _styleChip('Ember Glow', CardThemeStyle.ember,
                            const Color(0xFFF2B705)),
                        const SizedBox(width: 8),
                        _styleChip('Highland Peak', CardThemeStyle.highland,
                            const Color(0xFF00C853)),
                      ],
                    ),
                  ),

                  // Blur slider — only visible when a photo is chosen
                  if (_customPhotoPath != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.layers_alt,
                            size: 15, color: RuchaTheme.textSecondary),
                        const SizedBox(width: 8),
                        const Text(
                          'Background Blur',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: RuchaTheme.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          _blurAmount < 1
                              ? 'None'
                              : _blurAmount < 7
                                  ? 'Light'
                                  : _blurAmount < 14
                                      ? 'Medium'
                                      : 'Heavy',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: RuchaTheme.accentGreen),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: RuchaTheme.accentGreen,
                        inactiveTrackColor: RuchaTheme.border,
                        thumbColor: RuchaTheme.accentGreen,
                        overlayColor: RuchaTheme.accentGreen.withOpacity(0.15),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _blurAmount,
                        min: 0.0,
                        max: 20.0,
                        divisions: 20,
                        onChanged: (v) => setState(() => _blurAmount = v),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Route colour panel ────────────────────────────────────────
            _panel(
              icon: CupertinoIcons.paintbrush_fill,
              iconColor: _routeColor,
              title: 'Route Line Colour',
              child: Row(
                children: [
                  for (final c in _routeColorPresets) ...[
                    GestureDetector(
                      onTap: () => setState(() => _routeColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: c == _routeColor ? 36 : 28,
                        height: c == _routeColor ? 36 : 28,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _routeColor
                                ? Colors.white
                                : Colors.white24,
                            width: c == _routeColor ? 2.5 : 1.0,
                          ),
                          boxShadow: c == _routeColor
                              ? [
                                  BoxShadow(
                                      color: c.withOpacity(0.55), blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: c == _routeColor
                            ? const Icon(Icons.check,
                                color: Colors.black87, size: 16)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── The 4:5 card preview ──────────────────────────────────────
            Center(
              child: RepaintBoundary(
                key: _cardKey,
                child: AspectRatio(
                  aspectRatio: 0.8,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient:
                          _customPhotoPath == null ? _getGradient() : null,
                      boxShadow: [
                        BoxShadow(
                          color: _routeColor.withOpacity(0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          // 1. Custom photo with blur
                          if (_customPhotoPath != null &&
                              File(_customPhotoPath!).existsSync()) ...[
                            Positioned.fill(
                              child: Image.file(
                                File(_customPhotoPath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (_blurAmount > 0.5)
                              Positioned.fill(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: _blurAmount,
                                    sigmaY: _blurAmount,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                          ],

                          // 2. Vignette overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(
                                        _customPhotoPath != null ? 0.3 : 0.2),
                                    Colors.black.withOpacity(
                                        _customPhotoPath != null ? 0.60 : 0.6),
                                    Colors.black.withOpacity(
                                        _customPhotoPath != null ? 0.88 : 0.85),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),

                          // 3. GPS route with Strava glow — user-selected colour
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28.0, vertical: 48.0),
                              child: CustomPaint(
                                painter: RoutePainter(
                                  points: widget.activity.track,
                                  routeColor: _routeColor,
                                  activityType: widget.activity.type,
                                  showPoints: true,
                                ),
                              ),
                            ),
                          ),

                          // 4. Text overlay
                          Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top bar
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.6),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.white24),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                  width: 4,
                                                  height: 12,
                                                  color:
                                                      RuchaTheme.accentGreen),
                                              Container(
                                                  width: 4,
                                                  height: 12,
                                                  color: RuchaTheme.accentGold),
                                              Container(
                                                  width: 4,
                                                  height: 12,
                                                  color: RuchaTheme.accentRed),
                                              const SizedBox(width: 8),
                                              Text(
                                                'RUCHA',
                                                style: TextStyle(
                                                  color: _routeColor,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                  letterSpacing: 2.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _isRide
                                                ? '🚴 RIDE'
                                                : widget.activity.type == 'walk'
                                                    ? '🚶 WALK'
                                                    : '🏃 RUN',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        RuchaConstants
                                                .cities[widget.activity.city]
                                                ?.name ??
                                            'Ethiopia',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Bottom stats
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.ghostLegend != null) ...[
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: widget
                                                  .ghostLegend!.accentColor
                                                  .withOpacity(0.6)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(widget.ghostLegend!.icon,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Paced vs ${widget.ghostLegend!.name} (${widget.ghostLegend!.targetPaceFormatted})',
                                              style: TextStyle(
                                                color: widget
                                                    .ghostLegend!.accentColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    Text(
                                      widget.activity.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.08)),
                                      ),
                                      child: Column(
                                        children: [
                                          // Row 1: distance / time / pace-or-speed
                                          Row(
                                            children: [
                                              _cardStat('DISTANCE',
                                                  '${widget.activity.distance.toStringAsFixed(2)} km'),
                                              _cardStatDivider(),
                                              _cardStat(
                                                  'TIME',
                                                  RuchaConstants.formatDuration(
                                                      widget
                                                          .activity.duration)),
                                              _cardStatDivider(),
                                              _cardStat(
                                                _isRide ? 'SPEED' : 'PACE',
                                                _isRide
                                                    ? '${_computeSpeedKmh().toStringAsFixed(1)} km/h'
                                                    : '${RuchaConstants.formatPace(widget.activity.pace)}/km',
                                              ),
                                            ],
                                          ),
                                          // Row 2: elevation + HR (only if present)
                                          if (widget.activity.elevation > 0 ||
                                              (widget.activity.avgHr != null &&
                                                  widget.activity.avgHr! >
                                                      0)) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                _cardStat('+ELEV',
                                                    '+${widget.activity.elevation.round()} m'),
                                                if (widget.activity.avgHr !=
                                                        null &&
                                                    widget.activity.avgHr! >
                                                        0) ...[
                                                  _cardStatDivider(),
                                                  _cardStat('HR',
                                                      '❤️ ${widget.activity.avgHr} bpm'),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _saveToGallery,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(CupertinoIcons.arrow_down_to_line_alt,
                            size: 18),
                    label: const Text('Save to Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RuchaTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _shareCard,
                    icon: const Icon(CupertinoIcons.share, size: 18),
                    label: const Text('Share Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RuchaTheme.accentCoral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Share shortcuts ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RuchaTheme.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'SHARE TO YOUR FAVORITE APPS',
                    style: TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _shareAppButton(
                          label: 'Instagram',
                          icon: CupertinoIcons.camera_circle,
                          color: const Color(0xFFE1306C),
                          onTap: _shareCard),
                      _shareAppButton(
                          label: 'Telegram',
                          icon: CupertinoIcons.paperplane_fill,
                          color: const Color(0xFF0088CC),
                          onTap: _shareCard),
                      _shareAppButton(
                          label: 'WhatsApp',
                          icon: CupertinoIcons.chat_bubble_2_fill,
                          color: const Color(0xFF25D366),
                          onTap: _shareCard),
                      _shareAppButton(
                          label: 'Bluetooth',
                          icon: CupertinoIcons.bluetooth,
                          color: const Color(0xFF0077B5),
                          onTap: _shareCard),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// A consistently styled panel card used for each controls section.
  Widget _panel({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _styleChip(String label, CardThemeStyle style, Color color) {
    final active = _currentStyle == style && _customPhotoPath == null;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: active ? color : RuchaTheme.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() {
        _currentStyle = style;
        _customPhotoPath = null;
      }),
    );
  }

  Widget _shareAppButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Center(child: Icon(icon, color: color, size: 22)),
            ),
            const SizedBox(height: 6),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardStatDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withOpacity(0.12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  double _computeSpeedKmh() {
    if (widget.activity.duration <= 0) return 0.0;
    return widget.activity.distance / (widget.activity.duration / 3600.0);
  }

  LinearGradient _getGradient() {
    switch (_currentStyle) {
      case CardThemeStyle.sunset:
        return const LinearGradient(
          colors: [Color(0xFF2B1006), Color(0xFF130602), Color(0xFF090302)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardThemeStyle.midnight:
        return const LinearGradient(
          colors: [Color(0xFF091F18), Color(0xFF040F0C), Color(0xFF020706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardThemeStyle.ember:
        return const LinearGradient(
          colors: [Color(0xFF2E1A04), Color(0xFF140B01), Color(0xFF070400)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardThemeStyle.highland:
        return const LinearGradient(
          colors: [Color(0xFF022B14), Color(0xFF011409), Color(0xFF000803)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    final path = await MediaShareService.openCamera();
    if (path != null && mounted) {
      setState(() => _customPhotoPath = path);
    }
  }

  Future<void> _pickFromPhotos() async {
    final path = await MediaShareService.pickImageFromPhotos();
    if (path != null && mounted) {
      setState(() => _customPhotoPath = path);
    }
  }

  Future<Uint8List?> _renderCardImage() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to render card: $e');
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _renderCardImage();
      if (bytes != null) {
        final ok = await MediaShareService.saveCardToGallery(bytes: bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok
                  ? '✅ High-res Card saved to Photos & Gallery!'
                  : '⚠️ Could not save to gallery. Check storage permissions.'),
              backgroundColor:
                  ok ? RuchaTheme.accentGreen : RuchaTheme.accentRed,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareCard() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _renderCardImage();
      if (bytes != null) {
        final tempDir = Directory.systemTemp;
        final file = File(
            '${tempDir.path}/rucha_card_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);

        final hrPart = widget.activity.avgHr != null
            ? ' · ❤️ ${widget.activity.avgHr} BPM'
            : '';
        final metricPart = _isRide
            ? '${_computeSpeedKmh().toStringAsFixed(1)} km/h'
            : '${RuchaConstants.formatPace(widget.activity.pace)}/km';

        final caption =
            '${_isRide ? "🚴" : "🏃"} Just completed ${widget.activity.distance.toStringAsFixed(2)} km in ${widget.activity.city.toUpperCase()} with #RUCHA!\n'
            '⏱️ ${RuchaConstants.formatDuration(widget.activity.duration)} · ⚡ $metricPart · ⛰️ +${widget.activity.elevation.round()}m$hrPart\n'
            'Highland Athlete Community · #RUCHA #Strava #Ethiopia';

        await MediaShareService.shareCard(
            filePath: file.path, caption: caption);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
