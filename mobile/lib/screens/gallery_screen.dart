import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/activity.dart';
import '../models/legend_ghost.dart';
import '../services/activity_store.dart';
import 'run_card_screen.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ActivityStore>();
    final activities = store.activities;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.sparkles,
                    color: RuchaTheme.accentGold, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Run Cards',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.camera_fill,
                      color: RuchaTheme.accentGreen),
                  tooltip: 'Create card',
                  onPressed: activities.isEmpty
                      ? null
                      : () => _openCardCreator(context, activities.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            _buildEmptyState(context)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                // Ghost legend only makes sense for runs
                final legend = activity.type == 'run'
                    ? LegendGhost.all[index % LegendGhost.all.length]
                    : null;
                return _buildCardTile(context, activity, legend, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.photo_on_rectangle,
            size: 48,
            color: RuchaTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No run cards yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Finish recording a run to generate an artistic card with your GPS route, '
            'stats and an Ethiopian legend benchmark.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: RuchaTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(
    BuildContext context,
    Activity activity,
    LegendGhost? legend,
    int index,
  ) {
    LinearGradient gradient;
    Color accent;
    switch (index % 3) {
      case 1:
        gradient = const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accent = const Color(0xFF5FD6A8);
        break;
      case 2:
        gradient = const LinearGradient(
          colors: [Color(0xFF2B1055), Color(0xFF7597DE), Color(0xFF141E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accent = const Color(0xFFF2B705);
        break;
      default:
        gradient = const LinearGradient(
          colors: [Color(0xFF1F1C2C), Color(0xFF928DAB), Color(0xFFE65C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accent = const Color(0xFFFF7A42);
    }

    return GestureDetector(
      onTap: () => _openCardCreator(context, activity, legend: legend),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient,
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RUCHA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(legend?.icon ?? '🏃',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  RuchaConstants.cities[activity.city]?.name ?? activity.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${activity.distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      RuchaConstants.formatDuration(activity.duration),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCardCreator(BuildContext context, Activity activity,
      {LegendGhost? legend}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunCardScreen(
          activity: activity,
          ghostLegend: legend,
        ),
      ),
    );
  }
}
