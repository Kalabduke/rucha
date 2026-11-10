import 'package:flutter_test/flutter_test.dart';
import 'package:rucha_mobile/core/constants.dart';
import 'package:rucha_mobile/models/user.dart';
import 'package:rucha_mobile/models/legend_ghost.dart';
import 'package:rucha_mobile/services/tracking_service.dart';

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

  test('TrackingService Kalman filter rejects poor accuracy fixes', () {
    final tracker = TrackingService();
    tracker.startRecording(title: 'Test Run');

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
    expect(abebe.amharicName, equals('አበበ ቢቂላ'));
    expect(abebe.targetPaceFormatted, equals('03:12/km'));

    // Test pace delta note
    final noteAhead = abebe.getPaceDeltaNote(180.0); // 3:00/km (faster than 3:12)
    expect(noteAhead.contains('faster than Abebe Bikila'), isTrue);

    final noteBehind = abebe.getPaceDeltaNote(210.0); // 3:30/km (slower than 3:12)
    expect(noteBehind.contains('behind Abebe Bikila'), isTrue);
  });
}
