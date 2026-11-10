import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tracking_service.dart';
import '../services/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/metric_card.dart';
import '../widgets/route_painter.dart';
import '../widgets/split_table.dart';
import 'run_card_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final TextEditingController _nameController = TextEditingController();

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

              // Live Map / Route View
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: RuchaTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RuchaTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Procedural Grid background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: RoutePainter(
                            points: tracking.track,
                            routeColor: tracking.activityType == 'ride' ? RuchaTheme.accentGreen : RuchaTheme.accentCoral,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: RuchaTheme.background.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tracking.track.isEmpty ? 'Waiting for route…' : '${tracking.track.length} points logged',
                            style: const TextStyle(fontSize: 10, color: RuchaTheme.textSecondary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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

    // Open Run Card Studio
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunCardScreen(activity: act),
      ),
    );
  }
}
