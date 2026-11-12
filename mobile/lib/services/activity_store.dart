import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';

/// Aggregate training numbers for a period.
class ActivityStats {
  final double distanceKm;
  final int durationSeconds;
  final double elevationGain;
  final int activityCount;

  const ActivityStats({
    this.distanceKm = 0,
    this.durationSeconds = 0,
    this.elevationGain = 0,
    this.activityCount = 0,
  });

  static const ActivityStats empty = ActivityStats();
}

/// One bar in the weekly training-volume chart.
class WeeklyVolume {
  final DateTime weekStart;
  final double distanceKm;
  final int activityCount;

  const WeeklyVolume({
    required this.weekStart,
    required this.distanceKm,
    required this.activityCount,
  });

  String get label => 'W${ActivityStore._isoWeekNumber(weekStart)}';
}

/// A fastest-effort record derived from recorded GPS tracks.
class BestEffort {
  final String label;
  final double targetKm;
  final int seconds;
  final String activityTitle;
  final DateTime date;

  const BestEffort({
    required this.label,
    required this.targetKm,
    required this.seconds,
    required this.activityTitle,
    required this.date,
  });
}

/// Local-first activity storage.
///
/// The PWA keeps activities in `localStorage` so a run is never lost when the
/// RUCHA API is unavailable. This service does the same for the Flutter app and
/// exposes derived statistics so every screen reads from one source of truth.
class ActivityStore extends ChangeNotifier {
  static const String _prefsKey = 'rucha_activities_v1';

  final List<Activity> _activities = [];
  bool _loaded = false;
  Future<void>? _loading;

  List<Activity> get activities => List.unmodifiable(_activities);
  bool get isLoaded => _loaded;
  bool get isEmpty => _activities.isEmpty;

  ActivityStore() {
    _loading = _load();
  }

  Future<void> ensureLoaded() => _loading ?? Future<void>.value();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _activities
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((item) => Activity.fromJson(Map<String, dynamic>.from(item))));
        }
      }
    } catch (e) {
      debugPrint('ActivityStore load failed: $e');
    }
    _activities.sort((a, b) => b.date.compareTo(a.date));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_activities.map((activity) => activity.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('ActivityStore save failed: $e');
    }
  }

  Future<void> add(Activity activity) async {
    await ensureLoaded();
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index >= 0) {
      _activities[index] = activity;
    } else {
      _activities.add(activity);
    }
    _activities.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _activities.removeWhere((activity) => activity.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    await ensureLoaded();
    _activities.clear();
    notifyListeners();
    await _persist();
  }

  /// Adds activities fetched from the API without creating duplicates.
  Future<void> mergeRemote(List<Activity> remote) async {
    await ensureLoaded();
    if (remote.isEmpty) return;
    final known = _activities.map((a) => a.id).toSet();
    var changed = false;
    for (final activity in remote) {
      if (activity.id.isNotEmpty && known.add(activity.id)) {
        _activities.add(activity);
        changed = true;
      }
    }
    if (!changed) return;
    _activities.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _persist();
  }

  ActivityStats statsFor({DateTime? from, DateTime? to}) {
    var distance = 0.0;
    var duration = 0;
    var elevation = 0.0;
    var count = 0;
    for (final activity in _activities) {
      if (from != null && activity.date.isBefore(from)) continue;
      if (to != null && !activity.date.isBefore(to)) continue;
      distance += activity.distance;
      duration += activity.duration;
      elevation += activity.elevation;
      count++;
    }
    return ActivityStats(
      distanceKm: distance,
      durationSeconds: duration,
      elevationGain: elevation,
      activityCount: count,
    );
  }

  ActivityStats get allTimeStats => statsFor();

  ActivityStats get last7DaysStats {
    final now = DateTime.now();
    return statsFor(from: now.subtract(const Duration(days: 7)));
  }

  /// Seven weekly buckets, oldest first, where the last bucket is this week.
  List<WeeklyVolume> weeklyVolume({int weeks = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final result = <WeeklyVolume>[];

    for (var i = weeks - 1; i >= 0; i--) {
      final start = currentMonday.subtract(Duration(days: i * 7));
      final end = start.add(const Duration(days: 7));
      final stats = statsFor(from: start, to: end);
      result.add(WeeklyVolume(
        weekStart: start,
        distanceKm: stats.distanceKm,
        activityCount: stats.activityCount,
      ));
    }
    return result;
  }

  /// Best 1 km, 5 km, 10 km and half-marathon efforts from GPS tracks.
  ///
  /// When an activity has no track (for example an imported activity), its
  /// average pace is used as a conservative estimate.
  List<BestEffort> get bestEfforts {
    const targets = <({String label, double km})>[
      (label: '1 km', km: 1.0),
      (label: '5 km', km: 5.0),
      (label: '10 km', km: 10.0),
      (label: 'Half Marathon', km: 21.0975),
    ];

    final efforts = <String, BestEffort>{};
    for (final activity in _activities) {
      if (activity.type == 'ride') continue;
      for (final target in targets) {
        if (activity.distance + 0.02 < target.km) continue;

        int? seconds;
        if (activity.track.length >= 2) {
          seconds = _bestWindowSeconds(activity.track, target.km);
        }
        seconds ??= (activity.pace * target.km).round();
        if (seconds <= 0) continue;

        final current = efforts[target.label];
        if (current == null || seconds < current.seconds) {
          efforts[target.label] = BestEffort(
            label: target.label,
            targetKm: target.km,
            seconds: seconds,
            activityTitle: activity.title,
            date: activity.date,
          );
        }
      }
    }

    return [
      for (final target in targets)
        if (efforts[target.label] case final effort?) effort,
    ];
  }

  static int? _bestWindowSeconds(List<TrackPoint> track, double targetKm) {
    if (track.length < 2 || targetKm <= 0) return null;
    var bestMs = 1 << 62;
    var start = 0;

    for (var end = 0; end < track.length; end++) {
      if (track[end].d + 1e-9 < targetKm) continue;
      final windowStartD = track[end].d - targetKm;
      while (start + 1 < end && track[start + 1].d <= windowStartD) {
        start++;
      }
      if (start >= end) continue;

      final a = track[start];
      final b = track[start + 1];
      final span = b.d - a.d;
      final fraction = span > 1e-9 ? ((windowStartD - a.d) / span).clamp(0.0, 1.0) : 0.0;
      final startMs = a.t + ((b.t - a.t) * fraction).round();
      final elapsedMs = track[end].t - startMs;
      if (elapsedMs > 0 && elapsedMs < bestMs) bestMs = elapsedMs;
    }

    return bestMs == (1 << 62) ? null : (bestMs / 1000).round();
  }

  static int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstThursdayAdjusted =
        firstThursday.add(Duration(days: 3 - ((firstThursday.weekday + 6) % 7)));
    return 1 + (thursday.difference(firstThursdayAdjusted).inDays / 7).floor();
  }
}

/// Formats seconds as `mm:ss` or `h:mm:ss`.
String formatEffortSeconds(int seconds) {
  if (seconds <= 0) return '--:--';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Scales a weekly distance to a bar height in the range [minHeight, maxHeight].
double weeklyBarHeight(double value, double maxValue, {double minHeight = 8, double maxHeight = 92}) {
  if (maxValue <= 0 || value <= 0) return minHeight;
  return max(minHeight, (value / maxValue) * maxHeight);
}
