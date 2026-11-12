import '../core/constants.dart';
import 'activity.dart';

/// A training area discovered automatically from activity start points.
///
/// The server clusters starts within 500 metres and names the cluster after the
/// closest well-known landmark, so the coordinates always point at a real place
/// athletes can navigate to.
class PopularArea {
  final double lat;
  final double lng;
  final int runCount;
  final String name;
  final String city;

  const PopularArea({
    required this.lat,
    required this.lng,
    required this.runCount,
    required this.name,
    required this.city,
  });

  String get key => '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  String get coordinates =>
      '${lat.abs().toStringAsFixed(5)}° ${lat >= 0 ? 'N' : 'S'}, '
      '${lng.abs().toStringAsFixed(5)}° ${lng >= 0 ? 'E' : 'W'}';

  String get googleMapsDirectionsUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';

  String get googleMapsSearchUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  factory PopularArea.fromJson(Map<String, dynamic> json) => PopularArea(
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        runCount: (json['runCount'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString().trim().isNotEmpty == true
            ? json['name'].toString()
            : 'Training area',
        city: json['city']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'runCount': runCount,
        'name': name,
        'city': city,
      };

  double distanceFromMeters(double? fromLat, double? fromLng) {
    if (fromLat == null || fromLng == null) return 0;
    return RuchaConstants.haversineDistance(fromLat, fromLng, lat, lng);
  }
}

class _Landmark {
  final String name;
  final double lat;
  final double lng;
  final String city;

  const _Landmark(this.name, this.lat, this.lng, this.city);
}

/// Mirrors the server's 500 m clustering so recorded activities still produce
/// honest popular areas when the API is unreachable or the athlete is a guest.
class PopularAreaBuilder {
  static const double clusterRadiusMeters = 500;
  static const double landmarkRadiusMeters = 2500;

  static const List<_Landmark> _landmarks = [
    // ── Addis Ababa ──────────────────────────────────────────────────────────
    _Landmark('Meskel Square', 9.00490, 38.76380, 'Addis Ababa'),
    _Landmark('Unity Park (Jubilee Palace)', 9.01757, 38.74818, 'Addis Ababa'),
    _Landmark('Africa Hall / UNECA', 9.01520, 38.76110, 'Addis Ababa'),
    _Landmark('Addis Ababa University', 9.04720, 38.76370, 'Addis Ababa'),
    _Landmark('National Museum', 9.03810, 38.76170, 'Addis Ababa'),
    _Landmark('Mercato (Addis Ketema)', 9.03000, 38.73680, 'Addis Ababa'),
    _Landmark('Piassa', 9.03660, 38.74990, 'Addis Ababa'),
    _Landmark('Kazanchis', 9.01920, 38.76150, 'Addis Ababa'),
    _Landmark('Megenagna', 9.02450, 38.80100, 'Addis Ababa'),
    _Landmark('Bole International Airport', 8.97791, 38.79931, 'Addis Ababa'),
    _Landmark('Friendship Park (Lafto)', 8.98100, 38.73950, 'Addis Ababa'),
    _Landmark('Saris / Kaliti', 8.95710, 38.74140, 'Addis Ababa'),
    _Landmark('Ayat Residential Area', 9.01920, 38.84440, 'Addis Ababa'),
    _Landmark('Sarbet / Lideta', 9.00430, 38.75000, 'Addis Ababa'),
    _Landmark('Aware / CMC', 9.04370, 38.81210, 'Addis Ababa'),
    _Landmark('Sidist Kilo', 9.04720, 38.76370, 'Addis Ababa'),
    // ── Entoto Hills ─────────────────────────────────────────────────────────
    _Landmark('Entoto Maryam Church', 9.11290, 38.75450, 'Entoto Hills'),
    _Landmark('Entoto Natural Park Gate', 9.09430, 38.75480, 'Entoto Hills'),
    _Landmark('Mount Entoto Summit', 9.12050, 38.74990, 'Entoto Hills'),
    // ── Other cities ─────────────────────────────────────────────────────────
    _Landmark('Lake Bishoftu', 8.75910, 38.99590, 'Bishoftu'),
    _Landmark('Hawassa Lakeside Promenade', 7.05890, 38.47010, 'Hawassa'),
    _Landmark('Lake Tana Shore', 11.59640, 37.37250, 'Bahir Dar'),
    _Landmark('Fasil Ghebbi (Gondar Castle)', 12.60350, 37.46760, 'Gondar'),
    _Landmark('Harar Jugol (Old Town)', 9.31390, 42.11810, 'Harar'),
    _Landmark('Mekelle Central Market', 13.49150, 39.47490, 'Mekelle'),
  ];

  static List<PopularArea> clusterActivities(List<Activity> activities) {
    final starts = <({double lat, double lng})>[];
    for (final activity in activities) {
      final lat = activity.effectiveStartLat;
      final lng = activity.effectiveStartLng;
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      starts.add((lat: lat, lng: lng));
    }

    final used = List<bool>.filled(starts.length, false);
    final areas = <PopularArea>[];
    for (var i = 0; i < starts.length; i++) {
      if (used[i]) continue;
      used[i] = true;
      final cluster = <({double lat, double lng})>[starts[i]];
      for (var j = i + 1; j < starts.length; j++) {
        if (used[j]) continue;
        final d = RuchaConstants.haversineDistance(
          starts[i].lat,
          starts[i].lng,
          starts[j].lat,
          starts[j].lng,
        );
        if (d <= clusterRadiusMeters) {
          used[j] = true;
          cluster.add(starts[j]);
        }
      }

      var latSum = 0.0;
      var lngSum = 0.0;
      for (final point in cluster) {
        latSum += point.lat;
        lngSum += point.lng;
      }
      final lat = latSum / cluster.length;
      final lng = lngSum / cluster.length;
      final named = _nameFor(lat, lng);
      areas.add(PopularArea(
        lat: double.parse(lat.toStringAsFixed(5)),
        lng: double.parse(lng.toStringAsFixed(5)),
        runCount: cluster.length,
        name: named.$1,
        city: named.$2,
      ));
    }

    areas.sort((a, b) {
      if (a.runCount == b.runCount) return a.name.compareTo(b.name);
      return b.runCount.compareTo(a.runCount);
    });
    return areas.length > 12 ? areas.sublist(0, 12) : areas;
  }

  static (String, String) _nameFor(double lat, double lng) {
    var best = double.infinity;
    String name = '';
    String city = '';
    for (final landmark in _landmarks) {
      final d = RuchaConstants.haversineDistance(
          lat, lng, landmark.lat, landmark.lng);
      if (d < best) {
        best = d;
        name = landmark.name;
        city = landmark.city;
      }
    }
    if (best <= landmarkRadiusMeters && name.isNotEmpty) {
      return (name, city);
    }

    var bestCityDistance = double.infinity;
    for (final candidate in RuchaConstants.cities.values) {
      final d = RuchaConstants.haversineDistance(
          lat, lng, candidate.lat, candidate.lng);
      if (d < bestCityDistance) {
        bestCityDistance = d;
        city = candidate.name;
      }
    }
    if (bestCityDistance <= 40000 && city.isNotEmpty) {
      return ('$city training area', city);
    }
    return ('Training area', '');
  }

  /// Combines server-discovered areas with local guest recordings without
  /// duplicating the same 500 m cluster.
  static List<PopularArea> merge(
      List<PopularArea> remote, List<PopularArea> local) {
    final out = List<PopularArea>.from(remote);
    for (final area in local) {
      final duplicate = out.any((existing) =>
          RuchaConstants.haversineDistance(
              existing.lat, existing.lng, area.lat, area.lng) <=
          clusterRadiusMeters);
      if (!duplicate) out.add(area);
    }
    out.sort((a, b) {
      if (a.runCount == b.runCount) return a.name.compareTo(b.name);
      return b.runCount.compareTo(a.runCount);
    });
    return out.length > 12 ? out.sublist(0, 12) : out;
  }
}
