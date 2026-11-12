import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rucha_mobile/core/constants.dart';
import 'package:rucha_mobile/models/user.dart';
import 'package:rucha_mobile/models/activity.dart';
import 'package:rucha_mobile/models/legend_ghost.dart';
import 'package:rucha_mobile/services/tracking_service.dart';
import 'package:rucha_mobile/services/smartwatch_service.dart';
import 'package:rucha_mobile/services/auth_service.dart';

void main() {
  test('RUCHA Core constants and Ethiopian cities are configured', () {
    expect(RuchaConstants.cities.containsKey('addis'), isTrue);
    expect(RuchaConstants.cities['addis']!.baseEle, equals(2355));
    expect(RuchaConstants.cities.containsKey('bekoji'), isTrue);
    expect(RuchaConstants.cities['bekoji']!.baseEle, equals(2810));
    expect(RuchaConstants.holidays.isNotEmpty, isTrue);
  });

  test('Haversine distance, pace, and altitude adjustment work correctly', () {
    final d = RuchaConstants.haversineDistance(9.0320, 38.7469, 9.0450, 38.7469);
    expect(d, greaterThan(1000.0)); // > 1 km

    final pace = RuchaConstants.paceFor(5.0, 1500); // 5km in 25 min = 300s/km (5:00/km)
    expect(pace, equals(300.0));
    expect(RuchaConstants.formatPace(pace), equals('05:00'));

    // Sea-level equivalent pace in Addis Ababa (2,355m) should be faster (fewer seconds/km)
    final seaLevelPace = RuchaConstants.seaLevelEquivalentPace(300.0, 2355.0);
    expect(seaLevelPace, lessThan(300.0));
    expect(seaLevelPace, greaterThan(260.0)); // ~4:40/km
  });

  test('TrackingService Kalman filter rejects poor accuracy fixes', () async {
    final tracker = TrackingService()..bypassLocationChecksForTests = true;
    await tracker.startRecording(title: 'Test Run');

    // Add a coarse 2000m fix
    final accepted = tracker.addGpsFix(
      lat: 9.0320,
      lng: 38.7469,
      accuracy: 2000.0,
    );
    expect(accepted, isFalse);
    expect(tracker.track.isEmpty, isTrue);
    expect(tracker.totalDistanceKm, equals(0.0));

    // Add a precise 8m fix
    final accepted2 = tracker.addGpsFix(
      lat: 9.0320,
      lng: 38.7469,
      accuracy: 8.0,
    );
    expect(accepted2, isTrue);
    expect(tracker.track.length, equals(1));

    tracker.dispose();
  });

  test('TrackingService kilometre splits use real elapsed time', () async {
    final tracker = TrackingService()..bypassLocationChecksForTests = true;
    await tracker.startRecording(title: 'Split pacing test');

    const baseTime = 1700000000000;
    const stepLat = 0.0002; // roughly 22 m per fix
    for (var i = 0; i < 200; i++) {
      tracker.addGpsFix(
        lat: 9.0320 + (i * stepLat),
        lng: 38.7469,
        ele: 2355.0,
        accuracy: 5.0,
        timestamp: baseTime + (i * 2000),
      );
      if (tracker.totalDistanceKm > 1.2) break;
    }

    expect(tracker.totalDistanceKm, greaterThan(1.0));
    expect(tracker.splits, isNotEmpty);
    expect(tracker.splits.first.km, equals(1));
    expect(tracker.splits.first.paceSeconds, greaterThan(0));
    // A fixed 300s split would hide the actual elapsed time.
    expect(tracker.splits.first.paceSeconds, lessThan(300));

    tracker.dispose();
  });

  test('AuthService models and phone number validation', () {
    final user = User(
      id: 'usr_123',
      username: 'haile_g',
      displayName: 'Haile Gebrselassie',
      phoneNumber: '+251911234567',
      providers: const ['telegram'],
      createdAt: '2026-11-10T08:00:00Z',
    );
    expect(user.username, equals('haile_g'));
    expect(user.phoneNumber, equals('+251911234567'));
    expect(user.providers.contains('telegram'), isTrue);

    final json = user.toJson();
    final restored = User.fromJson(json);
    expect(restored.id, equals('usr_123'));
    expect(restored.displayName, equals('Haile Gebrselassie'));
    expect(restored.phoneNumber, equals('+251911234567'));
  });

  test('Ghost of Legends benchmarks and delta note calculations', () {
    expect(LegendGhost.all.length, greaterThanOrEqualTo(5));
    final abebe = LegendGhost.all.firstWhere((g) => g.id == 'abebe');
    expect(abebe.name, equals('Abebe Bikila'));
    expect(abebe.targetPaceFormatted, equals('03:12/km'));

    // Test pace delta note
    final noteAhead = abebe.getPaceDeltaNote(180.0); // 3:00/km (faster than 3:12)
    expect(noteAhead.contains('faster than Abebe Bikila'), isTrue);

    final noteBehind = abebe.getPaceDeltaNote(210.0); // 3:30/km (slower than 3:12)
    expect(noteBehind.contains('behind Abebe Bikila'), isTrue);
  });

  test('SmartwatchService virtual simulator and heart rate calculations', () async {
    final watch = SmartwatchService();
    expect(watch.isConnected, isFalse);

    // Toggle simulator mode
    watch.toggleSimulatorMode(true);
    expect(watch.isConnected, isTrue);
    expect(watch.connectedDeviceName?.contains('Wear OS'), isTrue);
    expect(watch.currentBpm, greaterThanOrEqualTo(138));
    expect(watch.avgBpm, greaterThan(0));
    expect(watch.maxBpm, greaterThanOrEqualTo(watch.currentBpm));

    watch.disconnect();
    expect(watch.isConnected, isFalse);
    expect(watch.currentBpm, equals(0));
  });

  test('Activity model serializes and restores heart rate metrics', () {
    final act = Activity(
      id: 'act_hr_123',
      title: 'Entoto Ride',
      type: 'ride',
      distance: 24.5,
      duration: 3600,
      elevation: 480.0,
      pace: 146.9,
      date: DateTime.now(),
      city: 'addis',
      avgHr: 156,
      maxHr: 178,
    );

    final json = act.toJson();
    expect(json['type'], equals('ride'));
    expect(json['avgHr'], equals(156));
    expect(json['maxHr'], equals(178));

    final restored = Activity.fromJson(json);
    expect(restored.type, equals('ride'));
    expect(restored.avgHr, equals(156));
    expect(restored.maxHr, equals(178));
  });

  test('AuthService registers, hashes and verifies a local account', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService(baseUrl: 'http://127.0.0.1:9/api');
    final result = await auth.register(
      'local_runner',
      'Password123',
      'Local Runner',
      phoneNumber: '+251911234567',
    );

    expect(result.success, isTrue);
    expect(result.user, isNotNull);
    expect(result.user!.username, equals('local_runner'));
    expect(result.user!.displayName, equals('Local Runner'));
    expect(result.user!.providers.contains('local'), isTrue);
    expect(result.token?.startsWith('local_'), isTrue);
    expect(auth.canUseApp, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rucha_local_accounts_db_v1');
    expect(raw, isNotNull);
    final db = jsonDecode(raw!) as Map<String, dynamic>;
    final account = db['local_runner'] as Map<String, dynamic>;
    expect(account['password'], isNull);
    expect(account['passwordHash'], isA<String>());
    expect(account['salt'], isA<String>());

    await auth.logout();
    expect(auth.canUseApp, isFalse);

    final login = await auth.login('local_runner', 'Password123');
    expect(login.success, isTrue);
    expect(login.user!.displayName, equals('Local Runner'));

    final wrong = await auth.login('local_runner', 'WrongPassword9');
    expect(wrong.success, isFalse);
    expect(wrong.error, contains('Incorrect password'));
  });
}
