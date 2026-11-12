import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/ethiopian_utils.dart';
import '../core/theme.dart';
import '../models/activity.dart';
import '../services/activity_store.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'run_card_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  final VoidCallback? onStartRecording;

  const ActivitiesScreen({super.key, this.onStartRecording});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  String _filter = 'all';
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final store = context.read<ActivityStore>();
    final auth = context.read<AuthService>();
    if (auth.serverOnline && auth.isAuthenticated && !auth.isLocalAccount) {
      final api = context.read<ApiService>();
      final remote = await api.fetchActivities();
      await store.mergeRemote(remote);
    } else {
      await store.ensureLoaded();
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ActivityStore>();
    final activities = store.activities;
    final filtered =
        activities.where((a) => _filter == 'all' || a.type == _filter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RuchaTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _filterButton('all', 'All')),
                      Expanded(child: _filterButton('run', '● Runs')),
                      Expanded(child: _filterButton('walk', '● Walks')),
                      Expanded(child: _filterButton('ride', '● Rides')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.arrow_clockwise, size: 20),
                tooltip: 'Refresh',
                onPressed: _refreshing ? null : _refresh,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryStrip(store: store),
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
                  const Icon(
                    CupertinoIcons.doc_text,
                    size: 40,
                    color: RuchaTheme.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activities.isEmpty
                        ? 'No activities recorded yet'
                        : 'No ${_filter == 'ride' ? 'rides' : _filter == 'walk' ? 'walks' : 'runs'} yet',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Record your first run, walk or ride with live GPS. It is saved on this '
                    'device even when the server is offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: widget.onStartRecording,
                    icon: const Icon(CupertinoIcons.play_arrow_solid, size: 16),
                    label: const Text('Record an activity'),
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
              itemBuilder: (context, index) =>
                  _ActivityCard(act: filtered[index]),
            ),
        ],
      ),
    );
  }

  Widget _filterButton(String type, String label) {
    final active = _filter == type;
    // Dot color per type to match the design's coloured pill labels
    Color dotColor = RuchaTheme.accent;
    if (type == 'walk') dotColor = RuchaTheme.accentGold;
    if (type == 'ride') dotColor = RuchaTheme.accentGreen;

    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? dotColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? dotColor : Colors.transparent,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : RuchaTheme.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final ActivityStore store;

  const _SummaryStrip({required this.store});

  @override
  Widget build(BuildContext context) {
    final stats = store.allTimeStats;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RuchaTheme.surface2.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Row(
        children: [
          _metric('ALL TIME', '${stats.distanceKm.toStringAsFixed(1)} km'),
          _metric('TIME', RuchaConstants.formatDuration(stats.durationSeconds)),
          _metric('CLIMB', '+${stats.elevationGain.round()} m'),
          _metric('SESSIONS', '${stats.activityCount}'),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity act;

  const _ActivityCard({required this.act});

  @override
  Widget build(BuildContext context) {
    final isRide = act.type == 'ride';
    final isWalk = act.type == 'walk';
    final accent = isRide
        ? RuchaTheme.accentGreen
        : isWalk
            ? RuchaTheme.accentGold
            : RuchaTheme.accent;
    final icon = isRide
        ? Icons.directions_bike
        : isWalk
            ? Icons.directions_walk
            : Icons.directions_run;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RunCardScreen(activity: act)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            act.type.toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      RuchaConstants.cities[act.city]?.name ?? act.city,
                      style: const TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  _relativeTime(act.date, context),
                  style: const TextStyle(
                      color: RuchaTheme.textSecondary, fontSize: 11),
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
                _statCol(
                    'DISTANCE',
                    applyGeez('${act.distance.toStringAsFixed(2)} km',
                        enabled: context.read<SettingsService>().geezNumerals)),
                _statCol(
                    'DURATION',
                    applyGeez(RuchaConstants.formatDuration(act.duration),
                        enabled: context.read<SettingsService>().geezNumerals)),
                if (isRide)
                  _statCol(
                      'SPEED',
                      applyGeez(
                          '${(act.distance / (act.duration / 3600.0)).toStringAsFixed(1)} km/h',
                          enabled:
                              context.read<SettingsService>().geezNumerals))
                else
                  _statCol(
                      'PACE',
                      applyGeez('${RuchaConstants.formatPace(act.pace)} /km',
                          enabled:
                              context.read<SettingsService>().geezNumerals)),
                _statCol(
                    'CLIMB',
                    applyGeez('+${act.elevation.round()} m',
                        enabled: context.read<SettingsService>().geezNumerals)),
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
          Text(
            label,
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date, BuildContext context) {
    final settings = context.read<SettingsService>();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Use Ethiopian calendar if enabled
    return formatEthiopianDate(
      date,
      useEthiopian: settings.ethiopianCalendar,
      useGeez: settings.geezNumerals,
      amharic: settings.language == 'am',
    );
  }
}
