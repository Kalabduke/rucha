import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class SegmentItem {
  final String id;
  final String name;
  final String city;
  final double distance;
  final double elevationGain;
  final String category; // 'HC', 'Cat 1', 'Cat 2', 'Cat 3', 'Cat 4'
  final int attempts;
  final int bestSec;
  final String bestAthlete;

  SegmentItem({
    required this.id,
    required this.name,
    required this.city,
    required this.distance,
    required this.elevationGain,
    required this.category,
    required this.attempts,
    required this.bestSec,
    required this.bestAthlete,
  });
}

class SegmentsScreen extends StatefulWidget {
  const SegmentsScreen({super.key});

  @override
  State<SegmentsScreen> createState() => _SegmentsScreenState();
}

class _SegmentsScreenState extends State<SegmentsScreen> {
  final List<SegmentItem> _segments = [
    SegmentItem(
      id: 's1',
      name: 'Entoto Ridge Highway Sprint',
      city: 'Addis Ababa',
      distance: 2.4,
      elevationGain: 185,
      category: 'Cat 2',
      attempts: 412,
      bestSec: 540, // 9:00
      bestAthlete: 'Kenensa B.',
    ),
    SegmentItem(
      id: 's2',
      name: 'Bishoftu Lake View Mile',
      city: 'Bishoftu',
      distance: 1.6,
      elevationGain: 35,
      category: 'Cat 4',
      attempts: 289,
      bestSec: 285, // 4:45
      bestAthlete: 'Derartu T.',
    ),
    SegmentItem(
      id: 's3',
      name: 'Meskel Square Criterium Loop',
      city: 'Addis Ababa',
      distance: 1.2,
      elevationGain: 12,
      category: 'Cat 4',
      attempts: 1230,
      bestSec: 192, // 3:12
      bestAthlete: 'Haile G.',
    ),
    SegmentItem(
      id: 's4',
      name: 'Lake Tana Waterfront Dash',
      city: 'Bahir Dar',
      distance: 3.8,
      elevationGain: 28,
      category: 'Cat 3',
      attempts: 198,
      bestSec: 720,
      bestAthlete: 'Tirunesh D.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
            const Text('Course Segments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add_circled, color: RuchaTheme.accentGreen),
            onPressed: () => _openCreateSegmentDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _segments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final s = _segments[idx];
          return Container(
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: RuchaTheme.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.category,
                        style: const TextStyle(
                          color: RuchaTheme.accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${s.attempts} attempts',
                      style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.city} · ${s.distance.toStringAsFixed(1)} km · +${s.elevationGain.round()} m climb',
                  style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface2.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.star_fill, size: 14, color: RuchaTheme.accentGold),
                          const SizedBox(width: 6),
                          Text(
                            'CR: ${s.bestAthlete}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text(
                        RuchaConstants.formatDuration(s.bestSec),
                        style: const TextStyle(
                          color: RuchaTheme.accentGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openCreateSegmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.terrain, color: RuchaTheme.accentGreen),
            SizedBox(width: 8),
            Text('Create a Segment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Turn any of your recorded activities into a course other athletes can race. Start and finish coordinates are matched automatically within 150 meters.',
          style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: RuchaTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Record an activity first to turn it into a segment!')),
              );
            },
            child: const Text('Select Activity'),
          ),
        ],
      ),
    );
  }
}
