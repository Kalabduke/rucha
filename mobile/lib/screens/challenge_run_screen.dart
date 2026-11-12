import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/activity.dart';
import '../models/challenge.dart';
import '../services/activity_store.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/challenge_results.dart';
import '../services/tracking_service.dart';
import '../widgets/osm_map_widget.dart';

/// Dedicated kilometre time trial.
///
/// The runner owns its own live GPS session, auto-stops at the chosen distance
/// and records the exact interpolated crossing time. It never redirects to the
/// normal Record tab and it refuses to hijack an activity that is already
/// recording there.
class ChallengeRunScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeRunScreen({super.key, required this.challenge});

  @override
  State<ChallengeRunScreen> createState() => _ChallengeRunScreenState();
}

class _ChallengeRunScreenState extends State<ChallengeRunScreen> {
  static const List<double> _standardPresets = [1.0, 5.0, 10.0];

  late double _targetKm;
  String _activityType = 'run';
  Map<String, ChallengeResult> _results = const {};
  bool _starting = false;
  bool _ownsSession = false;
  bool _finishing = false;

  Activity? _finishedActivity;
  ChallengeResult? _finishResult;
  int? _finishSeconds;
  int? _previousBestSeconds;
  bool _finishReached = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _targetKm = _defaultTargetKm();
    _loadResults();
    context.read<TrackingService>().addListener(_onTrackingChanged);
  }

  @override
  void dispose() {
    final tracking = context.read<TrackingService>();
    tracking.removeListener(_onTrackingChanged);
    // Safety net: if this route is removed without the PopScope confirmation,
    // never leave a live GPS stream running behind an empty screen.
    if (_ownsSession &&
        (tracking.status == RecordingStatus.running ||
            tracking.status == RecordingStatus.paused ||
            tracking.status == RecordingStatus.searching)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tracking.reset());
    }
    super.dispose();
  }

  double _defaultTargetKm() {
    final target = widget.challenge.targetKm;
    if (target != null && target > 0) return target;
    return 5.0;
  }

  List<double> get _presets {
    final values = List<double>.from(_standardPresets);
    final target = widget.challenge.targetKm;
    if (target != null &&
        target > 0 &&
        !values.any((value) => (value - target).abs() < 0.001)) {
      values.add(target);
    }
    if (!values.any((value) => (value - _targetKm).abs() < 0.001)) {
      values.add(_targetKm);
    }
    values.sort();
    return values;
  }

  Future<void> _loadResults() async {
    final results = await ChallengeResultStore.loadAll();
    if (!mounted) return;
    setState(() => _results = results);
  }

  ChallengeResult? get _selectedResult => ChallengeResultStore.resultFor(
        _results,
        widget.challenge.id,
        _targetKm,
      );

  bool get _isRecording {
    if (!_ownsSession) return false;
    final status = context.read<TrackingService>().status;
    return status == RecordingStatus.running ||
        status == RecordingStatus.paused ||
        status == RecordingStatus.searching;
  }

  void _onTrackingChanged() {
    if (!mounted) return;
    final tracking = context.read<TrackingService>();
    if (_ownsSession &&
        !_finishing &&
        tracking.status == RecordingStatus.running &&
        tracking.totalDistanceKm >= _targetKm) {
      final seconds = timeToDistanceSeconds(
        tracking.track,
        _targetKm,
        pausedSeconds: tracking.pausedSecondsTotal,
      );
      unawaited(_finish(reachedTarget: true, targetSeconds: seconds));
      return;
    }
    setState(() {});
  }

  /// Race clock: starts with the first accepted GPS fix, not with the
  /// permission prompt, and freezes while paused. This matches the exact
  /// crossing time that is stored when the target is reached.
  int _raceSeconds(TrackingService tracking) {
    if (tracking.track.isEmpty) return 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final seconds =
        ((nowMs - tracking.track.first.t) / 1000.0).round() -
            tracking.pausedSecondsTotal;
    return max(0, seconds);
  }

  Future<void> _start() async {
    if (_starting) return;
    final tracking = context.read<TrackingService>();
    if (tracking.status != RecordingStatus.idle) {
      setState(() {
        _error =
            'Another activity is already recording. Finish it in the Record tab first.';
      });
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });
    tracking.setActivityType(_activityType);
    final started = await tracking.startRecording(
      title: '"${widget.challenge.title}" ${_kmLabel(_targetKm)} time trial',
    );
    if (!mounted) return;
    setState(() {
      _starting = false;
      _ownsSession = started;
      if (!started) {
        _error = tracking.gpsWarning ??
            'Could not start GPS. Check location permission and try again.';
      }
    });
  }

  Future<void> _finish({
    required bool reachedTarget,
    int? targetSeconds,
  }) async {
    if (_finishing) return;
    final tracking = context.read<TrackingService>();
    final status = tracking.status;
    if (status != RecordingStatus.running &&
        status != RecordingStatus.paused &&
        status != RecordingStatus.searching) {
      return;
    }

    _finishing = true;
    final previous = _selectedResult;
    final seconds = targetSeconds ?? tracking.elapsedSeconds;
    final act = tracking.finishRecording();
    final store = context.read<ActivityStore>();
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();

    ChallengeResult? result;
    if (reachedTarget && seconds > 0) {
      result = await ChallengeResultStore.record(
        challengeId: widget.challenge.id,
        targetKm: _targetKm,
        seconds: seconds,
      );
    }

    await store.add(act);
    unawaited(api.saveActivity(act));

    if (reachedTarget &&
        auth.serverOnline &&
        auth.isAuthenticated &&
        !auth.isLocalAccount) {
      final user = auth.currentUser!;
      unawaited(
        api.postChallengeProgress(
          challengeId: widget.challenge.id,
          distanceKm: act.distance,
          durationSec: seconds,
          elevationM: act.elevation.round(),
          athleteId: user.id,
          athleteName: user.username,
        ),
      );
    }

    if (result != null) {
      _results = {
        ..._results,
        ChallengeResultStore.keyFor(widget.challenge.id, _targetKm): result,
      };
    }
    tracking.reset();
    if (!mounted) return;

    setState(() {
      _finishing = false;
      _ownsSession = false;
      _finishedActivity = act;
      _finishResult = result;
      _finishSeconds = reachedTarget ? seconds : null;
      _finishReached = reachedTarget;
      _previousBestSeconds = previous?.bestSeconds;
    });
  }

  Future<void> _finishManually() async {
    final tracking = context.read<TrackingService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        title: const Text('Finish this time trial?'),
        content: Text(
          'You have covered ${tracking.totalDistanceKm.toStringAsFixed(2)} '
          'of ${_kmLabel(_targetKm)}. The run is saved either way; a best '
          'time is only recorded when you reach the target distance.',
          style: const TextStyle(color: RuchaTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep running'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Finish & save',
              style: TextStyle(color: RuchaTheme.accentGreen),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finish(reachedTarget: false);
  }

  Future<void> _confirmLeave() async {
    if (!_isRecording) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final tracking = context.read<TrackingService>();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        title: const Text('Time trial in progress'),
        content: Text(
          '${tracking.totalDistanceKm.toStringAsFixed(2)} '
          'of ${_kmLabel(_targetKm)} covered. Leaving now stops the GPS '
          'session and saves the activity.',
          style: const TextStyle(color: RuchaTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('stay'),
            child: const Text('Keep running'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: const Text(
              'Stop & save',
              style: TextStyle(color: RuchaTheme.accentGreen),
            ),
          ),
        ],
      ),
    );
    if (action != 'save' || !mounted) return;
    await _finish(reachedTarget: false);
    if (mounted) Navigator.of(context).pop();
  }

  void _resetForRetry() {
    setState(() {
      _finishedActivity = null;
      _finishResult = null;
      _finishSeconds = null;
      _previousBestSeconds = null;
      _finishReached = false;
      _error = null;
    });
    unawaited(_loadResults());
  }

  Future<void> _pickCustomTarget() async {
    final controller = TextEditingController(
      text: _targetKm == _targetKm.roundToDouble()
          ? _targetKm.toStringAsFixed(0)
          : _targetKm.toStringAsFixed(2),
    );
    final chosen = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        title: const Text('Custom distance'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Distance (km)',
            hintText: 'e.g. 3.5',
          ),
          onSubmitted: (value) {
            final km = double.tryParse(value.trim());
            if (km != null && km > 0 && km <= 200) {
              Navigator.of(dialogContext).pop(km);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final km = double.tryParse(controller.text.trim());
              if (km != null && km > 0 && km <= 200) {
                Navigator.of(dialogContext).pop(km);
              }
            },
            child: const Text(
              'Use distance',
              style: TextStyle(color: RuchaTheme.accentGreen),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (chosen == null || !mounted) return;
    setState(() => _targetKm = chosen);
  }

  String _kmLabel(double km) {
    if ((km - km.roundToDouble()).abs() < 0.05) {
      return '${km.round()} km';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final otherSession = !_ownsSession &&
        _finishedActivity == null &&
        (tracking.status == RecordingStatus.running ||
            tracking.status == RecordingStatus.paused ||
            tracking.status == RecordingStatus.searching);

    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: RuchaTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _header(tracking),
              Expanded(
                child: _finishedActivity != null
                    ? _buildResult(tracking)
                    : otherSession
                        ? _buildBlocked(tracking)
                        : _buildRunner(tracking),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(TrackingService tracking) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 14, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => unawaited(_confirmLeave()),
            icon: const Icon(CupertinoIcons.back, size: 20),
            color: Colors.white,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIME TRIAL',
                  style: TextStyle(
                    color: RuchaTheme.accentGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  widget.challenge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _gpsBadge(tracking),
        ],
      ),
    );
  }

  Widget _gpsBadge(TrackingService tracking) {
    Color fg;
    String text;
    switch (tracking.gpsQuality) {
      case GpsQuality.good:
        fg = RuchaTheme.accentGreen;
        text = 'GPS strong';
        break;
      case GpsQuality.ok:
        fg = RuchaTheme.accentGreen;
        text = 'GPS ok';
        break;
      case GpsQuality.weak:
        fg = RuchaTheme.accentGold;
        text = 'GPS weak';
        break;
      case GpsQuality.coarse:
        fg = RuchaTheme.accentRed;
        text = 'Approximate';
        break;
      case GpsQuality.lost:
      case GpsQuality.searching:
        fg = RuchaTheme.textSecondary;
        text = 'Searching';
        break;
    }
    if (tracking.lastAccuracy != null &&
        tracking.gpsQuality != GpsQuality.searching) {
      text += ' ±${tracking.lastAccuracy!.round()}m';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocked(TrackingService tracking) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: RuchaTheme.accentGold,
            size: 44,
          ),
          const SizedBox(height: 14),
          const Text(
            'An activity is already recording',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Finish the live session in the Record tab before starting a time '
            'trial. RUCHA keeps one GPS recording at a time so a route is '
            'never duplicated or lost.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to challenges'),
          ),
        ],
      ),
    );
  }

  Widget _buildRunner(TrackingService tracking) {
    final isRunning = tracking.status == RecordingStatus.running;
    final isPaused = tracking.status == RecordingStatus.paused;
    final isSearching = tracking.status == RecordingStatus.searching;
    final active = _ownsSession && (isRunning || isPaused || isSearching);
    final preview = tracking.previewPosition;
    final city = RuchaConstants.cities[tracking.selectedCity] ??
        RuchaConstants.cities['addis']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: active ? 230 : 180,
              child: OsmMapWidget(
                centerLat: preview?.lat ?? city.lat,
                centerLng: preview?.lng ?? city.lng,
                initialZoom: 15,
                track: tracking.track,
                currentPosition: preview,
                routeColor: _activityType == 'ride'
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFC4C02),
                isInteractive: true,
                isDarkMode: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!active) ..._buildReady(tracking) else ..._buildLive(tracking),
        ],
      ),
    );
  }

  List<Widget> _buildReady(TrackingService tracking) {
    final result = _selectedResult;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RuchaTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RuchaTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.timer,
                  size: 16,
                  color: RuchaTheme.accentGreen,
                ),
                const SizedBox(width: 6),
                const Text(
                  'CHOOSE YOUR DISTANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  _kmLabel(_targetKm),
                  style: const TextStyle(
                    color: RuchaTheme.accentGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text(_kmLabel(preset)),
                    selected: (preset - _targetKm).abs() < 0.001,
                    onSelected: (_) => setState(() => _targetKm = preset),
                    selectedColor:
                        RuchaTheme.accentGreen.withValues(alpha: 0.2),
                    backgroundColor: RuchaTheme.surface2,
                    labelStyle: TextStyle(
                      color: (preset - _targetKm).abs() < 0.001
                          ? RuchaTheme.accentGreen
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: (preset - _targetKm).abs() < 0.001
                          ? RuchaTheme.accentGreen
                          : RuchaTheme.border,
                    ),
                    showCheckmark: false,
                  ),
                ChoiceChip(
                  avatar: const Icon(
                    CupertinoIcons.add,
                    size: 12,
                    color: RuchaTheme.textSecondary,
                  ),
                  label: const Text('Custom'),
                  selected: false,
                  onSelected: (_) => unawaited(_pickCustomTarget()),
                  backgroundColor: RuchaTheme.surface2,
                  labelStyle: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  side: const BorderSide(color: RuchaTheme.border),
                  showCheckmark: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RuchaTheme.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    result == null
                        ? CupertinoIcons.flag
                        : CupertinoIcons.rosette,
                    size: 18,
                    color: result == null
                        ? RuchaTheme.textSecondary
                        : RuchaTheme.accentGold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result == null
                          ? 'No effort at ${_kmLabel(_targetKm)} yet. Set your first time.'
                          : 'Personal best ${_formatSeconds(result.bestSeconds)} '
                              '· ${result.attempts} attempt${result.attempts == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: result == null
                            ? RuchaTheme.textSecondary
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _typeButton('run', 'Run', Icons.directions_run)),
          const SizedBox(width: 8),
          Expanded(child: _typeButton('ride', 'Ride', Icons.directions_bike)),
        ],
      ),
      if (widget.challenge.description.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RuchaTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RuchaTheme.border),
          ),
          child: Text(
            widget.challenge.description,
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RuchaTheme.accentRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: RuchaTheme.accentRed.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            _error!,
            style: const TextStyle(
              color: RuchaTheme.accentRed,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _starting ? null : () => unawaited(_start()),
          icon: _starting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(CupertinoIcons.play_arrow_solid, size: 16),
          label: Text(
            _starting
                ? 'Starting GPS…'
                : 'Start ${_kmLabel(_targetKm)} time trial',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: RuchaTheme.accentGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'The clock stops automatically at the target distance. GPS keeps '
        'recording with the screen off.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: RuchaTheme.textSecondary,
          fontSize: 10,
          height: 1.4,
        ),
      ),
    ];
  }

  Widget _typeButton(String type, String label, IconData icon) {
    final selected = _activityType == type;
    return GestureDetector(
      onTap: selected ? null : () => setState(() => _activityType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? RuchaTheme.accentGreen.withValues(alpha: 0.16)
              : RuchaTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? RuchaTheme.accentGreen : RuchaTheme.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? RuchaTheme.accentGreen : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? RuchaTheme.accentGreen : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLive(TrackingService tracking) {
    final progress =
        (_targetKm > 0 ? tracking.totalDistanceKm / _targetKm : 0.0)
            .clamp(0.0, 1.0);
    final isPaused = tracking.status == RecordingStatus.paused;
    final isSearching = tracking.status == RecordingStatus.searching;

    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: RuchaTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RuchaTheme.border),
        ),
        child: Column(
          children: [
            Text(
              isSearching ? 'WAITING FOR GPS' : 'ELAPSED',
              style: TextStyle(
                color:
                    isPaused ? RuchaTheme.accentGold : RuchaTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatSeconds(_raceSeconds(tracking)),
              style: TextStyle(
                color: isPaused ? RuchaTheme.accentGold : Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: RuchaTheme.surface2,
                valueColor: const AlwaysStoppedAnimation(
                  RuchaTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tracking.totalDistanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'of ${_kmLabel(_targetKm)}',
                  style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _metric(
              'PACE',
              tracking.currentPace > 0
                  ? '${RuchaConstants.formatPace(tracking.currentPace)}/km'
                  : '--:--',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metric(
              'GAIN',
              '+${tracking.elevationGain.round()} m',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metric(
              'REMAINING',
              '${max(0, _targetKm - tracking.totalDistanceKm).toStringAsFixed(2)} km',
            ),
          ),
        ],
      ),
      if (tracking.gpsWarning != null) ...[
        const SizedBox(height: 10),
        Text(
          tracking.gpsWarning!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RuchaTheme.accentGold,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSearching
                  ? null
                  : () {
                      final service = context.read<TrackingService>();
                      if (isPaused) {
                        unawaited(service.resumeRecording());
                      } else {
                        unawaited(service.pauseRecording());
                      }
                    },
              icon: Icon(
                isPaused
                    ? CupertinoIcons.play_arrow_solid
                    : CupertinoIcons.pause_fill,
                size: 14,
              ),
              label: Text(isPaused ? 'Resume' : 'Pause'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: RuchaTheme.border),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => unawaited(_finishManually()),
              icon: const Icon(CupertinoIcons.stop_fill, size: 14),
              label: const Text('Finish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: RuchaTheme.accentCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        isPaused
            ? 'Paused · the race clock is stopped'
            : 'Auto-stops at ${_kmLabel(_targetKm)}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isPaused ? RuchaTheme.accentGold : RuchaTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(TrackingService tracking) {
    final act = _finishedActivity!;
    final result = _finishResult;
    final isNewBest = _finishReached &&
        (_previousBestSeconds == null ||
            (_finishSeconds != null &&
                _finishSeconds! < _previousBestSeconds!));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Icon(
            _finishReached ? CupertinoIcons.rosette : CupertinoIcons.flag,
            size: 46,
            color: _finishReached
                ? RuchaTheme.accentGold
                : RuchaTheme.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            _finishReached ? 'TIME TRIAL COMPLETE' : 'RUN SAVED',
            style: TextStyle(
              color: _finishReached
                  ? RuchaTheme.accentGold
                  : RuchaTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _finishReached
                ? _formatSeconds(_finishSeconds ?? act.duration)
                : _formatSeconds(act.duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1.05,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _finishReached
                ? 'for ${_kmLabel(_targetKm)}'
                : '${act.distance.toStringAsFixed(2)} km covered · target was ${_kmLabel(_targetKm)}',
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isNewBest) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: RuchaTheme.accentGold.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 13,
                    color: RuchaTheme.accentGold,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'NEW PERSONAL BEST',
                    style: TextStyle(
                      color: RuchaTheme.accentGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Column(
              children: [
                _resultRow('Distance', '${act.distance.toStringAsFixed(2)} km'),
                _resultRow(
                  'Pace',
                  act.pace > 0
                      ? '${RuchaConstants.formatPace(act.pace)}/km'
                      : '--:--',
                ),
                _resultRow('Elevation gain', '+${act.elevation.round()} m'),
                if (_finishReached && result != null)
                  _resultRow(
                    'Personal best',
                    '${_formatSeconds(result.bestSeconds)} '
                        '(${result.attempts} attempt${result.attempts == 1 ? '' : 's'})',
                  ),
                _resultRow('Saved', 'On this device'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: RuchaTheme.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resetForRetry,
            child: const Text(
              'Run another time trial',
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int seconds) => RuchaConstants.formatDuration(seconds);
}
