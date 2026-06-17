import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../utils/logger_util.dart';
import 'bluetooth_service.dart';

enum LiquidLevelState { normal, nearFull, full }

class LiquidLevelReading {
  final double level;
  final double smoothedLevel;
  final bool isStable;
  final LiquidLevelState state;
  final DateTime timestamp;

  LiquidLevelReading({
    required this.level,
    required this.smoothedLevel,
    required this.isStable,
    required this.state,
    required this.timestamp,
  });
}

class LiquidLevelSensorService {
  static final LiquidLevelSensorService _instance =
      LiquidLevelSensorService._internal();
  factory LiquidLevelSensorService() => _instance;

  final BluetoothService _bluetooth = BluetoothService();
  StreamSubscription<double>? _levelSubscription;

  static const double defaultNearFullThreshold = 80.0;
  static const double defaultFullThreshold = 95.0;
  static const int defaultStableSamples = 5;
  static const double defaultStableThreshold = 2.0;

  double _nearFullThreshold = defaultNearFullThreshold;
  double _fullThreshold = defaultFullThreshold;
  int _stableSamples = defaultStableSamples;
  double _stableThreshold = defaultStableThreshold;

  double _currentLevel = 0.0;
  double _smoothedLevel = 0.0;
  final List<double> _levelBuffer = [];
  int _stableSampleCount = 0;
  bool _isStable = false;
  DateTime _lastReadingTime = DateTime.now();

  LiquidLevelState _currentState = LiquidLevelState.normal;
  LiquidLevelState? _lastTriggeredState;

  Timer? _simulationTimer;
  final Random _random = Random();
  double _simulationBaseLevel = 30.0;
  bool _simulationRunning = false;

  final StreamController<LiquidLevelReading> _readingController =
      StreamController<LiquidLevelReading>.broadcast();
  final StreamController<LiquidLevelState> _stateController =
      StreamController<LiquidLevelState>.broadcast();

  Stream<LiquidLevelReading> get readingStream => _readingController.stream;
  Stream<LiquidLevelState> get stateStream => _stateController.stream;

  double get currentLevel => _currentLevel;
  double get smoothedLevel => _smoothedLevel;
  bool get isStable => _isStable;
  LiquidLevelState get currentState => _currentState;
  DateTime get lastReadingTime => _lastReadingTime;
  double get nearFullThreshold => _nearFullThreshold;
  double get fullThreshold => _fullThreshold;

