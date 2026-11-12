import '../core/constants.dart';

class TrackPoint {
  final double lat;
  final double lng;
  final double ele;
  final double d; // cumulative distance in km
  final int t;   // timestamp ms
  final double accuracy;
  final double? speed;
  final int? hr;
  final int? cad;
  final int? pw;

  TrackPoint({
    required this.lat,
    required this.lng,
    required this.ele,
    required this.d,
    required this.t,
    required this.accuracy,
    this.speed,
    this.hr,
    this.cad,
    this.pw,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'ele': ele,
    'd': d,
    't': t,
    'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (hr != null) 'hr': hr,
    if (cad != null) 'cad': cad,
    if (pw != null) 'pw': pw,
  };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    ele: (json['ele'] as num?)?.toDouble() ?? 2355.0,
    d: (json['d'] as num?)?.toDouble() ?? 0.0,
    t: json['t'] is int ? json['t'] : (json['t'] as num).toInt(),
    accuracy: (json['accuracy'] as num?)?.toDouble() ?? 5.0,
    speed: (json['speed'] as num?)?.toDouble(),
    hr: json['hr'] as int?,
    cad: json['cad'] as int?,
    pw: json['pw'] as int?,
  );
}

class ActivitySplit {
  final int km;
  final double paceSeconds;
  final double eleGain;

  ActivitySplit({
    required this.km,
    required this.paceSeconds,
    required this.eleGain,
  });

  String get paceFormatted => RuchaConstants.formatPace(paceSeconds);

  Map<String, dynamic> toJson() => {
    'km': km,
    'paceSeconds': paceSeconds,
    'eleGain': eleGain,
  };

  factory ActivitySplit.fromJson(Map<String, dynamic> json) => ActivitySplit(
    km: json['km'] as int,
    paceSeconds: (json['paceSeconds'] as num).toDouble(),
    eleGain: (json['eleGain'] as num).toDouble(),
  );
}

class Activity {
  final String id;
  final String title;
  final String type; // 'run' or 'ride'
  final double distance; // in km
  final int duration;   // in seconds
  final double elevation; // in meters
  final double pace;    // seconds per km
  final double calories;
  final DateTime date;
  final String city;
  final List<TrackPoint> track;
  final List<ActivitySplit> splits;
  final int? avgHr;
  final int? maxHr;
  final String? ownerId;
  final String? ownerName;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final double avgGpsAccuracyM;

  Activity({
    required this.id,
    required this.title,
    this.type = 'run',
    required this.distance,
    required this.duration,
    required this.elevation,
    required this.pace,
    this.calories = 0.0,
    required this.date,
    required this.city,
    this.track = const [],
    this.splits = const [],
    this.avgHr,
    this.maxHr,
    this.ownerId,
    this.ownerName,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.avgGpsAccuracyM = 0.0,
  });

