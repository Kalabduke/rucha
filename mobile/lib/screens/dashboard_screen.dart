import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/activity.dart';
import '../services/activity_store.dart';
import '../services/tracking_service.dart';
import '../widgets/metric_card.dart';
import 'run_card_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onStartRecording;
  final ValueChanged<int>? onNavigateTo;

  const DashboardScreen({
    super.key,
    required this.onStartRecording,
    this.onNavigateTo,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final store = context.watch<ActivityStore>();
    final city = RuchaConstants.cities[tracking.selectedCity] ??
        RuchaConstants.cities['addis']!;
    final stats = store.last7DaysStats;
    final recent = store.activities.take(5).toList();
    // Per-day km for the current Mon–Sun week (7 values)
    final weekBuckets = store.weeklyVolume(weeks: 1);
    final weekVols = weekBuckets.isNotEmpty
        ? List.generate(7, (i) {
            final day = weekBuckets.first.weekStart.add(Duration(days: i));
            return store
                .statsFor(from: day, to: day.add(const Duration(days: 1)))
                .distanceKm;
          })
        : List<double>.filled(7, 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Greeting + city ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(
                            color: RuchaTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ready to run?',
                          style: TextStyle(
                            color: RuchaTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Auto-detected city chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: RuchaTheme.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          city.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: RuchaTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 2. Quick-start hero card ────────────────────────────────────
              GestureDetector(
                onTap: onStartRecording,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [RuchaTheme.accent, Color(0xFFE84E0A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: RuchaTheme.cardShadow(
                        color: RuchaTheme.accent, opacity: 0.35),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUICK START',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'RUN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${city.name} · ${city.baseEle.round()} m',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.play_arrow_solid,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── 3. Weekly volume bar chart ─────────────────────────────────
              _WeeklyChart(volumes: weekVols),

              const SizedBox(height: 20),

              // ── 4. 7-day stats — hero orange + 2 neutral stacked ──────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: MetricCard(
                        label: 'Duration',
                        value: RuchaConstants.formatDuration(
                            stats.durationSeconds),
                        unit: 'hrs',
                        icon: CupertinoIcons.stopwatch_fill,
                        accent: RuchaTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: MetricCard(
                              label: 'Calories',
                              value: stats.activityCount > 0
                                  ? '${(stats.distanceKm * 62).round()}'
                                  : '—',
                              unit: 'kcal',
                              icon: CupertinoIcons.flame_fill,
                              iconColor: RuchaTheme.accentRed,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: MetricCard(
                              label: 'Distance',
                              value: stats.distanceKm.toStringAsFixed(1),
                              unit: 'km',
                              icon: CupertinoIcons.location_fill,
                              iconColor: RuchaTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Elevation',
                      value: '+${stats.elevationGain.round()}',
                      unit: 'm',
                      icon: Icons.landscape_rounded,
                      iconColor: RuchaTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      label: 'Activities',
                      value: '${stats.activityCount}',
                      unit: stats.activityCount == 1 ? 'run' : 'runs',
                      icon: CupertinoIcons.bolt_fill,
                      iconColor: RuchaTheme.accentGold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── 5. Feature hub ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _HubCard(
                      icon: Icons.map_outlined,
                      color: RuchaTheme.accentBlue,
                      title: 'Explore',
                      onTap: () => onNavigateTo?.call(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HubCard(
                      icon: Icons.photo_library_rounded,
                      color: RuchaTheme.accent,
                      title: 'Cards',
                      onTap: () => onNavigateTo?.call(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HubCard(
                      icon: Icons.terrain_rounded,
                      color: RuchaTheme.accentGreen,
                      title: 'Segments',
                      onTap: () => onNavigateTo?.call(5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HubCard(
                      icon: Icons.groups_2_rounded,
                      color: RuchaTheme.accentGold,
                      title: 'Community',
                      onTap: () => onNavigateTo?.call(6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── 6. Recent activities ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT',
                    style: TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (recent.isNotEmpty)
                    GestureDetector(
                      onTap: () => onNavigateTo?.call(3),
                      child: const Text(
                        'All',
                        style: TextStyle(
                          color: RuchaTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (recent.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: RuchaTheme.accent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_run_rounded,
                            size: 32, color: RuchaTheme.accent),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No activities yet',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: RuchaTheme.textPrimary),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _RecentActivityTile(activity: recent[index]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Weekly bar chart ─────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<double> volumes; // km per day, 7 entries, oldest first

  const _WeeklyChart({required this.volumes});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon
    final maxVol = volumes.fold(0.0, max);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: RuchaTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        boxShadow: RuchaTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THIS WEEK',
                style: TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${volumes.fold(0.0, (s, v) => s + v).toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: RuchaTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final vol = i < volumes.length ? volumes[i] : 0.0;
                final frac = maxVol > 0 ? (vol / maxVol).clamp(0.0, 1.0) : 0.0;
                final isToday = i == todayIndex;
                final hasActivity = vol > 0;
                final barColor = isToday
                    ? RuchaTheme.accent
                    : hasActivity
                        ? RuchaTheme.accent.withOpacity(0.45)
                        : const Color(0xFF2A2A3A);
                final barH = max(4.0, frac * 50.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Background track
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A3A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            // Filled portion
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              height: barH,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isToday
                                    ? [
                                        BoxShadow(
                                          color: RuchaTheme.accent
                                              .withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(7, (i) {
              final isToday = i == todayIndex;
              return Expanded(
                child: Text(
                  days[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        isToday ? RuchaTheme.accent : RuchaTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Hub card ─────────────────────────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(18),
          boxShadow: RuchaTheme.cardShadow(),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.25)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: RuchaTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent activity tile ──────────────────────────────────────────────────────

class _RecentActivityTile extends StatelessWidget {
  final Activity activity;
  const _RecentActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isRide = activity.type == 'ride';
    final isWalk = activity.type == 'walk';
    final accent = isRide
        ? RuchaTheme.accentGreen
        : isWalk
            ? RuchaTheme.accentGold
            : RuchaTheme.accent;
    final icon = isRide
        ? Icons.directions_bike_rounded
        : isWalk
            ? Icons.directions_walk_rounded
            : Icons.directions_run_rounded;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RunCardScreen(activity: activity)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(18),
          boxShadow: RuchaTheme.cardShadow(),
        ),
        child: Row(
          children: [
            // Coloured icon pill
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, 0.3)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: RuchaTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${activity.distance.toStringAsFixed(2)} km · '
                    '${RuchaConstants.formatDuration(activity.duration)} · '
                    '+${activity.elevation.round()} m',
                    style: const TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right,
                size: 15, color: RuchaTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
