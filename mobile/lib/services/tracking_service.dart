import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';
import '../models/activity.dart';

enum RecordingStatus { idle, searching, running, paused, finished }

enum GpsQuality { searching, good, ok, weak, coarse, lost }

/// Records real device GPS fixes through the `geolocator` plugin.
///
/// The service owns the whole lifecycle: it asks for permission when recording
/// starts, refuses to silently record a session without a GPS fix, keeps the
/// stream alive while the phone is locked (Android foreground service / iOS
/// background location), and stops it on pause, finish and reset.
class TrackingService extends ChangeNotifier {
  RecordingStatus _status = RecordingStatus.idle;
  GpsQuality _gpsQuality = GpsQuality.searching;
  String _activityType = 'run'; // 'run' or 'ride'
  String _activityName = '';
  String _selectedCity = 'addis';

  final List<TrackPoint> _track = [];
  final List<ActivitySplit> _splits = [];

  TrackingService() {
    // Pre-warm GPS immediately so the first position arrives before the
    // user ever opens the Record tab.
    warmUp();
  }

  Timer? _ticker;
  DateTime? _startTime;
  int _pausedSecondsTotal = 0;
  DateTime? _pausedAt;
  int _elapsedSeconds = 0;

  double _totalDistanceKm = 0.0;
  double _elevationGain = 0.0;
  double _calories = 0.0;
  double _currentPace = 0.0;
  double _smoothedSpeedKmh = 0.0; // Google-Maps-style smoothed speed
  int? _currentHr;
  double? _lastAccuracy;
  String? _gpsWarning;
  int? _lastSplitTimeMs;
  double _lastSplitElevationGain = 0.0;

  // Rolling window for speed smoothing (last 5 fixes, weighted toward recent)
  final List<double> _speedWindowMs = []; // metres per second per fix

  StreamSubscription<Position>? _gpsSubscription;
  TrackPoint? _previewPoint;
  bool _permissionDenied = false;
  bool _serviceDisabled = false;

  /// Unit tests run without platform location services. This bypasses only the
  /// OS permission/service gate; all filtering and recording maths stay real.
  @visibleForTesting
  bool bypassLocationChecksForTests = false;

  // Kalman smoothing state.
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

  /// Total whole seconds spent paused in the current session. Used by
  /// challenge time trials to keep the race clock honest.
  int get pausedSecondsTotal {
    var paused = _pausedSecondsTotal;
    if (_status == RecordingStatus.paused && _pausedAt != null) {
      paused += DateTime.now().difference(_pausedAt!).inSeconds;
    }
    return paused;
  }

  double get totalDistanceKm => _totalDistanceKm;
  double get elevationGain => _elevationGain;
  double get calories => _calories;
  double get currentPace => _currentPace;
  int? get currentHr => _currentHr;

  /// Smoothed speed in km/h using a weighted rolling window — identical to
  /// the technique Google Maps Navigation uses so the display doesn't flicker.
  double get currentSpeedKmh => _smoothedSpeedKmh;

  /// Instantaneous pace from the smoothed speed (seconds per km).
  /// Falls back to overall session pace when speed is zero.
  double get smoothedPace {
    if (_smoothedSpeedKmh > 0.5) {
      return 3600.0 / _smoothedSpeedKmh; // seconds per km
    }
    return _currentPace;
  }

  double? get lastAccuracy => _lastAccuracy;
  String? get gpsWarning => _gpsWarning;
  bool get permissionDenied => _permissionDenied;
  bool get locationServiceDisabled => _serviceDisabled;

  /// Last known/best fix. Used to center the map before the first recorded
  /// point arrives; it is never added to the activity track.
  TrackPoint? get previewPosition =>
      _track.isNotEmpty ? _track.last : _previewPoint;

