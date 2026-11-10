import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tracking_service.dart';
import '../services/api_service.dart';
import '../services/smartwatch_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/legend_ghost.dart';
import '../widgets/metric_card.dart';
import '../widgets/split_table.dart';
import '../widgets/osm_map_widget.dart';
import 'run_card_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final TextEditingController _nameController = TextEditingController();
  LegendGhost? _selectedLegend = LegendGhost.all[0]; // Default: Abebe Bikila
  int _lastNotifiedSplit = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final smartwatch = context.watch<SmartwatchService>();
    final isRunning = tracking.status == RecordingStatus.running;
    final isPaused = tracking.status == RecordingStatus.paused;
    final isIdle = tracking.status == RecordingStatus.idle;

    // Sync smartwatch heart rate into tracking service
    if (smartwatch.currentBpm > 0 && tracking.currentHr != smartwatch.currentBpm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        tracking.setCurrentHeartRate(smartwatch.currentBpm);
      });
    }

    // Check for new kilometre split notification note
    if (tracking.splits.length > _lastNotifiedSplit && _selectedLegend != null) {
      _lastNotifiedSplit = tracking.splits.length;
      final split = tracking.splits.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(_selectedLegend!.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KM ${split.km} Note: ${split.paceFormatted}/km vs ${_selectedLegend!.name} (${_selectedLegend!.targetPaceFormatted})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF151B26),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: _selectedLegend!.accentColor.withValues(alpha: 0.5)),
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Activity'),
        actions: [
          _buildSmartwatchBadge(context, smartwatch),
          const SizedBox(width: 8),
          _buildGpsBadge(tracking),
          const SizedBox(width: 14),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Activity Type Selector (Run / Ride)
              if (isIdle) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RuchaTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _typeButton('run', 'Run', Icons.directions_run, tracking),
                      ),
                      Expanded(
                        child: _typeButton('ride', 'Ride', Icons.directions_bike, tracking),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Activity title (e.g. Morning Entoto Climb)',
                    hintStyle: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: RuchaTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: RuchaTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: RuchaTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Coarse GPS Warning Banner
              if (tracking.gpsWarning != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RuchaTheme.accentGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RuchaTheme.accentGold.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.location_slash, color: RuchaTheme.accentGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tracking.gpsWarning!,
                          style: const TextStyle(color: RuchaTheme.accentGold, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Live OpenStreetMap Embedded View
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: RuchaTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RuchaTheme.border),
                ),
                child: OsmMapWidget(
                  centerLat: tracking.track.isNotEmpty
                      ? tracking.track.last.lat
                      : (RuchaConstants.cities[tracking.selectedCity] ?? RuchaConstants.cities['addis']!).lat,
                  centerLng: tracking.track.isNotEmpty
                      ? tracking.track.last.lng
                      : (RuchaConstants.cities[tracking.selectedCity] ?? RuchaConstants.cities['addis']!).lng,
                  initialZoom: 15,
                  track: tracking.track,
                  currentPosition: tracking.track.isNotEmpty ? tracking.track.last : null,
                  routeColor: tracking.activityType == 'ride' ? const Color(0xFF00E676) : const Color(0xFFFC4C02),
                  isInteractive: true,
                  isDarkMode: true,
                ),
              ),

              const SizedBox(height: 14),

              // Ghost of Legends (Visual Benchmark Notes)
              _buildGhostLegendSection(tracking),

              const SizedBox(height: 14),

              // Strava-Style Metrics Grid (Supports Run Pace vs Ride Speed + Heart Rate + Calories)
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.1,
                children: [
                  MetricCard(
                    label: 'Distance',
                    value: tracking.totalDistanceKm.toStringAsFixed(2),
                    unit: 'km',
                    icon: CupertinoIcons.map_pin_ellipse,
                  ),
                  MetricCard(
                    label: 'Time',
                    value: RuchaConstants.formatDuration(tracking.elapsedSeconds),
                    unit: '',
                    icon: CupertinoIcons.stopwatch,
                    iconColor: RuchaTheme.accentGold,
                  ),
                  if (tracking.activityType == 'ride')
                    MetricCard(
                      label: 'Speed',
                      value: tracking.currentSpeedKmh.toStringAsFixed(1),
                      unit: 'km/h',
                      icon: CupertinoIcons.speedometer,
                      iconColor: const Color(0xFF00E676),
                    )
                  else
                    MetricCard(
                      label: 'Pace',
                      value: RuchaConstants.formatPace(tracking.currentPace),
                      unit: '/km',
                      icon: CupertinoIcons.speedometer,
                      iconColor: const Color(0xFFFC4C02),
                    ),
                  MetricCard(
                    label: 'Elevation',
                    value: '+${tracking.elevationGain.round()}',
                    unit: 'm',
                    icon: CupertinoIcons.arrow_up_right,
                  ),
                  MetricCard(
                    label: 'Heart Rate',
                    value: smartwatch.currentBpm > 0
                        ? '${smartwatch.currentBpm}'
                        : (tracking.currentHr != null ? '${tracking.currentHr}' : '--'),
                    unit: 'bpm',
                    icon: CupertinoIcons.heart_fill,
                    iconColor: Colors.redAccent,
                  ),
                  MetricCard(
                    label: 'Calories',
                    value: '${tracking.calories.round()}',
                    unit: 'kcal',
                    icon: CupertinoIcons.flame_fill,
                    iconColor: Colors.orangeAccent,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Controls
              if (isIdle) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    tracking.startRecording(title: _nameController.text.trim());
                  },
                  icon: const Icon(CupertinoIcons.play_arrow_solid, size: 20),
                  label: const Text('Start Recording'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ] else if (isRunning) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => tracking.pauseRecording(),
                        icon: const Icon(CupertinoIcons.pause_fill, size: 20),
                        label: const Text('Pause'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _finishAndSave(context, tracking),
                        icon: const Icon(CupertinoIcons.stop_fill, size: 20),
                        label: const Text('Finish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RuchaTheme.accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isPaused) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => tracking.resumeRecording(),
                        icon: const Icon(CupertinoIcons.play_arrow_solid, size: 20),
                        label: const Text('Resume'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _finishAndSave(context, tracking),
                        icon: const Icon(CupertinoIcons.stop_fill, size: 20),
                        label: const Text('Finish'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Kilometre Splits Card
              Container(
                decoration: BoxDecoration(
                  color: RuchaTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RuchaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        'KILOMETRE SPLITS',
                        style: TextStyle(
                          color: RuchaTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SplitTable(splits: tracking.splits),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String type, String label, IconData icon, TrackingService tracking) {
    final active = tracking.activityType == type;
    return GestureDetector(
      onTap: () => tracking.setActivityType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? RuchaTheme.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? RuchaTheme.accentGreen : RuchaTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? RuchaTheme.textPrimary : RuchaTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostLegendSection(TrackingService tracking) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedLegend != null
              ? _selectedLegend!.accentColor.withValues(alpha: 0.4)
              : RuchaTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('⚔️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'GHOST OF LEGENDS (BENCHMARK NOTE)',
                    style: TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (_selectedLegend != null)
                Text(
                  _selectedLegend!.title,
                  style: TextStyle(
                    color: _selectedLegend!.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Legend Chip Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ghostChip(
                  null,
                  'None',
                  _selectedLegend == null,
                  RuchaTheme.textSecondary,
                ),
                for (final g in LegendGhost.all) ...[
                  const SizedBox(width: 6),
                  _ghostChip(
                    g,
                    '${g.icon} ${g.name} (${g.targetPaceFormatted})',
                    _selectedLegend?.id == g.id,
                    g.accentColor,
                  ),
                ],
              ],
            ),
          ),

          if (_selectedLegend != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedLegend!.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _selectedLegend!.accentColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    tracking.status == RecordingStatus.running
                        ? CupertinoIcons.bolt_fill
                        : CupertinoIcons.info_circle_fill,
                    size: 16,
                    color: _selectedLegend!.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tracking.status == RecordingStatus.running
                          ? _selectedLegend!.getPaceDeltaNote(tracking.currentPace)
                          : '${_selectedLegend!.note} · Visual pace notes appear during your run.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ghostChip(LegendGhost? legend, String label, bool isSelected, Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _selectedLegend = legend),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.2) : RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? accent : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : RuchaTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildGpsBadge(TrackingService tracking) {
    Color bg;
    Color fg;
    String text;

    switch (tracking.gpsQuality) {
      case GpsQuality.good:
        bg = RuchaTheme.accentGreen.withOpacity(0.15);
        fg = RuchaTheme.accentGreen;
        text = 'GPS Strong';
        break;
      case GpsQuality.ok:
        bg = RuchaTheme.accentGreen.withOpacity(0.12);
        fg = RuchaTheme.accentGreen;
        text = 'GPS OK';
        break;
      case GpsQuality.weak:
        bg = RuchaTheme.accentGold.withOpacity(0.15);
        fg = RuchaTheme.accentGold;
        text = 'GPS Weak';
        break;
      case GpsQuality.coarse:
        bg = RuchaTheme.accentRed.withOpacity(0.15);
        fg = RuchaTheme.accentRed;
        text = 'Approximate';
        break;
      case GpsQuality.lost:
      case GpsQuality.searching:
        bg = RuchaTheme.surface2;
        fg = RuchaTheme.textSecondary;
        text = 'Searching…';
        break;
    }

    if (tracking.lastAccuracy != null && tracking.gpsQuality != GpsQuality.searching) {
      text += ' · ±${tracking.lastAccuracy!.round()}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartwatchBadge(BuildContext context, SmartwatchService watch) {
    final connected = watch.isConnected;
    final bpm = watch.currentBpm;
    final color = connected ? Colors.redAccent : RuchaTheme.textSecondary;
    final bg = connected ? Colors.redAccent.withOpacity(0.12) : RuchaTheme.surface2;

    return InkWell(
      onTap: () => _showSmartwatchSheet(context, watch),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? CupertinoIcons.heart_fill : CupertinoIcons.bluetooth,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              connected
                  ? (bpm > 0 ? '$bpm BPM' : (watch.connectedDeviceName ?? 'Watch'))
                  : 'Watch',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                      const Row(
                        children: [
                          Icon(CupertinoIcons.heart_circle_fill, color: Colors.redAccent, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Smartwatch & Sensors',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: RuchaTheme.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Connection Status Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: watch.isConnected ? Colors.redAccent.withOpacity(0.1) : RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: watch.isConnected ? Colors.redAccent.withOpacity(0.4) : RuchaTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          watch.isConnected ? CupertinoIcons.heart_fill : CupertinoIcons.circle,
                          color: watch.isConnected ? Colors.redAccent : RuchaTheme.textSecondary,
                          size: 26,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                watch.isConnected
                                    ? (watch.connectedDeviceName ?? 'Connected Smartwatch')
                                    : 'No Smartwatch Connected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                watch.isConnected
                                    ? 'Streaming Heart Rate · ${watch.currentBpm} BPM'
                                    : 'Connect a Wear OS, Garmin, Apple Watch BLE, or Polar sensor',
                                style: TextStyle(
                                  color: watch.isConnected ? Colors.redAccent : RuchaTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (watch.isConnected)
                          TextButton(
                            onPressed: () {
                              watch.disconnect();
                              setSheetState(() {});
                            },
                            child: const Text('Disconnect', style: TextStyle(color: RuchaTheme.accentRed)),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Scan Button
                  ElevatedButton.icon(
                    onPressed: watch.isScanning
                        ? null
                        : () async {
                            await watch.startScan();
                            setSheetState(() {});
                          },
                    icon: watch.isScanning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 18),
                    label: Text(watch.isScanning ? 'Scanning for nearby devices…' : 'Scan for Nearby Smartwatches'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RuchaTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),

                  // Discovered Devices List
                  if (watch.discoveredWatches.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('DISCOVERED DEVICES', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...watch.discoveredWatches.map((dev) {
                      final isCurrent = watch.connectedDeviceAddress == dev.address;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: RuchaTheme.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isCurrent ? RuchaTheme.accentGreen : RuchaTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(CupertinoIcons.device_laptop, size: 18, color: RuchaTheme.accentGold),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(dev.address, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                            OutlinedButton(
                              onPressed: isCurrent
                                  ? null
                                  : () async {
                                      await watch.connect(dev);
                                      setSheetState(() {});
                                    },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                side: BorderSide(color: isCurrent ? RuchaTheme.accentGreen : RuchaTheme.border),
                              ),
                              child: Text(isCurrent ? 'Paired' : 'Connect', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 14),

                  // Simulation Switch (For testing & demos)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Virtual Smartwatch Demo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Simulates live athletic heart rate (140-175 BPM)', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
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

  void _finishAndSave(BuildContext context, TrackingService tracking) async {
    final act = tracking.finishRecording();

    // Sync to backend if available
    final api = context.read<ApiService>();
    api.saveActivity(act);

    // Open Run Card Studio with selected Ghost Legend note
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunCardScreen(
          activity: act,
          ghostLegend: _selectedLegend,
        ),
      ),
    );
  }
}
