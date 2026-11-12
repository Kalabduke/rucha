import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../services/activity_store.dart';
import '../services/auth_service.dart';

class SegmentItem {
  final String id;
  final String name;
  final String city;
  final double distance;
  final double elevationGain;
  final String category;
  final String type;
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
    this.type = 'run',
    required this.attempts,
    required this.bestSec,
    required this.bestAthlete,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'distance': distance,
        'elevationGain': elevationGain,
        'category': category,
        'type': type,
        'attempts': attempts,
        'bestSec': bestSec,
        'bestAthlete': bestAthlete,
      };

  factory SegmentItem.fromJson(Map<String, dynamic> json) => SegmentItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Segment',
        city: json['city']?.toString() ?? 'addis',
        distance: (json['distance'] as num?)?.toDouble() ?? 0,
        elevationGain: (json['elevationGain'] as num?)?.toDouble() ?? 0,
        category: json['category']?.toString() ?? 'Cat 4',
        type: json['type']?.toString() ?? 'run',
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        bestSec: (json['bestSec'] as num?)?.toInt() ?? 0,
        bestAthlete: json['bestAthlete']?.toString() ?? 'Athlete',
      );
}

class SegmentsScreen extends StatefulWidget {
  const SegmentsScreen({super.key});

  @override
  State<SegmentsScreen> createState() => _SegmentsScreenState();
}

class _SegmentsScreenState extends State<SegmentsScreen> {
  static const _prefsKey = 'rucha_segments_v1';

  List<SegmentItem> _segments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSegments();
  }

  Future<void> _loadSegments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _segments = decoded
              .whereType<Map>()
              .map((item) =>
                  SegmentItem.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveSegments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_segments.map((segment) => segment.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ActivityStore>();
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _segments.isEmpty
              ? _buildEmptyState(store)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _segments.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildIntro(store);
                    return _segmentCard(_segments[index - 1]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSegment(context, store),
        backgroundColor: RuchaTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Create segment'),
      ),
    );
  }

  Widget _buildIntro(ActivityStore store) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.terrain, color: RuchaTheme.accentGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_segments.length} ${_segments.length == 1 ? 'segment' : 'segments'}',
              style: const TextStyle(
                  color: RuchaTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ActivityStore store) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terrain,
                size: 52, color: RuchaTheme.textSecondary),
            const SizedBox(height: 14),
            const Text(
              'No segments yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _createSegment(context, store),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Create your first segment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentCard(SegmentItem segment) {
    final isRide = segment.type == 'ride';
    final accent = isRide ? RuchaTheme.accentGreen : RuchaTheme.accent;
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
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  segment.category,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${segment.attempts} attempt${segment.attempts == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            segment.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${RuchaConstants.cities[segment.city]?.name ?? segment.city} · '
            '${segment.distance.toStringAsFixed(1)} km · '
            '+${segment.elevationGain.round()} m climb · ${isRide ? 'Ride' : 'Run'}',
            style:
                const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RuchaTheme.surface2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.star_fill,
                        size: 14, color: RuchaTheme.accentGold),
                    const SizedBox(width: 6),
                    Text(
                      'CR: ${segment.bestAthlete}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Text(
                  segment.bestSec > 0
                      ? RuchaConstants.formatDuration(segment.bestSec)
                      : 'No time',
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
  }

  void _createSegment(BuildContext context, ActivityStore store) {
    final auth = context.read<AuthService>();
    final activities = store.activities;
    if (activities.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: RuchaTheme.surface,
          title: const Text('Record an activity first'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final activity = activities.first;
    final category = _categoryFor(
        activity.elevation / (activity.distance == 0 ? 1 : activity.distance));
    final athlete = auth.currentUser?.displayName ??
        (auth.isGuest ? 'Guest athlete' : 'RUCHA athlete');
    final segment = SegmentItem(
      id: 'seg_${DateTime.now().millisecondsSinceEpoch}',
      name: activity.title,
      city: activity.city,
      distance: activity.distance,
      elevationGain: activity.elevation,
      category: category,
      type: activity.type,
      attempts: 1,
      bestSec: activity.duration,
      bestAthlete: athlete,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.terrain, color: RuchaTheme.accentGreen, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Create segment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use "${activity.title}" as your course?',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '${activity.distance.toStringAsFixed(2)} km · '
              '+${activity.elevation.round()} m · $category. '
              'The start and finish of this route become the segment match points.',
              style: const TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              setState(() => _segments.insert(0, segment));
              await _saveSegments();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                    content:
                        Text('Segment "${segment.name}" created locally.')),
              );
            },
            child: const Text('Create segment'),
          ),
        ],
      ),
    );
  }

  String _categoryFor(double gainPerKm) {
    if (gainPerKm >= 800) return 'HC';
    if (gainPerKm >= 500) return 'Cat 1';
    if (gainPerKm >= 250) return 'Cat 2';
    if (gainPerKm >= 100) return 'Cat 3';
    return 'Cat 4';
  }
}