  LiquidLevelSensorService._internal() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _nearFullThreshold =
          (prefs.getDouble(StorageConstants.levelWarningNearFull) ??
              defaultNearFullThreshold);
      _fullThreshold =
          (prefs.getDouble(StorageConstants.levelWarningFull) ??
              defaultFullThreshold);
      _stableSamples =
          (prefs.getInt(StorageConstants.levelSensorStableSamples) ??
              defaultStableSamples);
    } catch (e) {
      LoggerUtil.warning('加载液位传感器配置失败，使用默认值: $e');
    }
  }

  Future<void> setThresholds({
    double? nearFull,
    double? full,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (nearFull != null) {
        _nearFullThreshold = nearFull;
        await prefs.setDouble(StorageConstants.levelWarningNearFull, nearFull);
      }
      if (full != null) {
        _fullThreshold = full;
        await prefs.setDouble(StorageConstants.levelWarningFull, full);
      }
      _evaluateState();
    } catch (e) {
      LoggerUtil.error('保存液位阈值失败: $e');
    }
  }

  Future<bool> connectAndAttach({
    String? deviceAddress,
  }) async {
    try {
      bool ok;
      if (deviceAddress != null && deviceAddress.isNotEmpty) {
        await _bluetooth.connectByAddress(deviceAddress);
      } else {
        ok = await _bluetooth.autoConnectLevelSensor();
        if (!ok) {
          throw Exception('液位传感器蓝牙连接失败');
        }
      }

      if (!_bluetooth.isLevelSensorConnected) {
        throw Exception('未检测到液位传感器设备类型');
      }

      _attachBluetoothLevelStream();
      LoggerUtil.info('液位传感器连接成功: ${_bluetooth.connectedDeviceName}');
      return true;
    } catch (e) {
      LoggerUtil.error('连接液位传感器失败', e);
      _startSimulationMode();
      return false;
    }
  }

  void _attachBluetoothLevelStream() {
    _levelSubscription?.cancel();
    _levelSubscription = _bluetooth.liquidLevelStream.listen((level) {
      _onLevelReceived(level);
    });
    LoggerUtil.debug('已订阅蓝牙液位数据流');
  }

  void _startSimulationMode() {
    if (_simulationRunning) return;
    _simulationRunning = true;
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final noise = (_random.nextDouble() - 0.5) * 2;
      final simulated = _simulationBaseLevel + noise;
      final clamped = simulated.clamp(0.0, 100.0).toDouble();
      _onLevelReceived(clamped);
    });
    LoggerUtil.info('已启动液位传感器模拟模式');
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationRunning = false;
  }

  void setSimulationLevel(double level) {
    _simulationBaseLevel = level.clamp(0.0, 100.0).toDouble();
  }

  void _onLevelReceived(double level) {
    _currentLevel = level;
    _lastReadingTime = DateTime.now();

    _levelBuffer.add(level);
    if (_levelBuffer.length > _stableSamples * 3) {
      _levelBuffer.removeRange(0, _levelBuffer.length - _stableSamples * 3);
    }

    if (_levelBuffer.length >= _stableSamples) {
      final recent = _levelBuffer.sublist(_levelBuffer.length - _stableSamples);
      final avg = recent.reduce((a, b) => a + b) / recent.length;
      _smoothedLevel = double.parse(avg.toStringAsFixed(1));

      final maxV = recent.reduce(max);
      final minV = recent.reduce(min);
      final bool nowStable = (maxV - minV) <= _stableThreshold;

      if (nowStable) {
        _stableSampleCount++;
      } else {
        _stableSampleCount = 0;
      }

      final bool wasStable = _isStable;
      _isStable = _stableSampleCount >= _stableSamples;
      if (wasStable != _isStable) {
        LoggerUtil.debug('液位稳定状态: $_isStable, 当前平滑值: $_smoothedLevel%');
      }
    } else {
      _smoothedLevel = level;
      _isStable = false;
    }

    final previousState = _currentState;
    _evaluateState();

    final reading = LiquidLevelReading(
      level: level,
      smoothedLevel: _smoothedLevel,
      isStable: _isStable,
      state: _currentState,
      timestamp: _lastReadingTime,
    );
    _readingController.add(reading);

    if (previousState != _currentState) {
      _stateController.add(_currentState);
    }
  }

  void _evaluateState() {
    final level = _smoothedLevel > 0 ? _smoothedLevel : _currentLevel;

    LiquidLevelState newState;
    if (level >= _fullThreshold) {
      newState = LiquidLevelState.full;
    } else if (level >= _nearFullThreshold) {
      newState = LiquidLevelState.nearFull;
    } else {
      newState = LiquidLevelState.normal;
    }

    if (_currentState != newState) {
      if (_isStable || newState == LiquidLevelState.normal) {
        _currentState = newState;
        if (newState != LiquidLevelState.normal) {
          if (_lastTriggeredState != newState) {
            _lastTriggeredState = newState;
          }
        } else {
          _lastTriggeredState = null;
        }
      }
    } else if (newState == LiquidLevelState.normal) {
      _lastTriggeredState = null;
    }
  }

  Future<void> disconnect() async {
    stopSimulation();
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    _bluetooth.disconnect();
    _currentLevel = 0.0;
    _smoothedLevel = 0.0;
    _isStable = false;
    _stableSampleCount = 0;
    _levelBuffer.clear();
    _currentState = LiquidLevelState.normal;
    _lastTriggeredState = null;
  }

  Future<String?> getBoundContainerCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(StorageConstants.levelSensorContainerCode);
    } catch (e) {
      return null;
    }
  }

  Future<void> bindContainer(String containerCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          StorageConstants.levelSensorContainerCode, containerCode);
      LoggerUtil.info('液位传感器已绑定容器: $containerCode');
    } catch (e) {
      LoggerUtil.error('绑定容器失败: $e');
    }
  }

  Future<void> unbindContainer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageConstants.levelSensorContainerCode);
      LoggerUtil.info('液位传感器已解除容器绑定');
    } catch (e) {
      LoggerUtil.error('解除容器绑定失败: $e');
    }
  }

  bool get isSimulationRunning => _simulationRunning;

  void dispose() {
    disconnect();
    _readingController.close();
    _stateController.close();
  }
}
