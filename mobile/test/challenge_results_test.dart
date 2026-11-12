import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rucha_mobile/models/activity.dart';
import 'package:rucha_mobile/services/challenge_results.dart';

TrackPoint _point({
  required double d,
  required int t,
  double ele = 2355,
}) =>
    TrackPoint(
      lat: 9.032 + d * 0.01,
      lng: 38.7469,
      ele: ele,
      d: d,
      t: 1700000000000 + t * 1000,
      accuracy: 5,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('timeToDistanceSeconds interpolates the exact target crossing', () {
    final track = [
      _point(d: 0, t: 0),
      _point(d: 0.6, t: 300),
      _point(d: 1.05, t: 500),
    ];

    // 1 km sits 0.4/0.45 of the way through the final segment.
    expect(timeToDistanceSeconds(track, 1.0), 478);
    expect(timeToDistanceSeconds(track, 0.5), 250);
    expect(timeToDistanceSeconds(track, 1.5), isNull);
  });

  test('timeToDistanceSeconds removes paused time and ignores overshoot', () {
    final track = [
      _point(d: 0, t: 0),
      _point(d: 1.02, t: 302),
    ];

    expect(timeToDistanceSeconds(track, 1.0, pausedSeconds: 12), 284);
    expect(timeToDistanceSeconds(track, 1.0, pausedSeconds: 0), 296);
  });

  test('timeToElevationGainSeconds interpolates positive gain only', () {
    final track = [
      _point(d: 0, t: 0, ele: 2355),
      _point(d: 0.1, t: 100, ele: 2365),
      _point(d: 0.2, t: 300, ele: 2380),
    ];

    // 20 m of gain is 10/15 through the second climb.
    expect(timeToElevationGainSeconds(track, 20), 233);
    expect(timeToElevationGainSeconds(track, 100), isNull);
  });

  test('ChallengeResultStore keeps the best and last effort per distance',
      () async {
    SharedPreferences.setMockInitialValues({});
    const challengeId = 'ch_time_trial';

    final first = await ChallengeResultStore.record(
      challengeId: challengeId,
      targetKm: 5,
      seconds: 1500,
    );
    expect(first.bestSeconds, 1500);
    expect(first.lastSeconds, 1500);
    expect(first.attempts, 1);

    final second = await ChallengeResultStore.record(
      challengeId: challengeId,
      targetKm: 5,
      seconds: 1620,
    );
    expect(second.bestSeconds, 1500);
    expect(second.lastSeconds, 1620);
    expect(second.attempts, 2);

    final third = await ChallengeResultStore.record(
      challengeId: challengeId,
      targetKm: 5,
      seconds: 1440,
    );
    expect(third.bestSeconds, 1440);
    expect(third.attempts, 3);

    final all = await ChallengeResultStore.loadAll();
    final stored = ChallengeResultStore.resultFor(all, challengeId, 5);
    expect(stored, isNotNull);
    expect(stored!.bestSeconds, 1440);
    expect(stored.targetKm, 5);
    expect(
      ChallengeResultStore.resultFor(all, challengeId, 1),
      isNull,
      reason: 'a 1 km effort is a different record from a 5 km effort',
    );

    // Round-trips through SharedPreferences JSON.
    final reloaded = await ChallengeResultStore.loadAll();
    expect(reloaded[ChallengeResultStore.keyFor(challengeId, 5)]!.attempts, 3);
  });
}
