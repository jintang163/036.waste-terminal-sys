import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/app_constants.dart';
import '../services/bluetooth_service.dart';
import '../services/liquid_level_linkage_service.dart';
import '../services/liquid_level_sensor_service.dart';

enum LiquidLevelPageState { idle, scanning, connecting, connected, error }

class LiquidLevelProvider extends ChangeNotifier {
  final LiquidLevelSensorService _sensor = LiquidLevelSensorService();
  final LiquidLevelLinkageService _linkage = LiquidLevelLinkageService();
  final BluetoothService _bluetooth = BluetoothService();
  final Logger _logger = Logger();

  LiquidLevelPageState _state = LiquidLevelPageState.idle;
  String? _errorMessage;
  List<BluetoothDeviceInfo> _scannedDevices = [];
  String? _boundContainerCode;

  double _currentLevel = 0.0;
  double _smoothedLevel = 0.0;
  bool _isStable = false;
  LiquidLevelState _currentLevelState = LiquidLevelState.normal;

  StreamSubscription<LiquidLevelReading>? _readingSubscription;
  StreamSubscription<LiquidLevelState>? _stateSubscription;
  StreamSubscription<LiquidLevelAlertEvent>? _alertSubscription;
  StreamSubscription<List<BluetoothDeviceInfo>>? _scanSubscription;

  final List<LiquidLevelAlertEvent> _recentAlerts = [];
  static const int _maxAlerts = 20;

  LiquidLevelPageState get state => _state;
  String? get errorMessage => _errorMessage;
  List<BluetoothDeviceInfo> get scannedDevices => List.unmodifiable(_scannedDevices);
  String? get boundContainerCode => _boundContainerCode;
  double get currentLevel => _currentLevel;
  double get smoothedLevel => _smoothedLevel;
  bool get isStable => _isStable;
  LiquidLevelState get currentLevelState => _currentLevelState;
  bool get isConnected =>
      _bluetooth.isLevelSensorConnected || _sensor.isSimulationRunning;
  bool get isSensorConnected => _bluetooth.isLevelSensorConnected;
  bool get isSimulation => _sensor.isSimulationRunning;
  String? get connectedDeviceName => _bluetooth.connectedDeviceName;
  double get nearFullThreshold => _sensor.nearFullThreshold;
  double get fullThreshold => _sensor.fullThreshold;
  List<LiquidLevelAlertEvent> get recentAlerts => List.unmodifiable(_recentAlerts);

  Future<void> init() async {
    _boundContainerCode = await _sensor.getBoundContainerCode();

    _readingSubscription = _sensor.readingStream.listen((reading) {
      _currentLevel = reading.level;
      _smoothedLevel = reading.smoothedLevel;
      _isStable = reading.isStable;
      _currentLevelState = reading.state;
      notifyListeners();
    });

    _stateSubscription = _sensor.stateStream.listen((s) {
      _currentLevelState = s;
      notifyListeners();
    });

    _alertSubscription = _linkage.alertStream.listen((alert) {
      _recentAlerts.insert(0, alert);
      if (_recentAlerts.length > _maxAlerts) {
        _recentAlerts.removeRange(_maxAlerts, _recentAlerts.length);
      }
      notifyListeners();
    });

    try {
      await _linkage.init();
      _state = _bluetooth.isLevelSensorConnected
          ? LiquidLevelPageState.connected
          : LiquidLevelPageState.idle;
    } catch (e) {
      _state = LiquidLevelPageState.idle;
    }
    notifyListeners();
  }

  Future<void> startScan() async {
    try {
      if (!(await _bluetooth.isBluetoothOn())) {
        final ok = await _bluetooth.turnOnBluetooth();
        if (!ok) throw Exception('蓝牙未开启');
      }

      _state = LiquidLevelPageState.scanning;
      _scannedDevices.clear();
      notifyListeners();

      _scanSubscription?.cancel();
      _scanSubscription = _bluetooth.scanResultsStream.listen((devices) {
        _scannedDevices = devices
            .where((d) => d.type == BluetoothDeviceType.levelSensor)
            .toList();
        notifyListeners();
      });

      await _bluetooth.startScan(
        timeout: const Duration(seconds: 10),
        withNames: const ['LEVEL', 'LIQUID', '液位', '传感', 'SENSOR', 'LS-'],
      );

      _state = LiquidLevelPageState.idle;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _state = LiquidLevelPageState.error;
      _logger.e('扫描蓝牙设备失败', e);
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await _bluetooth.stopScan();
    if (_state == LiquidLevelPageState.scanning) {
      _state = LiquidLevelPageState.idle;
      notifyListeners();
    }
  }

  Future<bool> connectDevice(String address) async {
    try {
      _state = LiquidLevelPageState.connecting;
      _errorMessage = null;
      notifyListeners();

      final ok = await _sensor.connectAndAttach(deviceAddress: address);
      if (ok) {
        try {
          await _linkage.init();
        } catch (_) {}
        _state = LiquidLevelPageState.connected;
        notifyListeners();
        return true;
      }
      _state = LiquidLevelPageState.idle;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = LiquidLevelPageState.error;
      _logger.e('连接液位传感器失败', e);
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _sensor.disconnect();
    _state = LiquidLevelPageState.idle;
    _currentLevel = 0;
    _smoothedLevel = 0;
    _isStable = false;
    _currentLevelState = LiquidLevelState.normal;
    notifyListeners();
  }

  Future<void> bindContainer(String containerCode) async {
    await _sensor.bindContainer(containerCode);
    _boundContainerCode = containerCode;
    notifyListeners();
  }

  Future<void> unbindContainer() async {
    await _sensor.unbindContainer();
    _boundContainerCode = null;
    notifyListeners();
  }

  Future<void> setThresholds({
    double? nearFull,
    double? full,
  }) async {
    await _sensor.setThresholds(nearFull: nearFull, full: full);
    notifyListeners();
  }

  void setSimulationLevel(double level) {
    _sensor.setSimulationLevel(level);
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _stateSubscription?.cancel();
    _alertSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }
}