  double? get effectiveStartLat => startLat ?? (track.isNotEmpty ? track.first.lat : null);
  double? get effectiveStartLng => startLng ?? (track.isNotEmpty ? track.first.lng : null);
  double? get effectiveEndLat => endLat ?? (track.isNotEmpty ? track.last.lat : null);
  double? get effectiveEndLng => endLng ?? (track.isNotEmpty ? track.last.lng : null);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'distance': distance,
    'duration': duration,
    'elevation': elevation,
    'pace': pace,
    'calories': calories,
    'date': date.millisecondsSinceEpoch,
    'city': city,
    'track': track.map((p) => p.toJson()).toList(),
    'splits': splits.map((s) => s.toJson()).toList(),
    if (avgHr != null) 'avgHr': avgHr,
    if (maxHr != null) 'maxHr': maxHr,
    if (ownerId != null) 'ownerId': ownerId,
    if (ownerName != null) 'ownerName': ownerName,
    if (startLat != null) 'startLat': startLat,
    if (startLng != null) 'startLng': startLng,
    if (endLat != null) 'endLat': endLat,
    if (endLng != null) 'endLng': endLng,
    if (avgGpsAccuracyM > 0) 'gpsAccuracyM': avgGpsAccuracyM,
  };

  /// The payload accepted by the RUCHA server. It differs from local storage:
  /// the server uses distanceKm/durationSec/elevationGainM and real
  /// start/end coordinates, which power automatic popular-area clustering.
  Map<String, dynamic> toServerJson({
    String athleteId = '',
    String athleteName = '',
    String visibility = 'private',
  }) {
    final first = track.isNotEmpty ? track.first : null;
    final last = track.isNotEmpty ? track.last : null;
    final sLat = startLat ?? first?.lat ?? 0;
    final sLng = startLng ?? first?.lng ?? 0;
    final eLat = endLat ?? last?.lat ?? sLat;
    final eLng = endLng ?? last?.lng ?? sLng;
    return {
      'id': id,
      'title': title,
      'type': type,
      'athleteId': athleteId,
      'athleteName': athleteName.isNotEmpty ? athleteName : (ownerName ?? 'RUCHA athlete'),
      'city': city,
      'startLat': sLat,
      'startLng': sLng,
      'endLat': eLat,
      'endLng': eLng,
      'distanceKm': distance,
      'durationSec': duration,
      'paceSecPerKm': pace,
      'elevationGainM': elevation.round(),
      'calories': calories.round(),
      'avgHr': avgHr,
      'hrSource': avgHr == null ? 'none' : 'Bluetooth HR',
      if (maxHr != null) 'maxHr': maxHr,
      'gpsAccuracyM': avgGpsAccuracyM,
      'source': 'gps',
      'track': track
          .map((p) => {
                'lat': p.lat,
                'lng': p.lng,
                'ele': p.ele,
                'd': p.d,
                't': p.t,
                'accuracy': p.accuracy,
                if (p.hr != null) 'hr': p.hr,
                if (p.cad != null) 'cad': p.cad,
                if (p.pw != null) 'pw': p.pw,
              })
          .toList(),
      'startedAt': date.toUtc().toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      if (ownerId != null) 'ownerId': ownerId,
      if (ownerName != null) 'ownerName': ownerName,
      'visibility': visibility,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    var rawTrack = json['track'];
    List<TrackPoint> trackPoints = [];
    if (rawTrack is List) {
      trackPoints = rawTrack.map((p) => TrackPoint.fromJson(p as Map<String, dynamic>)).toList();
    }

    var rawSplits = json['splits'];
    List<ActivitySplit> splitsList = [];
    if (rawSplits is List) {
      splitsList = rawSplits.map((s) => ActivitySplit.fromJson(s as Map<String, dynamic>)).toList();
    }

    DateTime parsedDate;
    final rawDate = json['date'] ?? json['startedAt'] ?? json['createdAt'];
    if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Activity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Activity',
      type: json['type']?.toString() ?? 'run',
      distance: (json['distance'] as num?)?.toDouble() ??
          (json['distanceKm'] as num?)?.toDouble() ??
          0.0,
      duration: (json['duration'] as num?)?.toInt() ??
          (json['durationSec'] as num?)?.toInt() ??
          0,
      elevation: (json['elevation'] as num?)?.toDouble() ??
          (json['elevationGainM'] as num?)?.toDouble() ??
          0.0,
      pace: (json['pace'] as num?)?.toDouble() ??
          (json['paceSecPerKm'] as num?)?.toDouble() ??
          0.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      city: json['city']?.toString() ?? 'addis',
      track: trackPoints,
      splits: splitsList,
      avgHr: (json['avgHr'] as num?)?.toInt(),
      maxHr: (json['maxHr'] as num?)?.toInt(),
      ownerId: json['ownerId']?.toString(),
      ownerName: json['ownerName']?.toString(),
      startLat: (json['startLat'] as num?)?.toDouble() ??
          (trackPoints.isNotEmpty ? trackPoints.first.lat : null),
      startLng: (json['startLng'] as num?)?.toDouble() ??
          (trackPoints.isNotEmpty ? trackPoints.first.lng : null),
      endLat: (json['endLat'] as num?)?.toDouble() ??
          (trackPoints.isNotEmpty ? trackPoints.last.lat : null),
      endLng: (json['endLng'] as num?)?.toDouble() ??
          (trackPoints.isNotEmpty ? trackPoints.last.lng : null),
      avgGpsAccuracyM: (json['gpsAccuracyM'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
