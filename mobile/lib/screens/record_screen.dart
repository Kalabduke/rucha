import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tracking_service.dart';
import '../services/api_service.dart';
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
    final isRunning = tracking.status == RecordingStatus.running;
    final isPaused = tracking.status == RecordingStatus.paused;
    final isIdle = tracking.status == RecordingStatus.idle;

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
                  routeColor: tracking.activityType == 'ride' ? RuchaTheme.accentGreen : RuchaTheme.accentCoral,
                  isInteractive: true,
                  isDarkMode: true,
                ),
              ),

              const SizedBox(height: 14),

              // Ghost of Legends (Visual Benchmark Notes)
              _buildGhostLegendSection(tracking),

              const SizedBox(height: 14),

              // Metrics Grid
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
                  MetricCard(
                    label: 'Pace',
                    value: RuchaConstants.formatPace(tracking.currentPace),
                    unit: '/km',
                    icon: CupertinoIcons.speedometer,
                    iconColor: RuchaTheme.accentCoral,
                  ),
                  MetricCard(
                    label: 'Elevation',
                    value: '+${tracking.elevationGain.round()}',
                    unit: 'm',
                    icon: CupertinoIcons.arrow_up_right,
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
                  _selectedLegend!.amharicName,
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
