import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../core/constants.dart';

enum RecordingStatus { idle, searching, running, paused, finished }
enum GpsQuality { searching, good, ok, weak, coarse, lost }

class TrackingService extends ChangeNotifier {
  RecordingStatus _status = RecordingStatus.idle;
  GpsQuality _gpsQuality = GpsQuality.searching;
  String _activityType = 'run'; // 'run' or 'ride'
  String _activityName = '';
  String _selectedCity = 'addis';

  final List<TrackPoint> _track = [];
  final List<ActivitySplit> _splits = [];
  
  Timer? _ticker;
  DateTime? _startTime;
  int _pausedSecondsTotal = 0;
  DateTime? _pausedAt;
  int _elapsedSeconds = 0;

  double _totalDistanceKm = 0.0;
  double _elevationGain = 0.0;
  double _calories = 0.0;
  double _currentPace = 0.0;
  double? _lastAccuracy;
  String? _gpsWarning;

  // Kalman smoothing variables
  double? _sLat;
  double? _sLng;
  double? _sVar;
  final List<double> _eleBuffer = [];

  // Getters
  RecordingStatus get status => _status;
  GpsQuality get gpsQuality => _gpsQuality;
  String get activityType => _activityType;
  String get activityName => _activityName;
  String get selectedCity => _selectedCity;
  List<TrackPoint> get track => List.unmodifiable(_track);
  List<ActivitySplit> get splits => List.unmodifiable(_splits);
  int get elapsedSeconds => _elapsedSeconds;
  double get totalDistanceKm => _totalDistanceKm;
  double get elevationGain => _elevationGain;
  double get calories => _calories;
  double get currentPace => _currentPace;
  double? get lastAccuracy => _lastAccuracy;
  String? get gpsWarning => _gpsWarning;

  void setActivityType(String type) {
    if (_status == RecordingStatus.idle) {
      _activityType = type;
      notifyListeners();
    }
  }

  void setActivityName(String name) {
    _activityName = name;
    notifyListeners();
  }

  void setCity(String cityId) {
    if (RuchaConstants.cities.containsKey(cityId)) {
      _selectedCity = cityId;
      notifyListeners();
    }
  }

