import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DiscoveredWatch {
  final String address;
  final String name;
  final int rssi;

  const DiscoveredWatch({
    required this.address,
    required this.name,
    this.rssi = -60,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredWatch && runtimeType == other.runtimeType && address == other.address;

  @override
  int get hashCode => address.hashCode;
}

class SmartwatchService extends ChangeNotifier {
  static const MethodChannel _control = MethodChannel('com.rucha.mobile/smartwatch');
  static const EventChannel _stream = EventChannel('com.rucha.mobile/smartwatch_stream');

  StreamSubscription? _eventSub;
  Timer? _simulatorTimer;

  bool _isBluetoothAvailable = true;
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;

  int _currentBpm = 0;
  final List<int> _bpmHistory = [];

  final List<DiscoveredWatch> _discoveredWatches = [];
  bool _isSimulatorMode = false;

  SmartwatchService() {
    _initChannel();
  }

  bool get isBluetoothAvailable => _isBluetoothAvailable;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  int get currentBpm => _currentBpm;
  List<DiscoveredWatch> get discoveredWatches => List.unmodifiable(_discoveredWatches);
  bool get isSimulatorMode => _isSimulatorMode;

  int get avgBpm {
    if (_bpmHistory.isEmpty) return _currentBpm > 0 ? _currentBpm : 0;
    final sum = _bpmHistory.reduce((a, b) => a + b);
    return (sum / _bpmHistory.length).round();
  }

  int get maxBpm {
    if (_bpmHistory.isEmpty) return _currentBpm;
    return _bpmHistory.reduce(max);
  }

  void _initChannel() {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      _control.invokeMethod<bool>('isBluetoothAvailable').then((avail) {
        _isBluetoothAvailable = avail ?? false;
        notifyListeners();
      });

      _eventSub = _stream.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          final type = event['type']?.toString();
          if (type == 'bpm') {
            final bpm = (event['bpm'] as num?)?.toInt() ?? 0;
            if (bpm > 30 && bpm < 240) {
              _currentBpm = bpm;
              _bpmHistory.add(bpm);
              notifyListeners();
            }
          } else if (type == 'status') {
            final status = event['status']?.toString();
            if (status == 'connected') {
              _isConnected = true;
              _connectedDeviceName = event['name']?.toString() ?? 'Smartwatch';
              _connectedDeviceAddress = event['address']?.toString();
            } else if (status == 'disconnected') {
              _isConnected = false;
              _connectedDeviceName = null;
              _connectedDeviceAddress = null;
              _currentBpm = 0;
            }
            notifyListeners();
          } else if (type == 'discovered') {
            final addr = event['address']?.toString() ?? '';
            final name = event['name']?.toString() ?? 'BLE Watch';
            final rssi = (event['rssi'] as num?)?.toInt() ?? -60;
            if (addr.isNotEmpty && !_discoveredWatches.any((w) => w.address == addr)) {
              _discoveredWatches.add(DiscoveredWatch(address: addr, name: name, rssi: rssi));
              notifyListeners();
            }
          }
        }
      }, onError: (err) {
        debugPrint('Smartwatch stream error: $err');
      });
    } catch (e) {
      debugPrint('Failed to init Smartwatch channel: $e');
    }
  }

  Future<void> startScan() async {
    _discoveredWatches.clear();
    _isScanning = true;
    notifyListeners();

    if (_isSimulatorMode || kIsWeb || !Platform.isAndroid) {
      // Provide standard virtual devices in simulator mode or non-Android
      await Future.delayed(const Duration(milliseconds: 600));
      _discoveredWatches.addAll(const [
        DiscoveredWatch(address: 'AA:BB:CC:11:22:33', name: 'Garmin Forerunner 965', rssi: -45),
        DiscoveredWatch(address: 'AA:BB:CC:44:55:66', name: 'Wear OS Galaxy Watch 6', rssi: -52),
        DiscoveredWatch(address: 'AA:BB:CC:77:88:99', name: 'Apple Watch Ultra BLE', rssi: -58),
        DiscoveredWatch(address: 'AA:BB:CC:00:11:22', name: 'Polar H10 Heart Rate Strap', rssi: -40),
      ]);
      _isScanning = false;
      notifyListeners();
      return;
    }

    try {
      await _control.invokeMethod('startScan');
    } catch (_) {}
  }

  Future<void> stopScan() async {
    _isScanning = false;
    notifyListeners();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _control.invokeMethod('stopScan');
      } catch (_) {}
    }
  }

  Future<void> connect(DiscoveredWatch watch) async {
    _isConnected = true;
    _connectedDeviceName = watch.name;
    _connectedDeviceAddress = watch.address;
    notifyListeners();

    if (_isSimulatorMode || kIsWeb || !Platform.isAndroid) {
      _startSimulatorHeartRate();
      return;
    }

    try {
      await _control.invokeMethod('connectWatch', {
        'address': watch.address,
        'name': watch.name,
      });
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectedDeviceName = null;
    _connectedDeviceAddress = null;
    _currentBpm = 0;
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    notifyListeners();

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _control.invokeMethod('disconnectWatch');
      } catch (_) {}
    }
  }

  void toggleSimulatorMode(bool enable) {
    _isSimulatorMode = enable;
    if (_isSimulatorMode && !_isConnected) {
      connect(const DiscoveredWatch(
        address: 'SIM:00:11:22:33',
        name: 'Wear OS Pro (Simulated)',
        rssi: -30,
      ));
    } else if (!_isSimulatorMode && _connectedDeviceAddress?.startsWith('SIM:') == true) {
      disconnect();
    }
    notifyListeners();
  }

  void _startSimulatorHeartRate() {
    _simulatorTimer?.cancel();
    _currentBpm = 142;
    _bpmHistory.add(_currentBpm);
    notifyListeners();

    final rnd = Random();
    _simulatorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      // Dynamic physiological heart rate variations between 140 and 172 BPM
      final delta = rnd.nextInt(5) - 2; // -2, -1, 0, 1, 2
      _currentBpm = (_currentBpm + delta).clamp(138, 178);
      _bpmHistory.add(_currentBpm);
      notifyListeners();
    });
  }

  void clearSession() {
    _bpmHistory.clear();
    if (!_isConnected) {
      _currentBpm = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _simulatorTimer?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }
}
