import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tracking_service.dart';
import '../services/api_service.dart';
import '../services/activity_store.dart';
import '../services/settings_service.dart';
import '../services/smartwatch_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/legend_ghost.dart';
import '../widgets/split_table.dart';
import '../widgets/osm_map_widget.dart';
import 'run_card_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  LegendGhost? _selectedLegend = LegendGhost.all[0];
  int _lastNotifiedSplit = 0;

  // Bottom pill expansion — mirrors GoCycling tap-to-expand
  bool _statsExpanded = true;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<TrackingService>().warmUp());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Route colour per activity ─────────────────────────────────────────────
  Color _routeColor(String type) {
    switch (type) {
      case 'ride':
        return const Color(0xFF00E676);
      case 'walk':
        return const Color(0xFF40C4FF);
      default:
        return const Color(0xFFFC4C02);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final smartwatch = context.watch<SmartwatchService>();
    final settings = context.watch<SettingsService>();
    final isRunning = tracking.status == RecordingStatus.running;
    final isPaused = tracking.status == RecordingStatus.paused;
    final isSearching = tracking.status == RecordingStatus.searching;
    final isIdle = tracking.status == RecordingStatus.idle;
    final isActive = isRunning || isPaused || isSearching;
    final preview = tracking.previewPosition;
    final city = RuchaConstants.cities[tracking.selectedCity] ??
        RuchaConstants.cities['addis']!;
    final accent = _routeColor(tracking.activityType);

    // Sync smartwatch HR
    if (smartwatch.currentBpm > 0 &&
        tracking.currentHr != smartwatch.currentBpm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) tracking.setCurrentHeartRate(smartwatch.currentBpm);
      });
    }

    // Split snackbar
    if (tracking.splits.length > _lastNotifiedSplit &&
        _selectedLegend != null) {
      _lastNotifiedSplit = tracking.splits.length;
      final split = tracking.splits.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(_selectedLegend!.icon,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'KM ${split.km}  ${split.paceFormatted}/km  vs ${_selectedLegend!.name}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: const Color(0xFF151B26),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: _selectedLegend!.accentColor.withOpacity(0.5)),
              ),
            ),
          );
      });
    }

    return Scaffold(
      // ── Full-screen map ───────────────────────────────────────────────────
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Map fills the entire screen
          Positioned.fill(
            child: OsmMapWidget(
              centerLat: preview?.lat ?? city.lat,
              centerLng: preview?.lng ?? city.lng,
              initialZoom: 15,
              track: tracking.track,
              currentPosition: preview,
              routeColor: accent,
              isInteractive: true,
              isDarkMode: true,
              autoFitTrack: false,
              dataSaver: settings.dataSaver,
            ),
          ),

          // 1b. Overlay when no GPS fix yet — shows status to user
          if (preview == null && isIdle)
            Positioned(
              left: 0,
              right: 0,
              bottom: 300, // above the bottom pill
              child: Center(
                child: _buildMapStatusPill(tracking),
              ),
            ),

          // 2. Top-left back button — leaves the screen without stopping tracking
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, left: 6),
                child: GestureDetector(
                  onTap: () {
                    // Pop if pushed onto the navigator stack (e.g. from a shortcut).
                    // If embedded in the IndexedStack, pop has no effect so we
                    // rely on the bottom nav to change tabs — that's by design.
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    // No-op when embedded: tracking keeps running,
                    // user can switch tabs normally via the bottom bar.
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117).withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2b. Bottom-anchored status row — Ride/Searching/Watch pills sit just above the bottom sheet
          Positioned(
            left: 14,
            right: 14,
            bottom: 230, // floats just above the bottom sheet handle
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Activity type / title pill (left)
                  if (isIdle) _activityTypePill(tracking, accent),
                  if (isActive)
                    _frostedPill(
                      child: Text(
                        tracking.activityName.isNotEmpty
                            ? tracking.activityName
                            : '${tracking.activityType[0].toUpperCase()}${tracking.activityType.substring(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // GPS badge
                  _buildGpsBadge(tracking),
                  const SizedBox(width: 8),
                  // HR badge
                  _buildSmartwatchBadge(context, smartwatch),
                ],
              ),
            ),
          ),

          // 3. Corner metric boxes — shown during active recording
          if (isRunning || isPaused)
            _buildCornerMetrics(tracking, smartwatch, accent),

          // 3. Bottom sheet — frosted glass pill (GoCycling style)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPill(context, tracking, smartwatch, isIdle,
                isSearching, isRunning, isPaused, accent, city),
          ),
        ],
      ),
    );
  }

  // ── Map status pill ───────────────────────────────────────────────────────

  Widget _buildMapStatusPill(TrackingService tracking) {
    // Permission blocked — show actionable message
    if (tracking.permissionDenied || tracking.locationServiceDisabled) {
      final msg = tracking.gpsWarning ??
          (tracking.locationServiceDisabled
              ? 'Turn on GPS in device settings'
              : 'Allow location permission for RUCHA');
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xCC0D1117),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RuchaTheme.accentCoral.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded,
                color: RuchaTheme.accentCoral, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                msg,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.35),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Normal loading — tiles fetching
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xAA0D1117),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: RuchaTheme.accentCoral,
            ),
          ),
          SizedBox(width: 9),
          Text(
            'Loading map…',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Corner metric boxes (live recording) ────────────────────────────────

  Widget _buildCornerMetrics(
      TrackingService tracking, SmartwatchService smartwatch, Color accent) {
    final distStr = tracking.track.isNotEmpty
        ? '${tracking.track.last.d.toStringAsFixed(2)} km'
        : '0.00 km';
    final timeStr = RuchaConstants.formatDuration(tracking.elapsedSeconds);
    final paceStr = tracking.smoothedPace > 0
        ? '${RuchaConstants.formatPace(tracking.smoothedPace)}/km'
        : '--:--';
    final hrStr = smartwatch.currentBpm > 0
        ? '${smartwatch.currentBpm} bpm'
        : (tracking.currentHr != null ? '${tracking.currentHr} bpm' : '-- bpm');

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 68, 12, 220),
        child: Stack(
          children: [
            // Top-left: Distance
            Positioned(
              left: 0,
              top: 0,
              child: _cornerBox('DIST', distStr, accent),
            ),
            // Top-right: Time
            Positioned(
              right: 0,
              top: 0,
              child: _cornerBox('TIME', timeStr, Colors.white70),
            ),
            // Bottom-left: Pace
            Positioned(
              left: 0,
              bottom: 0,
              child: _cornerBox('PACE', paceStr, accent),
            ),
            // Bottom-right: HR
            Positioned(
              right: 0,
              bottom: 0,
              child: _cornerBox(
                'HR',
                hrStr,
                smartwatch.currentBpm > 0
                    ? const Color(0xFFFF5252)
                    : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerBox(String label, String value, Color valueColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117).withOpacity(0.72),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Skeleton loader (map loading state) ──────────────────────────────────

  Widget _buildSkeleton() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0D1117),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _shimmerBox(72, 72, radius: 36),
            const SizedBox(height: 16),
            _shimmerBox(120, 14, radius: 7),
            const SizedBox(height: 8),
            _shimmerBox(80, 10, radius: 5),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {double radius = 8}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Bottom pill ──────────────────────────────────────────────────────────

  Widget _buildBottomPill(
    BuildContext context,
    TrackingService tracking,
    SmartwatchService smartwatch,
    bool isIdle,
    bool isSearching,
    bool isRunning,
    bool isPaused,
    Color accent,
    City city,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _statsExpanded = !_statsExpanded),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117).withOpacity(0.82),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top:
                    BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Idle state: type selector + name + start ─────────────
                if (isIdle) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _typeSelector(tracking),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Activity name (optional)',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.07),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        _lastNotifiedSplit = 0;
                        // Ghost/pacer is for runs only — clear it on non-run start
                        if (tracking.activityType != 'run') {
                          setState(() => _selectedLegend = null);
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        final started = await tracking.startRecording(
                            title: _nameController.text.trim());
                        if (!started && mounted) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(
                                tracking.gpsWarning ?? 'Could not start GPS.'),
                            backgroundColor: const Color(0xFF151B26),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      icon:
                          const Icon(CupertinoIcons.play_arrow_solid, size: 18),
                      label: const Text('Start Recording'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Ghost / pace legend — only meaningful for runs
                  if (tracking.activityType == 'run')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ghostRow(tracking),
                    ),
                ],

                // ── Searching ────────────────────────────────────────────
                if (isSearching) ...[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: RuchaTheme.textSecondary)),
                      SizedBox(width: 10),
                      Text('Acquiring GPS…',
                          style: TextStyle(
                              color: RuchaTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ],

                // ── Active: metrics + controls ───────────────────────────
                if (isRunning || isPaused) ...[
                  if (_statsExpanded)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _metricsGrid(tracking, smartwatch),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _metricsCompact(tracking, smartwatch),
                    ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _controls(context, tracking, isRunning, isPaused),
                  ),
                  // Ghost live note
                  if (_selectedLegend != null && isRunning) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ghostLiveNote(tracking),
                    ),
                  ],
                  // Splits (only when expanded)
                  if (_statsExpanded && tracking.splits.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Row(
                        children: const [
                          Text('SPLITS',
                              style: TextStyle(
                                color: RuchaTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              )),
                        ],
                      ),
                    ),
                    SplitTable(splits: tracking.splits),
                  ],
                ],

                // GPS warning
                if (tracking.gpsWarning != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.location_slash,
                            color: RuchaTheme.accentGold, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tracking.gpsWarning!,
                            style: const TextStyle(
                                color: RuchaTheme.accentGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                // Safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Metric layouts ────────────────────────────────────────────────────────

  /// 3-column expanded grid — spacious, no congestion
  Widget _metricsGrid(TrackingService tracking, SmartwatchService smartwatch) {
    final isRide = tracking.activityType == 'ride';
    final bpm = smartwatch.currentBpm > 0
        ? '${smartwatch.currentBpm}'
        : (tracking.currentHr != null ? '${tracking.currentHr}' : '—');

    return Column(
      children: [
        Row(
          children: [
            _metricCell('DISTANCE',
                '${tracking.totalDistanceKm.toStringAsFixed(2)} km'),
            _divider(),
            _metricCell(
                'TIME', RuchaConstants.formatDuration(tracking.elapsedSeconds)),
            _divider(),
            _metricCell(
              isRide ? 'SPEED' : 'PACE',
              isRide
                  ? '${tracking.currentSpeedKmh.toStringAsFixed(1)} km/h'
                  : '${RuchaConstants.formatPace(tracking.currentPace)}/km',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricCell('+ELEVATION', '+${tracking.elevationGain.round()} m'),
            _divider(),
            _metricCell('HEART RATE', '$bpm bpm', valueColor: Colors.redAccent),
            _divider(),
            _metricCell('CALORIES', '${tracking.calories.round()} kcal'),
          ],
        ),
      ],
    );
  }

  /// Single-line compact pill when collapsed
  Widget _metricsCompact(
      TrackingService tracking, SmartwatchService smartwatch) {
    final isRide = tracking.activityType == 'ride';
    final bpm = smartwatch.currentBpm > 0 ? '${smartwatch.currentBpm} bpm' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${tracking.totalDistanceKm.toStringAsFixed(2)} km',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        _compactDot(),
        Text(
          RuchaConstants.formatDuration(tracking.elapsedSeconds),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        _compactDot(),
        Text(
          isRide
              ? '${tracking.currentSpeedKmh.toStringAsFixed(1)} km/h'
              : '${RuchaConstants.formatPace(tracking.currentPace)}/km',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (bpm.isNotEmpty) ...[
          _compactDot(),
          Text(
            '❤ $bpm',
            style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _metricCell(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withOpacity(0.1),
      );

  Widget _compactDot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      );

  // ── Controls ──────────────────────────────────────────────────────────────

  Widget _controls(BuildContext context, TrackingService tracking,
      bool isRunning, bool isPaused) {
    if (isRunning) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: tracking.pauseRecording,
              icon: const Icon(CupertinoIcons.pause_fill, size: 18),
              label: const Text('Pause'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _finishAndSave(context, tracking),
              icon: const Icon(CupertinoIcons.stop_fill, size: 18),
              label: const Text('Finish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: RuchaTheme.accentRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }
    if (isPaused) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: tracking.resumeRecording,
              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 18),
              label: const Text('Resume'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _finishAndSave(context, tracking),
              icon: const Icon(CupertinoIcons.stop_fill, size: 18),
              label: const Text('Finish'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // ── Type selector ─────────────────────────────────────────────────────────

  Widget _typeSelector(TrackingService tracking) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _typeBtn('run', '🏃 Run', tracking)),
          Expanded(child: _typeBtn('walk', '🚶 Walk', tracking)),
          Expanded(child: _typeBtn('ride', '🚴 Ride', tracking)),
        ],
      ),
    );
  }

  Widget _typeBtn(String type, String label, TrackingService tracking) {
    final active = tracking.activityType == type;
    return GestureDetector(
      onTap: () {
        tracking.setActivityType(type);
        // Ghost/pacer is for runs only — clear it when switching to walk/ride
        if (type != 'run') {
          setState(() => _selectedLegend = null);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withOpacity(0.45),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Activity type pill (idle, top bar) ────────────────────────────────────

  Widget _activityTypePill(TrackingService tracking, Color accent) {
    final icons = {'run': '🏃', 'walk': '🚶', 'ride': '🚴'};
    return _frostedPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icons[tracking.activityType] ?? '🏃',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            tracking.activityType[0].toUpperCase() +
                tracking.activityType.substring(1),
            style: TextStyle(
                color: accent, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _frostedPill({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117).withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  // ── GPS badge ─────────────────────────────────────────────────────────────

  Widget _buildGpsBadge(TrackingService tracking) {
    Color fg;
    String text;
    switch (tracking.gpsQuality) {
      case GpsQuality.good:
        fg = RuchaTheme.accentGreen;
        text = 'GPS';
        break;
      case GpsQuality.ok:
        fg = RuchaTheme.accentGreen;
        text = 'GPS OK';
        break;
      case GpsQuality.weak:
        fg = RuchaTheme.accentGold;
        text = 'GPS Weak';
        break;
      case GpsQuality.coarse:
        fg = RuchaTheme.accentRed;
        text = 'GPS ~';
        break;
      default:
        fg = RuchaTheme.textSecondary;
        text = 'Searching…';
    }
    if (tracking.lastAccuracy != null &&
        tracking.gpsQuality != GpsQuality.searching) {
      text += ' ±${tracking.lastAccuracy!.round()}m';
    }
    return _frostedPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Smartwatch badge ──────────────────────────────────────────────────────

  Widget _buildSmartwatchBadge(BuildContext context, SmartwatchService watch) {
    final connected = watch.isConnected;
    final bpm = watch.currentBpm;
    return GestureDetector(
      onTap: () => _showSmartwatchSheet(context, watch),
      child: _frostedPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? CupertinoIcons.heart_fill : CupertinoIcons.bluetooth,
              size: 13,
              color: connected ? Colors.redAccent : RuchaTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              connected
                  ? (bpm > 0
                      ? '$bpm BPM'
                      : (watch.connectedDeviceName ?? 'Watch'))
                  : 'Watch',
              style: TextStyle(
                color: connected ? Colors.redAccent : RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ghost legend ──────────────────────────────────────────────────────────

  Widget _ghostRow(TrackingService tracking) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ghostChip(
              null, 'None', _selectedLegend == null, RuchaTheme.textSecondary),
          for (final g in LegendGhost.all) ...[
            const SizedBox(width: 6),
            _ghostChip(
              g,
              '${g.icon} ${g.name}',
              _selectedLegend?.id == g.id,
              g.accentColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _ghostChip(
      LegendGhost? legend, String label, bool isSelected, Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _selectedLegend = legend),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _ghostLiveNote(TrackingService tracking) {
    if (_selectedLegend == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _selectedLegend!.accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: _selectedLegend!.accentColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.bolt_fill,
              size: 14, color: _selectedLegend!.accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _selectedLegend!.getPaceDeltaNote(tracking.currentPace),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Smartwatch bottom sheet ───────────────────────────────────────────────

  void _showSmartwatchSheet(BuildContext context, SmartwatchService watch) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RuchaTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [
                        Icon(CupertinoIcons.heart_circle_fill,
                            color: Colors.redAccent, size: 24),
                        SizedBox(width: 10),
                        Text('Heart Rate Sensor',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                      ]),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill,
                            color: RuchaTheme.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: watch.isConnected
                          ? Colors.redAccent.withOpacity(0.1)
                          : RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: watch.isConnected
                              ? Colors.redAccent.withOpacity(0.4)
                              : RuchaTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          watch.isConnected
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.circle,
                          color: watch.isConnected
                              ? Colors.redAccent
                              : RuchaTheme.textSecondary,
                          size: 26,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                watch.isConnected
                                    ? (watch.connectedDeviceName ?? 'Connected')
                                    : 'No Device',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (watch.isConnected)
                                Text('${watch.currentBpm} BPM',
                                    style: const TextStyle(
                                        color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (watch.isConnected)
                          TextButton(
                            onPressed: () {
                              watch.disconnect();
                              setSheetState(() {});
                            },
                            child: const Text('Disconnect',
                                style: TextStyle(color: RuchaTheme.accentRed)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: watch.isScanning
                        ? null
                        : () async {
                            await watch.startScan();
                            setSheetState(() {});
                          },
                    icon: watch.isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(
                            CupertinoIcons.antenna_radiowaves_left_right,
                            size: 18),
                    label: Text(
                        watch.isScanning ? 'Scanning…' : 'Scan for Devices'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: RuchaTheme.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                  ),
                  if (watch.discoveredWatches.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...watch.discoveredWatches.map((dev) {
                      final isCurrent =
                          watch.connectedDeviceAddress == dev.address;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: RuchaTheme.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isCurrent
                                  ? RuchaTheme.accentGreen
                                  : RuchaTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(dev.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            OutlinedButton(
                              onPressed: isCurrent
                                  ? null
                                  : () async {
                                      await watch.connect(dev);
                                      setSheetState(() {});
                                    },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              child: Text(isCurrent ? 'Paired' : 'Connect',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Demo mode',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Switch(
                          value: watch.isSimulatorMode,
                          activeColor: RuchaTheme.accentGreen,
                          onChanged: (val) {
                            watch.toggleSimulatorMode(val);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Finish & save ─────────────────────────────────────────────────────────

  void _finishAndSave(BuildContext context, TrackingService tracking) async {
    final act = tracking.finishRecording();
    _nameController.clear();
    _lastNotifiedSplit = 0;

    final store = context.read<ActivityStore>();
    final api = context.read<ApiService>();
    final navigator = Navigator.of(context);
    await store.add(act);
    unawaited(api.saveActivity(act));
    tracking.reset();
    if (!mounted) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => RunCardScreen(
          activity: act,
          ghostLegend: _selectedLegend,
        ),
      ),
    );
  }
}
