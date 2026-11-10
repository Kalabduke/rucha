import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity.dart';
import '../services/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'run_card_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  final VoidCallback? onStartRecording;

  const ActivitiesScreen({super.key, this.onStartRecording});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  String _filter = 'all'; // 'all', 'run', 'ride'
  List<Activity> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final api = context.read<ApiService>();
    final list = await api.fetchActivities();
    if (mounted) {
      setState(() {
        _activities = list.isNotEmpty ? list : _fallbackActivities();
        _isLoading = false;
      });
    }
  }

  List<Activity> _fallbackActivities() {
    return [
      Activity(
        id: 'act_1',
        title: 'Morning Entoto Ridge Climb',
        type: 'run',
        city: 'Addis Ababa',
        distance: 8.42,
        duration: 2580,
        pace: 306.0,
        elevation: 340.0,
        date: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Activity(
        id: 'act_2',
        title: 'Meskel Square Fast Circuit',
        type: 'run',
        city: 'Addis Ababa',
        distance: 5.10,
        duration: 1320,
        pace: 258.0,
        elevation: 45.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Activity(
        id: 'act_3',
        title: 'Bole Medhane Alem Evening Ride',
        type: 'ride',
        city: 'Addis Ababa',
        distance: 21.60,
        duration: 3240,
        pace: 150.0,
        elevation: 180.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _activities.where((a) {
      if (_filter == 'all') return true;
      return a.type == _filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentGreen)),
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentGold)),
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentRed)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text('Training Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(width: 8),
                Text('እንቅስቃሴዎች', style: TextStyle(fontSize: 12, color: RuchaTheme.accentGold, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadActivities();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RuchaTheme.accentGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _filterButton('all', 'All (${_activities.length})')),
                        Expanded(child: _filterButton('run', 'Runs')),
                        Expanded(child: _filterButton('ride', 'Rides')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(CupertinoIcons.doc_text, size: 40, color: RuchaTheme.textSecondary),
                          const SizedBox(height: 12),
                          const Text('No activities recorded yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Record your first run or ride with live GPS.', style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: widget.onStartRecording,
                            icon: const Icon(CupertinoIcons.play_arrow_solid, size: 16),
                            label: const Text('Start Recording'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RuchaTheme.accentGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final act = filtered[idx];
                        return _buildActivityCard(act);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _filterButton(String type, String label) {
    final active = _filter == type;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? RuchaTheme.accentGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : RuchaTheme.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Activity act) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RunCardScreen(activity: act),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RuchaTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RuchaTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: act.type == 'ride'
                            ? RuchaTheme.accentGreen.withValues(alpha: 0.15)
                            : RuchaTheme.accentCoral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            act.type == 'ride' ? Icons.directions_bike : Icons.directions_run,
                            size: 14,
                            color: act.type == 'ride' ? RuchaTheme.accentGreen : RuchaTheme.accentCoral,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            act.type.toUpperCase(),
                            style: TextStyle(
                              color: act.type == 'ride' ? RuchaTheme.accentGreen : RuchaTheme.accentCoral,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      act.city,
                      style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  _relativeTime(act.date),
                  style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              act.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statCol('DISTANCE', '${act.distance.toStringAsFixed(2)} km'),
                _statCol('DURATION', RuchaConstants.formatDuration(act.duration)),
                _statCol('PACE', '${RuchaConstants.formatPace(act.pace)} /km'),
                _statCol('CLIMB', '+${act.elevation.round()} m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
