import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
      other is DiscoveredWatch &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// Cross-platform Bluetooth LE heart rate service.
/// Works on both Android and iOS using flutter_blue_plus.
class SmartwatchService extends ChangeNotifier {
  StreamSubscription? _scanSubscription;
  StreamSubscription? _hrSubscription;
  Timer? _simulatorTimer;
  BluetoothDevice? _connectedDevice;

  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;

  int _currentBpm = 0;
  final List<int> _bpmHistory = [];

  final List<DiscoveredWatch> _discoveredWatches = [];
  bool _isSimulatorMode = false;

  // Standard Bluetooth SIG UUIDs for Heart Rate
  static final Guid _hrServiceUuid =
      Guid("0000180d-0000-1000-8000-00805f9b34fb");
  static final Guid _hrMeasurementUuid =
      Guid("00002a37-0000-1000-8000-00805f9b34fb");

  SmartwatchService();

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  int get currentBpm => _currentBpm;
  List<DiscoveredWatch> get discoveredWatches =>
      List.unmodifiable(_discoveredWatches);
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

  Future<void> startScan() async {
    _discoveredWatches.clear();
    _isScanning = true;
    notifyListeners();

    if (_isSimulatorMode || kIsWeb) {
      // Provide standard virtual devices in simulator mode or web
      await Future.delayed(const Duration(milliseconds: 600));
      _discoveredWatches.addAll(const [
        DiscoveredWatch(
            address: 'AA:BB:CC:11:22:33',
            name: 'Garmin Forerunner 965',
            rssi: -45),
        DiscoveredWatch(
            address: 'AA:BB:CC:44:55:66',
            name: 'Wear OS Galaxy Watch 6',
            rssi: -52),
        DiscoveredWatch(
            address: 'AA:BB:CC:77:88:99',
            name: 'Apple Watch Ultra BLE',
            rssi: -58),
        DiscoveredWatch(
            address: 'AA:BB:CC:00:11:22',
            name: 'Polar H10 Heart Rate Strap',
            rssi: -40),
      ]);
      _isScanning = false;
      notifyListeners();
      return;
    }

    try {
      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isAvailable) {
        _isScanning = false;
        notifyListeners();
        return;
      }

      // Start scanning for devices with Heart Rate Service
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final device = r.device;
          final name = device.platformName.isNotEmpty
              ? device.platformName
              : 'BLE Watch';
          final addr = device.remoteId.toString();
          final rssi = r.rssi;

          // Only add devices advertising the Heart Rate Service
          final hasHrService = r.advertisementData.serviceUuids
              .any((uuid) => uuid == _hrServiceUuid);
          if (hasHrService &&
              !_discoveredWatches.any((w) => w.address == addr)) {
            _discoveredWatches
                .add(DiscoveredWatch(address: addr, name: name, rssi: rssi));
            notifyListeners();
          }
        }
      }, onError: (e) {
        debugPrint('BLE scan error: $e');
      });

      await FlutterBluePlus.startScan(
        withServices: [_hrServiceUuid],
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('Failed to start BLE scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    _isScanning = false;
    notifyListeners();
    if (!kIsWeb) {
      try {
        await FlutterBluePlus.stopScan();
        await _scanSubscription?.cancel();
        _scanSubscription = null;
      } catch (e) {
        debugPrint('Stop scan error: $e');
      }
    }
  }

  Future<void> connect(DiscoveredWatch watch) async {
    _isConnected = true;
    _connectedDeviceName = watch.name;
    _connectedDeviceAddress = watch.address;
    notifyListeners();

    if (_isSimulatorMode || kIsWeb) {
      _startSimulatorHeartRate();
      return;
    }

    try {
      // Find the device by remote ID
      final devices = FlutterBluePlus.connectedDevices;
      BluetoothDevice? device = devices.cast<BluetoothDevice?>().firstWhere(
            (d) => d?.remoteId.toString() == watch.address,
            orElse: () => null,
          );

      if (device == null) {
        // Device not already connected, need to scan for it
        final scanResults = FlutterBluePlus.lastScanResults;
        for (final r in scanResults) {
          if (r.device.remoteId.toString() == watch.address) {
            device = r.device;
            break;
          }
        }
      }

      if (device == null) {
        _isConnected = false;
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
        notifyListeners();
        return;
      }

      _connectedDevice = device;

      // Connect to the device
      await device.connect(timeout: const Duration(seconds: 15));

      // Discover services
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == _hrServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _hrMeasurementUuid) {
              // Subscribe to heart rate notifications
              await char.setNotifyValue(true);
              _hrSubscription = char.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  final bpm = _parseHrValue(value);
                  if (bpm > 30 && bpm < 240) {
                    _currentBpm = bpm;
                    _bpmHistory.add(bpm);
                    notifyListeners();
                  }
                }
              });
              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('BLE connect error: $e');
      _isConnected = false;
      _connectedDeviceName = null;
      _connectedDeviceAddress = null;
      _connectedDevice = null;
      notifyListeners();
    }
  }

  int _parseHrValue(List<int> value) {
    if (value.isEmpty) return 0;
    final flag = value[0];
    // Bit 0 indicates format: 0 = uint8, 1 = uint16
    if ((flag & 0x01) != 0 && value.length >= 3) {
      // uint16 format
      return (value[1] & 0xFF) | ((value[2] & 0xFF) << 8);
    } else if (value.length >= 2) {
      // uint8 format
      return value[1] & 0xFF;
    }
    return 0;
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectedDeviceName = null;
    _connectedDeviceAddress = null;
    _currentBpm = 0;
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    await _hrSubscription?.cancel();
    _hrSubscription = null;

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('BLE disconnect error: $e');
      }
      _connectedDevice = null;
    }

    notifyListeners();
  }

  void toggleSimulatorMode(bool enable) {
    _isSimulatorMode = enable;
    if (_isSimulatorMode && !_isConnected) {
      connect(const DiscoveredWatch(
        address: 'SIM:00:11:22:33',
        name: 'Wear OS Pro (Simulated)',
        rssi: -30,
      ));
    } else if (!_isSimulatorMode &&
        _connectedDeviceAddress?.startsWith('SIM:') == true) {
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
    _scanSubscription?.cancel();
    _hrSubscription?.cancel();
    if (_connectedDevice != null) {
      _connectedDevice!.disconnect();
    }
    super.dispose();
  }
}
