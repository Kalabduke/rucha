import 'dart:math';

class City {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double baseEle;
  final double eleSlope;
  final String tag;

  const City({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.baseEle,
    required this.eleSlope,
    required this.tag,
  });
}

class RuchaConstants {
  static const String appName = 'RUCHA';
  static const String defaultApiUrl = 'https://rucha-api.onrender.com/api';

  // 8 Ethiopian cities
  static const Map<String, City> cities = {
    'addis': City(
        id: 'addis',
        name: 'Addis Ababa',
        lat: 9.0320,
        lng: 38.7469,
        baseEle: 2355,
        eleSlope: 92,
        tag: 'Capital · 2,355 m'),
    'entoto': City(
        id: 'entoto',
        name: 'Entoto Hills',
        lat: 9.1050,
        lng: 38.7520,
        baseEle: 2980,
        eleSlope: 60,
        tag: 'High-altitude trails'),
    'bishoftu': City(
        id: 'bishoftu',
        name: 'Bishoftu',
        lat: 8.7380,
        lng: 38.9850,
        baseEle: 1900,
        eleSlope: 18,
        tag: 'Crater lakes'),
    'hawassa': City(
        id: 'hawassa',
        name: 'Hawassa',
        lat: 7.0621,
        lng: 38.4765,
        baseEle: 1708,
        eleSlope: 14,
        tag: 'Lakeside'),
    'bahirdar': City(
        id: 'bahirdar',
        name: 'Bahir Dar',
        lat: 11.5742,
        lng: 37.3614,
        baseEle: 1800,
        eleSlope: 12,
        tag: 'Lake Tana'),
    'gondar': City(
        id: 'gondar',
        name: 'Gondar',
        lat: 12.6075,
        lng: 37.4660,
        baseEle: 2133,
        eleSlope: 45,
        tag: 'Royal enclosure'),
    'mekelle': City(
        id: 'mekelle',
        name: 'Mekelle',
        lat: 13.4967,
        lng: 39.4753,
        baseEle: 2084,
        eleSlope: 35,
        tag: 'Northern highlands'),
    'harar': City(
        id: 'harar',
        name: 'Harar Jugol',
        lat: 9.3149,
        lng: 42.1288,
        baseEle: 1885,
        eleSlope: 28,
        tag: 'Walled historic city'),
    'bekoji': City(
        id: 'bekoji',
        name: 'Bekoji',
        lat: 7.5333,
        lng: 39.2500,
        baseEle: 2810,
        eleSlope: 45,
        tag: 'Town of Runners · 2,810m'),
    'sululta': City(
        id: 'sululta',
        name: 'Sululta',
        lat: 9.1833,
        lng: 38.7500,
        baseEle: 2750,
        eleSlope: 30,
        tag: 'National Distance Camp · 2,750m'),
  };

  // 14 Ethiopian Holidays
  static const List<Map<String, String>> holidays = [
    {
      'name': 'Enkutatash (Ethiopian New Year)',
      'date': 'Sep 11',
      'desc': 'Meskerem 1 · Spring bloom & fresh start'
    },
    {
      'name': 'Finding of the True Cross (Meskel)',
      'date': 'Sep 27',
      'desc': 'Demera bonfires across Meskel Square'
    },
    {
      'name': 'Genna (Ethiopian Christmas)',
      'date': 'Jan 7',
      'desc': 'Tahsas 29 · Traditional Genna games'
    },
    {
      'name': 'Timkat (Epiphany)',
      'date': 'Jan 19',
      'desc': 'Tabot processions and water blessings'
    },
    {
      'name': 'Adwa Victory Day',
      'date': 'Mar 2',
      'desc': 'Commemorating the 1896 battle victory'
    },
    {
      'name': 'Siklet (Good Friday)',
      'date': 'Apr 25',
      'desc': 'Day of fasting and reflection'
    },
    {
      'name': 'Fasika (Easter)',
      'date': 'Apr 27',
      'desc': 'Celebration ending the 55-day fast'
    },
    {
      'name': 'Patriots Victory Day',
      'date': 'May 5',
      'desc': 'Liberation of Addis Ababa 1941'
    },
    {'name': 'Martyrs Day', 'date': 'Feb 19', 'desc': 'Yekatit 12 memorial'},
  ];

  // Mathematical & Geo Helpers
  static const double earthRadiusMeters = 6371008.8;

  static double haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLng = (lng2 - lng1) * (pi / 180.0);
    final la1 = lat1 * (pi / 180.0);
    final la2 = lat2 * (pi / 180.0);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(min(1.0, sqrt(a)));
    return earthRadiusMeters * c;
  }

  static double paceFor(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0.001 || durationSeconds <= 0) return 0.0;
    return durationSeconds / distanceKm; // seconds per km
  }

  static String formatPace(double paceSecondsPerKm) {
    if (paceSecondsPerKm <= 0 || paceSecondsPerKm > 3600) return '--:--';
    final m = (paceSecondsPerKm / 60).floor();
    final s = (paceSecondsPerKm % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static double caloriesFor(
      double distanceKm, int durationSeconds, double elevGain, String type) {
    if (distanceKm <= 0) return 0.0;
    final factor = type == 'ride' ? 32.0 : 64.0;
    final elevBonus = elevGain * 0.12;
    return max(0.0, (distanceKm * factor) + elevBonus);
  }

  /// Calculates the sea-level equivalent pace (seconds/km) using the Bassett / Daniels high-altitude VO2 model.
  /// Running at 2,400m+ in Ethiopia incurs a ~6% to 11% aerobic penalty.
  static double seaLevelEquivalentPace(
      double paceSeconds, double altitudeMeters) {
    if (paceSeconds <= 0 || altitudeMeters <= 500) return paceSeconds;
    // Beyond 1500m, pace slows roughly 0.065% per 100m
    final excessAlt = max(0.0, altitudeMeters - 1500.0);
    final altitudePenaltyFactor = 1.0 +
        (excessAlt / 100.0) * 0.0075 +
        (min(1500.0, altitudeMeters) / 100.0) * 0.002;
    return paceSeconds / altitudePenaltyFactor;
  }

  // Authentic Ethiopian Kudos / Cheers
  static const List<Map<String, String>> kudosCheers = [
    {'en': 'Keep Pushing!'},
    {'en': 'Warrior!'},
    {'en': 'Stay Strong!'},
    {'en': 'Fast Pace!'},
  ];
}
