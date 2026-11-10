import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../core/constants.dart';

enum RecordingStatus { idle, searching, running, paused, finished }
enum GpsQuality { searching, good, ok, weak, coarse, lost }

class TrackingService extends ChangeNotifier {
  static const MethodChannel _gpsControl = MethodChannel('com.rucha.mobile/gps_control');
  static const EventChannel _gpsStream = EventChannel('com.rucha.mobile/gps_stream');

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

  // Real GPS hardware integration
  StreamSubscription? _gpsSubscription;
  bool _hasRealGpsFix = false;
  double? _simLat;
  double? _simLng;
  double? _simEle;
  double _simAngle = 0.0;

  // Kalman smoothing variables
  double? _sLat;
  double? _sLng;
  double? _sVar;
  final List<double> _eleBuffer = [];

  TrackingService() {
    _initGps();
  }

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

  Future<void> _initGps() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await _gpsControl.invokeMethod('requestPermissions');
      }
    } catch (_) {}
  }

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

  Future<void> startRecording({String? title}) async {
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
    _hasRealGpsFix = false;

    final city = RuchaConstants.cities[_selectedCity] ?? RuchaConstants.cities['addis']!;
    _simLat = city.lat;
    _simLng = city.lng;
    _simEle = city.baseEle;

    // Start Real Android GPS hardware listener
    await _startNativeGps();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status == RecordingStatus.running) {
        _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds - _pausedSecondsTotal;
        _currentPace = RuchaConstants.paceFor(_totalDistanceKm, _elapsedSeconds);
        _calories = RuchaConstants.caloriesFor(_totalDistanceKm, _elapsedSeconds, _elevationGain, _activityType);

        // On mobile devices (Android/iOS), NEVER inject synthetic points!
        // Real athletes must strictly record their genuine hardware GPS trail.
        // Only run gentle curved trail simulation on desktop/Linux developer environments without GPS.
        final isMobileDevice = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        if (!isMobileDevice && !_hasRealGpsFix && _elapsedSeconds > 2) {
          _simulateStep();
        }

        notifyListeners();
      }
    });

    notifyListeners();
  }

  Future<void> _startNativeGps() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await _gpsControl.invokeMethod('requestPermissions');
        _gpsSubscription?.cancel();
        _gpsSubscription = _gpsStream.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is Map) {
              _hasRealGpsFix = true;
              final lat = (event['latitude'] as num).toDouble();
              final lng = (event['longitude'] as num).toDouble();
              final ele = (event['altitude'] as num?)?.toDouble();
              final acc = (event['accuracy'] as num?)?.toDouble();
              final spd = (event['speed'] as num?)?.toDouble();
              final ts = (event['timestamp'] as num?)?.toInt();

              addGpsFix(
                lat: lat,
                lng: lng,
                ele: ele,
                accuracy: acc,
                speed: spd,
                timestamp: ts,
              );
            }
          },
          onError: (err) {
            debugPrint('Native GPS stream error: $err');
          },
        );
        await _gpsControl.invokeMethod('startGps');
      }
    } catch (e) {
      debugPrint('Failed to start native GPS: $e');
    }
  }

  void _simulateStep() {
    if (_simLat == null || _simLng == null || _simEle == null) return;
    final speedMps = _activityType == 'ride' ? 6.5 : 3.0; // 3 m/s = 5:33/km
    _simAngle += 0.08; // Natural meandering curve like real trails, never a rigid diagonal
    final deltaLat = (speedMps / 111111.0) * cos(_simAngle);
    final deltaLng = (speedMps / (111111.0 * cos(_simLat! * pi / 180.0))) * sin(_simAngle);

    _simLat = _simLat! + deltaLat;
    _simLng = _simLng! + deltaLng;
    _simEle = _simEle! + sin(_simAngle * 2) * 0.4;

    addGpsFix(
      lat: _simLat!,
      lng: _simLng!,
      ele: _simEle!,
      accuracy: 6.0,
      speed: speedMps,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> pauseRecording() async {
    if (_status == RecordingStatus.running) {
      _status = RecordingStatus.paused;
      _pausedAt = DateTime.now();
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await _gpsControl.invokeMethod('stopGps');
        }
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (_status == RecordingStatus.paused) {
      _status = RecordingStatus.running;
      if (_pausedAt != null) {
        _pausedSecondsTotal += DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
      }
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await _gpsControl.invokeMethod('startGps');
        }
      } catch (_) {}
      notifyListeners();
    }
  }

  Activity finishRecording() {
    _ticker?.cancel();
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        _gpsControl.invokeMethod('stopGps');
      }
    } catch (_) {}

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
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        _gpsControl.invokeMethod('stopGps');
      }
    } catch (_) {}

    _status = RecordingStatus.idle;
    _track.clear();
    _splits.clear();
    _elapsedSeconds = 0;
    _totalDistanceKm = 0.0;
    _elevationGain = 0.0;
    _calories = 0.0;
    _currentPace = 0.0;
    _gpsWarning = null;
    _hasRealGpsFix = false;
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

    // Signal quality assessment
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

    // Drop inaccurate outliers
    final maxAcc = _activityType == 'ride' ? 55.0 : 50.0;
    if (acc > maxAcc) {
      notifyListeners();
      return false;
    }

    if (_status != RecordingStatus.running) {
      notifyListeners();
      return true;
    }

    final t = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    // Kalman Smoothing
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
      final deadZone = max(1.5, min(acc * 0.3, 7.0));
      if (stepM < deadZone) {
        notifyListeners();
        return false;
      }

      // Max speed filter to reject GPS warp spikes
      final dtS = max(0.001, (t - lastPt.t) / 1000.0);
      final maxSpeedAllowed = _activityType == 'ride' ? 30.0 : 14.0; // m/s
      if (stepM / dtS > maxSpeedAllowed) {
        notifyListeners();
        return false;
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
    _gpsSubscription?.cancel();
    super.dispose();
  }
}
