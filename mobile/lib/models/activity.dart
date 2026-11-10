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
  final String? ownerId;
  final String? ownerName;

  Activity({
    required this.id,
    required this.title,
    required this.type,
    required this.distance,
    required this.duration,
    required this.elevation,
    required this.pace,
    required this.calories,
    required this.date,
    required this.city,
    required this.track,
    this.splits = const [],
    this.ownerId,
    this.ownerName,
  });

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
    if (ownerId != null) 'ownerId': ownerId,
    if (ownerName != null) 'ownerName': ownerName,
  };

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
    if (json['date'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(json['date'] as int);
    } else if (json['date'] is String) {
      parsedDate = DateTime.tryParse(json['date'] as String) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Activity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Activity',
      type: json['type']?.toString() ?? 'run',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      pace: (json['pace'] as num?)?.toDouble() ?? 0.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      city: json['city']?.toString() ?? 'addis',
      track: trackPoints,
      splits: splitsList,
      ownerId: json['ownerId']?.toString(),
      ownerName: json['ownerName']?.toString(),
    );
  }
}