  void setCurrentHeartRate(int? hr) {
    _currentHr = hr;
    notifyListeners();
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

  /// Picks the nearest city from [RuchaConstants.cities] given a GPS coordinate.
  /// Only updates if the nearest city is within 80 km (keeps "Addis Ababa" as the
  /// default when the device has no fix or is outside Ethiopia).
  void _autoDetectCity(double lat, double lng) {
    var bestId = _selectedCity;
    var bestDist = double.infinity;
    for (final entry in RuchaConstants.cities.entries) {
      final d = RuchaConstants.haversineDistance(
          lat, lng, entry.value.lat, entry.value.lng);
      if (d < bestDist) {
        bestDist = d;
        bestId = entry.key;
      }
    }
    if (bestDist <= 80000 && bestId != _selectedCity) {
      _selectedCity = bestId;
      notifyListeners();
    }
  }

  /// Warms up GPS: requests permission if needed, seeds the map with the last
  /// known fix, and starts a low-power background position stream so the map
  /// always shows the real location even before recording starts.
  Future<void> warmUp() async {
    if (kIsWeb) return;
    try {
      var permission = await Geolocator.checkPermission();

      // Request permission proactively — this is the core feature
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        _gpsWarning =
            'Location permission is blocked. Open Settings → Apps → RUCHA → Permissions and allow location.';
        notifyListeners();
        return;
      }

      if (permission == LocationPermission.denied) {
        _permissionDenied = true;
        _gpsWarning =
            'Location permission was denied. RUCHA needs GPS to record your route.';
        notifyListeners();
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        _serviceDisabled = true;
        _gpsWarning =
            'Location services are off. Turn on GPS in your device settings.';
        notifyListeners();
        return;
      }

      // Clear any stale warnings
      _permissionDenied = false;
      _serviceDisabled = false;
      _gpsWarning = null;

      // Seed immediately from last known position
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _previewPoint = _toTrackPoint(last);
        _autoDetectCity(last.latitude, last.longitude);
      }
      notifyListeners();

      // Start a low-power background stream so the map dot updates live
      // even before the user taps Start Recording.
      _startPreviewStream();
    } catch (e) {
      debugPrint('Location warm-up failed: $e');
    }
  }

  StreamSubscription<Position>? _previewSubscription;

  /// Low-power stream — updates every ~5 seconds, only while idle.
  /// Stops automatically when recording starts (the recording stream takes over).
  void _startPreviewStream() {
    if (_previewSubscription != null) return; // already running
    if (_status != RecordingStatus.idle) return;
    try {
      final settings = kIsWeb
          ? const LocationSettings(accuracy: LocationAccuracy.low)
          : (Platform.isAndroid
              ? AndroidSettings(
                  accuracy: LocationAccuracy.medium,
                  distanceFilter: 10,
                  intervalDuration: const Duration(seconds: 5),
                )
              : const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  distanceFilter: 10,
                ));
      _previewSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (pos) {
          if (_status == RecordingStatus.idle) {
            _previewPoint = _toTrackPoint(pos);
            _autoDetectCity(pos.latitude, pos.longitude);
            notifyListeners();
          } else {
            // Recording started — shut down preview stream
            _stopPreviewStream();
          }
        },
        onError: (_) => _stopPreviewStream(),
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void _stopPreviewStream() {
    _previewSubscription?.cancel();
    _previewSubscription = null;
  }

  /// Starts a real recording. Returns false when permission or the system
  /// location service is unavailable, in which case the status returns to idle
  /// instead of pretending a run is being recorded.
  Future<bool> startRecording({String? title}) async {
    if (_status == RecordingStatus.running ||
        _status == RecordingStatus.paused ||
        _status == RecordingStatus.searching) {
      return false;
    }

    _status = RecordingStatus.searching;
    _gpsWarning = null;
    _permissionDenied = false;
    _serviceDisabled = false;
    notifyListeners();

    if (!bypassLocationChecksForTests && !await _ensureLocationReady()) {
      _status = RecordingStatus.idle;
      notifyListeners();
      return false;
    }

    _resetSessionState();
    _activityName = title ??
        (activityType == 'run'
            ? 'Morning Run'
            : activityType == 'walk'
                ? 'Morning Walk'
                : 'Morning Ride');
    _startTime = DateTime.now();
    _status = RecordingStatus.running;
    _gpsQuality = GpsQuality.searching;

    if (!bypassLocationChecksForTests) {
      _startGpsStream();
    }
    _startTicker();
    notifyListeners();
    return true;
  }

  Future<bool> _ensureLocationReady() async {
    if (kIsWeb) {
      _gpsWarning = 'Live GPS recording is available in the RUCHA mobile app.';
      return false;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _permissionDenied = true;
        _gpsWarning =
            'Location permission was denied. RUCHA needs precise location to record your route.';
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        _gpsWarning =
            'Location permission is blocked. Open Settings → Apps → RUCHA → Permissions and allow precise location.';
        return false;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        _serviceDisabled = true;
        _gpsWarning =
            'Location services are turned off. Turn on GPS / Location in your device settings, then try again.';
        return false;
      }

      // Seed the map with the most recent known fix. It is a preview only and
      // is not counted as activity distance.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final age = DateTime.now().difference(last.timestamp).abs();
        if (age.inMinutes <= 30) {
          _previewPoint = _toTrackPoint(last);
          _autoDetectCity(last.latitude, last.longitude);
        }
      }
      return true;
    } on LocationServiceDisabledException {
      _serviceDisabled = true;
      _gpsWarning =
          'Location services are turned off. Turn on GPS / Location in your device settings, then try again.';
      return false;
    } catch (e) {
      _gpsWarning = 'Could not start GPS: $e';
      return false;
    }
  }

  LocationSettings _locationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'RUCHA is recording your activity',
          notificationText:
              'Your GPS route keeps recording while the screen is off.',
          notificationChannelName: 'RUCHA activity tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  void _startGpsStream() {
    _gpsSubscription?.cancel();
    try {
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(
        _onPosition,
        onError: _onGpsError,
        cancelOnError: false,
      );
    } catch (e) {
      _onGpsError(e);
    }
  }

  void _onPosition(Position position) {
    _previewPoint = _toTrackPoint(position);
    _autoDetectCity(position.latitude, position.longitude);
    addGpsFix(
      lat: position.latitude,
      lng: position.longitude,
      ele: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed,
      timestamp: position.timestamp.millisecondsSinceEpoch,
    );
  }

  void _onGpsError(Object error) {
    debugPrint('GPS stream error: $error');
    if (error is LocationServiceDisabledException) {
      _serviceDisabled = true;
      _gpsQuality = GpsQuality.lost;
      _gpsWarning =
          'GPS was turned off. Turn location back on to continue recording your route.';
    } else {
      _gpsQuality = GpsQuality.lost;
      _gpsWarning =
          'GPS signal lost. Move to an open area and keep the app running.';
    }
    notifyListeners();
  }

  TrackPoint _toTrackPoint(Position position) {
    return TrackPoint(
      lat: position.latitude,
      lng: position.longitude,
      ele: position.altitude,
      d: _totalDistanceKm,
      t: position.timestamp.millisecondsSinceEpoch,
      accuracy: position.accuracy,
      speed: position.speed,
      hr: _currentHr,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status != RecordingStatus.running || _startTime == null) return;
      _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds -
          _pausedSecondsTotal;
      _currentPace = RuchaConstants.paceFor(_totalDistanceKm, _elapsedSeconds);
      _calories = RuchaConstants.caloriesFor(
        _totalDistanceKm,
        _elapsedSeconds,
        _elevationGain,
        _activityType,
      );
      notifyListeners();
    });
  }

  Future<void> pauseRecording() async {
    if (_status != RecordingStatus.running) return;
    _status = RecordingStatus.paused;
    _pausedAt = DateTime.now();
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    if (_status != RecordingStatus.paused) return;
    _status = RecordingStatus.running;
    if (_pausedAt != null) {
      _pausedSecondsTotal += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    _gpsQuality = GpsQuality.searching;
    _startGpsStream();
    notifyListeners();
  }

  Activity finishRecording() {
    _ticker?.cancel();
    _ticker = null;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    final finishedAt = DateTime.now();
    _status = RecordingStatus.finished;

    int? avgHr;
    int? maxHr;
    final hrs = _track.map((p) => p.hr).whereType<int>().toList();
    if (hrs.isNotEmpty) {
      avgHr = (hrs.reduce((a, b) => a + b) / hrs.length).round();
      maxHr = hrs.reduce(max);
    } else if (_currentHr != null && _currentHr! > 0) {
      avgHr = _currentHr;
      maxHr = _currentHr;
    }

    final accuracies =
        _track.map((p) => p.accuracy).where((a) => a > 0).toList();
    final avgAccuracy = accuracies.isEmpty
        ? 0.0
        : accuracies.reduce((a, b) => a + b) / accuracies.length;

    final act = Activity(
      id: 'act_${finishedAt.millisecondsSinceEpoch}',
      title: _activityName.isNotEmpty
          ? _activityName
          : 'RUCHA ${_activityType.toUpperCase()}',
      type: _activityType,
      distance: _totalDistanceKm,
      duration: _elapsedSeconds,
      elevation: _elevationGain,
      pace: _currentPace,
      calories: _calories,
      date: _startTime ?? finishedAt,
      city: _selectedCity,
      track: List.from(_track),
      splits: List.from(_splits),
      avgHr: avgHr,
      maxHr: maxHr,
      avgGpsAccuracyM: avgAccuracy,
      startLat: _track.isNotEmpty ? _track.first.lat : null,
      startLng: _track.isNotEmpty ? _track.first.lng : null,
      endLat: _track.isNotEmpty ? _track.last.lat : null,
      endLng: _track.isNotEmpty ? _track.last.lng : null,
    );

    notifyListeners();
    return act;
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    _status = RecordingStatus.idle;
    _track.clear();
    _splits.clear();
    _elapsedSeconds = 0;
    _totalDistanceKm = 0.0;
    _elevationGain = 0.0;
    _calories = 0.0;
    _currentPace = 0.0;
    _gpsWarning = null;
    _lastSplitTimeMs = null;
    _lastSplitElevationGain = 0.0;
    _sLat = null;
    _sLng = null;
    _sVar = null;
    _eleBuffer.clear();
    _speedWindowMs.clear();
    _smoothedSpeedKmh = 0.0;
    _gpsQuality = GpsQuality.searching;
    notifyListeners();
  }

  void _resetSessionState() {
    _track.clear();
    _splits.clear();
    _elapsedSeconds = 0;
    _pausedSecondsTotal = 0;
    _pausedAt = null;
    _totalDistanceKm = 0.0;
    _elevationGain = 0.0;
    _calories = 0.0;
    _currentPace = 0.0;
    _lastAccuracy = null;
    _lastSplitTimeMs = null;
    _lastSplitElevationGain = 0.0;
    _sLat = null;
    _sLng = null;
    _sVar = null;
    _eleBuffer.clear();
    _speedWindowMs.clear();
    _smoothedSpeedKmh = 0.0;
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

    if (acc <= 12) {
      _gpsQuality = GpsQuality.good;
      _gpsWarning = null;
    } else if (acc <= 30) {
      _gpsQuality = GpsQuality.ok;
      _gpsWarning = null;
    } else if (acc <= 60) {
      _gpsQuality = GpsQuality.weak;
      _gpsWarning = 'Weak GPS signal (±${acc.round()}m). Move to an open area.';
    } else {
      _gpsQuality = GpsQuality.coarse;
      _gpsWarning =
          'Approximate GPS (±${acc.round()}m). Enable "Precise Location" for an accurate route.';
    }

    // A fix this bad cannot produce a trustworthy route. Keep waiting rather
    // than drawing a straight line across the map.
    if (acc > 100) {
      notifyListeners();
      return false;
    }

    if (_status != RecordingStatus.running) {
      notifyListeners();
      return true;
    }

    final t = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    // Kalman smoothing. Process noise grows with speed so a fast ride is not
    // lagged behind by an over-smoothed line.
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

    final baseCityEle = (RuchaConstants.cities[_selectedCity] ??
            RuchaConstants.cities['addis']!)
        .baseEle;
    final smoothedEle = _smoothElevation(ele ?? baseCityEle);

    double stepM = 0.0;
    if (_track.isNotEmpty) {
      final lastPt = _track.last;
      stepM = RuchaConstants.haversineDistance(
        lastPt.lat,
        lastPt.lng,
        smoothedLat,
        smoothedLng,
      );

      // Standing-still jitter must never become distance or a zig-zag line.
      final deadZone = max(1.5, min(acc * 0.3, 7.0));
      if (stepM < deadZone) {
        notifyListeners();
        return false;
      }

      // Reject impossible teleports while allowing genuine sprint/descent
      // speeds.
      final dtS = max(0.001, (t - lastPt.t) / 1000.0);
      final maxSpeedAllowed = _activityType == 'ride'
          ? 30.0
          : _activityType == 'walk'
              ? 3.5
              : 14.0; // m/s
      if (stepM / dtS > maxSpeedAllowed) {
        notifyListeners();
        return false;
      }

      final dEle = smoothedEle - lastPt.ele;
      if (dEle > 0) {
        _elevationGain += dEle;
      }
    }

    _totalDistanceKm += (stepM / 1000.0);

    // ── Smoothed speed (Google Maps style) ───────────────────────────────
    // Compute instantaneous speed for this segment, push to rolling window,
    // then compute exponentially-weighted average for smooth display.
    if (_track.isNotEmpty) {
      final lastPt = _track.last;
      final dtS = max(0.001, (t - lastPt.t) / 1000.0);
      final instantKmh = (stepM / dtS) * 3.6;
      _speedWindowMs.add(instantKmh);
      if (_speedWindowMs.length > 5) _speedWindowMs.removeAt(0);

      // Weights: 1, 2, 3, 4, 5 (most recent = highest weight)
      double weightedSum = 0.0;
      double totalWeight = 0.0;
      for (int i = 0; i < _speedWindowMs.length; i++) {
        final w = (i + 1).toDouble();
        weightedSum += _speedWindowMs[i] * w;
        totalWeight += w;
      }
      final rawSmoothed =
          totalWeight > 0 ? weightedSum / totalWeight : instantKmh;

      // Exponential smoothing: α=0.25 absorbs spikes without lag
      const alpha = 0.25;
      if (_smoothedSpeedKmh == 0.0) {
        _smoothedSpeedKmh = rawSmoothed;
      } else {
        _smoothedSpeedKmh =
            alpha * rawSmoothed + (1.0 - alpha) * _smoothedSpeedKmh;
      }

      // Clamp to realistic range
      final maxKmh = _activityType == 'ride'
          ? 108.0
          : _activityType == 'walk'
              ? 12.6
              : 50.4;
      _smoothedSpeedKmh = _smoothedSpeedKmh.clamp(0.0, maxKmh);
    }

    final pt = TrackPoint(
      lat: smoothedLat,
      lng: smoothedLng,
      ele: smoothedEle,
      d: _totalDistanceKm,
      t: t,
      accuracy: acc,
      speed: speed,
      hr: _currentHr,
    );
    _track.add(pt);
    if (_track.length == 1) {
      _lastSplitTimeMs = pt.t;
    }

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
    if (_track.length < 2) return;
    final current = _track.last;
    final previous = _track[_track.length - 2];
    final segmentDistance = current.d - previous.d;

    while (_totalDistanceKm >= (_splits.length + 1).toDouble()) {
      final targetKm = (_splits.length + 1).toDouble();
      final fraction = segmentDistance > 1e-9
          ? ((targetKm - previous.d) / segmentDistance).clamp(0.0, 1.0)
          : 1.0;
      final targetMs =
          previous.t + ((current.t - previous.t) * fraction).round();
      final startMs = _lastSplitTimeMs ?? _track.first.t;
      final splitSeconds = ((targetMs - startMs) / 1000).round();
      final splitElevation = _elevationGain - _lastSplitElevationGain;

      _splits.add(ActivitySplit(
        km: targetKm.toInt(),
        paceSeconds: splitSeconds > 0 ? splitSeconds.toDouble() : 0.0,
        eleGain: splitElevation > 0 ? splitElevation : 0.0,
      ));
      _lastSplitTimeMs = targetMs;
      _lastSplitElevationGain = _elevationGain;

      // Safety valve for corrupted GPS jumps.
      if (_splits.length > 100) break;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _gpsSubscription?.cancel();
    super.dispose();
  }
}
