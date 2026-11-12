import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';

/// The best locally recorded effort for one challenge distance.
class ChallengeResult {
  final int bestSeconds;
  final int lastSeconds;
  final int attempts;
  final double targetKm;
  final DateTime? lastAt;

  const ChallengeResult({
    required this.bestSeconds,
    required this.lastSeconds,
    required this.attempts,
    required this.targetKm,
    this.lastAt,
  });

  factory ChallengeResult.fromJson(
    Map<String, dynamic> json, {
    double fallbackTargetKm = 0,
  }) =>
      ChallengeResult(
        bestSeconds: (json['bestSeconds'] as num?)?.toInt() ?? 0,
        lastSeconds: (json['lastSeconds'] as num?)?.toInt() ?? 0,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        targetKm: (json['targetKm'] as num?)?.toDouble() ?? fallbackTargetKm,
        lastAt: json['lastAt'] is String
            ? DateTime.tryParse(json['lastAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'bestSeconds': bestSeconds,
        'lastSeconds': lastSeconds,
        'attempts': attempts,
        'targetKm': targetKm,
        if (lastAt != null) 'lastAt': lastAt!.toIso8601String(),
      };
}

/// Seconds spent covering exactly [targetKm], interpolated between the two GPS
/// fixes that bracket the target so the result is not inflated by the distance
/// overshoot of the last fix.
///
/// [pausedSeconds] is removed because the time trial clock stops while the
/// athlete has paused recording.
int? timeToDistanceSeconds(
  List<TrackPoint> track,
  double targetKm, {
  int pausedSeconds = 0,
}) {
  if (targetKm <= 0 || track.length < 2) return null;
  if (track.last.d + 1e-9 < targetKm) return null;

  var low = 0;
  var high = track.length - 1;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (track[mid].d >= targetKm) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }

  if (low <= 0) return 0;
  final before = track[low - 1];
  final after = track[low];
  final span = after.d - before.d;
  final fraction =
      span > 1e-12 ? ((targetKm - before.d) / span).clamp(0.0, 1.0) : 1.0;
  final targetMs = before.t + ((after.t - before.t) * fraction).round();
  final seconds = ((targetMs - track.first.t) / 1000.0).round() - pausedSeconds;
  return max(0, seconds);
}

/// Seconds spent climbing exactly [targetGainM] metres of positive elevation,
/// interpolated between the fixes that bracket the target.
int? timeToElevationGainSeconds(
  List<TrackPoint> track,
  double targetGainM, {
  int pausedSeconds = 0,
}) {
  if (targetGainM <= 0 || track.length < 2) return null;

  var gain = 0.0;
  for (var i = 1; i < track.length; i++) {
    final step = max(0.0, track[i].ele - track[i - 1].ele);
    if (step <= 0) continue;
    if (gain + step >= targetGainM) {
      final fraction = ((targetGainM - gain) / step).clamp(0.0, 1.0);
      final targetMs =
          track[i - 1].t + ((track[i].t - track[i - 1].t) * fraction).round();
      final seconds =
          ((targetMs - track.first.t) / 1000.0).round() - pausedSeconds;
      return max(0, seconds);
    }
    gain += step;
  }
  return null;
}

/// Stores challenge finishes on the device so a time-trial result survives an
/// app restart. Server-backed challenges also receive a progress post, but the
/// local best is always recorded first.
class ChallengeResultStore {
  static const String _prefsKey = 'rucha_challenge_results_v1';

  /// Results are keyed by challenge and distance: a 1 km best is not
  /// comparable with a 10 km best, and one challenge can host several presets.
  static String keyFor(String challengeId, double targetKm) {
    final label = targetKm == targetKm.roundToDouble()
        ? targetKm.toStringAsFixed(0)
        : targetKm.toStringAsFixed(2);
    return '$challengeId@$label';
  }

  static Future<Map<String, ChallengeResult>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, ChallengeResult>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map) {
          final key = entry.key.toString();
          out[key] = ChallengeResult.fromJson(
            Map<String, dynamic>.from(value),
            fallbackTargetKm: _targetKmFromKey(key),
          );
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Returns the recorded result for one challenge and distance, if any.
  static ChallengeResult? resultFor(
    Map<String, ChallengeResult> all,
    String challengeId,
    double targetKm,
  ) =>
      all[keyFor(challengeId, targetKm)];

  /// Records [seconds] for a challenge distance and returns the updated result.
  static Future<ChallengeResult> record({
    required String challengeId,
    required double targetKm,
    required int seconds,
  }) async {
    final results = await loadAll();
    final key = keyFor(challengeId, targetKm);
    final previous = results[key];
    final best = previous == null || seconds < previous.bestSeconds
        ? seconds
        : previous.bestSeconds;
    final updated = ChallengeResult(
      bestSeconds: best,
      lastSeconds: seconds,
      attempts: (previous?.attempts ?? 0) + 1,
      targetKm: targetKm,
      lastAt: DateTime.now(),
    );
    results[key] = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final entry in results.entries) entry.key: entry.value.toJson(),
        }),
      );
    } catch (_) {
      // A successful run is already saved as an activity; losing the summary
      // must not fail the screen.
    }
    return updated;
  }

  static double _targetKmFromKey(String key) {
    final at = key.lastIndexOf('@');
    if (at < 0) return 0;
    return double.tryParse(key.substring(at + 1)) ?? 0;
  }
}