  void startRecording({String? title}) {
    if (_status == RecordingStatus.running) return;

    _status = RecordingStatus.running;
    _activityName = title ?? (activityType == 'run' ? 'Morning Run' : 'Morning Ride');
    _startTime = DateTime.now();
    _pausedSecondsTotal = 0;
    _elapsedSeconds = 0;
    _totalDistanceKm = 0.0;
    _elevationGain = 0.0;
    _calories = 0.0;
    _currentPace = 0.0;
    _track.clear();
    _splits.clear();
    _sLat = null;
    _sLng = null;
    _sVar = null;
    _eleBuffer.clear();
    _gpsWarning = null;

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status == RecordingStatus.running) {
        _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds - _pausedSecondsTotal;
        _currentPace = RuchaConstants.paceFor(_totalDistanceKm, _elapsedSeconds);
        _calories = RuchaConstants.caloriesFor(_totalDistanceKm, _elapsedSeconds, _elevationGain, _activityType);
        notifyListeners();
      }
    });

    notifyListeners();
  }

  void pauseRecording() {
    if (_status == RecordingStatus.running) {
      _status = RecordingStatus.paused;
      _pausedAt = DateTime.now();
      notifyListeners();
    }
  }

  void resumeRecording() {
    if (_status == RecordingStatus.paused) {
      _status = RecordingStatus.running;
      if (_pausedAt != null) {
        _pausedSecondsTotal += DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
      }
      notifyListeners();
    }
  }

  Activity finishRecording() {
    _ticker?.cancel();
    _status = RecordingStatus.finished;

    final act = Activity(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      title: _activityName.isNotEmpty ? _activityName : 'RUCHA ${_activityType.toUpperCase()}',
      type: _activityType,
      distance: _totalDistanceKm,
      duration: _elapsedSeconds,
      elevation: _elevationGain,
      pace: _currentPace,
      calories: _calories,
      date: _startTime ?? DateTime.now(),
      city: _selectedCity,
      track: List.from(_track),
      splits: List.from(_splits),
    );

    notifyListeners();
    return act;
  }

  void reset() {
    _ticker?.cancel();
    _status = RecordingStatus.idle;
    _track.clear();
    _splits.clear();
    _elapsedSeconds = 0;
    _totalDistanceKm = 0.0;
    _elevationGain = 0.0;
    _calories = 0.0;
    _currentPace = 0.0;
    _gpsWarning = null;
    notifyListeners();
  }

  /// Ingests a new GPS fix and processes it through the Kalman filter.
  bool addGpsFix({
    required double lat,
    required double lng,
    double? ele,
    double? accuracy,
    double? speed,
    int? timestamp,
  }) {
    final acc = accuracy ?? 50.0;
    _lastAccuracy = acc;

    // Determine signal quality
    if (acc <= 12) {
      _gpsQuality = GpsQuality.good;
      _gpsWarning = null;
    } else if (acc <= 30) {
      _gpsQuality = GpsQuality.ok;
      _gpsWarning = null;
    } else if (acc <= 60) {
      _gpsQuality = GpsQuality.weak;
      _gpsWarning = 'Weak GPS signal (±${acc.round()}m)';
    } else {
      _gpsQuality = GpsQuality.coarse;
      _gpsWarning = 'Approximate GPS (±${acc.round()}m). Ensure "Precise Location" is enabled.';
    }

    // Drop low accuracy fixes to prevent false speed/distance spikes
    final maxAcc = _activityType == 'ride' ? 50.0 : 45.0;
    if (acc > maxAcc) {
      notifyListeners();
      return false; // Point rejected due to poor accuracy
    }

    if (_status != RecordingStatus.running) {
      notifyListeners();
      return true;
    }

    final t = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    // Kalman Smoothing (weighted process noise)
    final spd = (speed != null && speed > 0) ? speed : 0.0;
    final q = 5.0 + min(10.0, spd * 2.5);
    double smoothedLat = lat;
    double smoothedLng = lng;

    if (_sLat == null || _sLng == null || _sVar == null) {
      _sLat = lat;
      _sLng = lng;
      _sVar = acc * acc;
    } else {
      final prevT = _track.isNotEmpty ? _track.last.t : t;
      final dt = max(0.001, (t - prevT) / 1000.0);
      _sVar = _sVar! + dt * q * q;
      final k = _sVar! / (_sVar! + acc * acc);
      _sLat = _sLat! + k * (lat - _sLat!);
      _sLng = _sLng! + k * (lng - _sLng!);
      _sVar = (1.0 - k) * _sVar!;
      smoothedLat = _sLat!;
      smoothedLng = _sLng!;
    }

    // Median elevation smoothing
    final baseCityEle = (RuchaConstants.cities[_selectedCity] ?? RuchaConstants.cities['addis']!).baseEle;
    final smoothedEle = _smoothElevation(ele ?? baseCityEle);

    // Distance step calculation
    double stepM = 0.0;
    if (_track.isNotEmpty) {
      final lastPt = _track.last;
      stepM = RuchaConstants.haversineDistance(lastPt.lat, lastPt.lng, smoothedLat, smoothedLng);

      // Dead-zone filter for standing still
      final deadZone = max(2.0, min(acc * 0.35, 8.0));
      if (stepM < deadZone) {
        notifyListeners();
        return false; // Standing still
      }

      // Max impossible speed filter
      final dtS = max(0.001, (t - lastPt.t) / 1000.0);
      final maxSpeedAllowed = _activityType == 'ride' ? 25.0 : 12.0; // m/s
      if (stepM / dtS > maxSpeedAllowed) {
        notifyListeners();
        return false; // Spike rejected
      }

      // Elevation gain
      final dEle = smoothedEle - lastPt.ele;
      if (dEle > 0) {
        _elevationGain += dEle;
      }
    }

    _totalDistanceKm += (stepM / 1000.0);

    final pt = TrackPoint(
      lat: smoothedLat,
      lng: smoothedLng,
      ele: smoothedEle,
      d: _totalDistanceKm,
      t: t,
      accuracy: acc,
      speed: speed,
    );
    _track.add(pt);

    // Compute kilometre splits
    _checkSplits();

    notifyListeners();
    return true;
  }

  double _smoothElevation(double ele) {
    _eleBuffer.add(ele);
    if (_eleBuffer.length > 7) _eleBuffer.removeAt(0);
    final sorted = List<double>.from(_eleBuffer)..sort();
    return sorted[sorted.length ~/ 2];
  }

  void _checkSplits() {
    final targetKm = _splits.length + 1;
    if (_totalDistanceKm >= targetKm) {
      final splitPace = RuchaConstants.paceFor(1.0, _elapsedSeconds - (_splits.isEmpty ? 0 : (_splits.length * 300)));
      _splits.add(ActivitySplit(
        km: targetKm,
        paceSeconds: splitPace,
        eleGain: _elevationGain,
      ));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
