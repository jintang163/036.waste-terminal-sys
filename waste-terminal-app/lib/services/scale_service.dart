import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/app_constants.dart';
import '../models/scale_calibration.dart';
import '../utils/logger_util.dart';
import 'bluetooth_service.dart';

/// 地磅服务状态
enum ScaleServiceStatus {
  idle,
  connecting,
  connected,
  simulating,
  calibrating,
  error,
}

/// 校准步骤
enum CalibrationStep {
  idle,
  waitingZero,
  waitingFirstWeight,
  waitingSecondWeight,
  completed,
  cancelled,
}

/// 地磅重量读数
class ScaleReading {
  final double netWeight;
  final double rawWeight;
  final double calibratedWeight;
  final bool isStable;
  final DateTime timestamp;

  ScaleReading({
    required this.netWeight,
    required this.rawWeight,
    required this.calibratedWeight,
    required this.isStable,
    required this.timestamp,
  });
}

/// 地磅服务：支持蓝牙真实重量驱动、校准参数按设备分存、硬件/软件协同归零去皮
class ScaleService {
  // 单例
  static final ScaleService _instance = ScaleService._internal();
  factory ScaleService() => _instance;
  ScaleService._internal();

  // 依赖
  final BluetoothService _bluetooth = BluetoothService();
  static const _uuid = Uuid();

  // 状态
  ScaleServiceStatus _status = ScaleServiceStatus.idle;
  CalibrationStep _calibrationStep = CalibrationStep.idle;
  String? _lastErrorMessage;
  ScaleCalibrationParams _params = ScaleCalibrationParams(
    lastCalibrationTime: DateTime.now(),
  );

  // 读数相关
  double _rawWeight = 0.0;
  double _previousRawWeight = 0.0;
  bool _isWeightStable = false;
  int _stableSampleCount = 0;
  static const int _defaultStableSamples = 5;
  static const double _defaultStableThreshold = 0.005;
  DateTime _lastReadingTime = DateTime.now();

  // 三点校准临时变量
  double? _calibrationRawZero;
  double? _calibrationRawFirst;
  double? _calibrationKnownFirst;
  double? _calibrationRawSecond;
  double? _calibrationKnownSecond;

  // 模拟模式定时器
  Timer? _simulationTimer;
  final Random _random = Random();
  double _simulationBaseWeight = 0.0;
  double _simulationNoise = 0.002;

  // 蓝牙订阅
  StreamSubscription<double>? _bluetoothWeightSubscription;

  // 校准历史
  final List<ScaleCalibrationRecord> _history = [];
  static const int _maxHistoryCount = 50;

  // Stream 控制器
  final _statusController = StreamController<ScaleServiceStatus>.broadcast();
  final _weightController = StreamController<ScaleReading>.broadcast();
  final _stableController = StreamController<bool>.broadcast();
  final _calibrationStepController = StreamController<CalibrationStep>.broadcast();
  final _paramsController = StreamController<ScaleCalibrationParams>.broadcast();

  // Stream 暴露
  Stream<ScaleServiceStatus> get statusStream => _statusController.stream;
  Stream<ScaleReading> get weightStream => _weightController.stream;
  Stream<bool> get stableStream => _stableController.stream;
  Stream<CalibrationStep> get calibrationStepStream =>
      _calibrationStepController.stream;
  Stream<ScaleCalibrationParams> get paramsStream => _paramsController.stream;

  // 当前状态
  ScaleServiceStatus get status => _status;
  CalibrationStep get calibrationStep => _calibrationStep;
  ScaleCalibrationParams get params => _params;
  double get rawWeight => _rawWeight;
  bool get isWeightStable => _isWeightStable;
  String? get lastErrorMessage => _lastErrorMessage;
  List<ScaleCalibrationRecord> get history =>
      List.unmodifiable(_history);
  bool get isUsingHardwareSource =>
      _status == ScaleServiceStatus.connected;

  // ===================================================================
  // 初始化 & 蓝牙数据源接入
  // ===================================================================

  /// 连接蓝牙地磅并将真实解析重量作为数据源
  Future<bool> connectAndAttach({
    String? deviceAddress,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _setStatus(ScaleServiceStatus.connecting);
    _lastErrorMessage = null;
    try {
      bool ok;
      if (deviceAddress != null && deviceAddress.isNotEmpty) {
        ok = await _bluetooth.connectByAddress(deviceAddress, timeout: timeout);
      } else {
        // 尝试自动连接上一次的设备
        final lastId = _params.deviceAddress;
        if (lastId != null && lastId.isNotEmpty) {
          ok = await _bluetooth.connectByAddress(lastId, timeout: timeout);
        } else {
          throw Exception('未指定地磅设备地址，且无历史连接记录');
        }
      }
      if (!ok) {
        throw Exception('蓝牙连接失败');
      }
      // 设备连接成功：按设备地址加载专属校准参数
      final addr = _bluetooth.deviceId;
      final name = _bluetooth.connectedDevice?.name;
      await loadSavedParams(deviceAddress: addr, fallbackDeviceName: name);
      // 绑定蓝牙真实重量流作为数据源
      _attachBluetoothWeightStream();
      _setStatus(ScaleServiceStatus.connected);
      _notifyParams();
      return true;
    } catch (e) {
      LoggerUtil.error('连接地磅失败', e);
      _lastErrorMessage = e.toString();
      _setStatus(ScaleServiceStatus.error);
      // 连接失败自动回落模拟模式，避免流程卡死
      _startSimulationMode();
      return false;
    }
  }

  /// 断开地磅
  Future<void> disconnect() async {
    await _bluetoothWeightSubscription?.cancel();
    _bluetoothWeightSubscription = null;
    _stopSimulation();
    _bluetooth.disconnect();
    _rawWeight = 0.0;
    _isWeightStable = false;
    _setStatus(ScaleServiceStatus.idle);
    _broadcastReading();
  }

  /// 启动模拟模式（无真实设备时的降级方案）
  void _startSimulationMode() {
    _stopSimulation();
    _setStatus(ScaleServiceStatus.simulating);
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final noise = (_random.nextDouble() - 0.5) * 2 * _simulationNoise;
      _rawWeight = _simulationBaseWeight + noise;
      _lastReadingTime = DateTime.now();
      _updateStability(_rawWeight);
      _broadcastReading();
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  /// 手动设置模拟重量（测试用）
  void setSimulationWeight(double w) {
    _simulationBaseWeight = w;
  }

  // ===================================================================
  // 蓝牙真实重量流接入（BUG 1 修复核心）
  // ===================================================================

  /// 订阅蓝牙解析后的真实重量流作为 ScaleService 的原始读数来源
  void _attachBluetoothWeightStream() {
    _bluetoothWeightSubscription?.cancel();
    _bluetoothWeightSubscription =
        _bluetooth.weightStream.listen((bluetoothWeightKg) {
      // 蓝牙已经解析为千克单位的真实数值 -> 直接作为 rawWeight
      updateRawWeightFromBluetooth(bluetoothWeightKg);
    });
  }

  /// 外部（蓝牙服务）推送真实解析重量的入口
  ///
  /// 这是校准链路最上游的数据源：
  ///   蓝牙原始字节 → BluetoothService._parseScaleData → 数值 kg → 本方法 → 后续校准/稳定判定
  void updateRawWeightFromBluetooth(double bluetoothParsedWeightKg) {
    _rawWeight = bluetoothParsedWeightKg;
    _lastReadingTime = DateTime.now();
    _updateStability(_rawWeight);
    _broadcastReading();
  }

  // ===================================================================
  // 按设备地址分存校准参数（BUG 2 修复核心）
  // ===================================================================

  static String _paramsKeyForDevice(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return StorageConstants.scaleCalibrationParams;
    }
    return '${StorageConstants.scaleCalibrationParams}_$deviceId';
  }

  static const String _deviceIndexKey = '${StorageConstants.scaleCalibrationParams}_index';

  /// 加载指定设备的校准参数
  ///
  /// 优先级：
  ///   1. deviceAddress 显式指定的设备专属参数
  ///   2. 当前已连接蓝牙设备地址的专属参数
  ///   3. 全局默认参数（向后兼容）
  ///   4. 新建默认参数
  Future<ScaleCalibrationParams> loadSavedParams({
    String? deviceAddress,
    String? fallbackDeviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final addr = deviceAddress ?? _bluetooth.deviceId ?? _params.deviceAddress;
    String key = _paramsKeyForDevice(addr);

    // 先尝试加载指定设备
    String? jsonStr = prefs.getString(key);

    // 无专属参数：尝试向后兼容的全局参数
    if ((jsonStr == null || jsonStr.isEmpty) &&
        addr != null &&
        addr.isNotEmpty) {
      final legacy = prefs.getString(StorageConstants.scaleCalibrationParams);
      if (legacy != null && legacy.isNotEmpty) {
        final legacyParams = ScaleCalibrationParams.fromJson(legacy);
        // 从全局迁移到设备专属（升级迁移）
        final migrated = legacyParams.copyWith(
          deviceAddress: addr,
          deviceName: fallbackDeviceName ?? legacyParams.deviceName,
        );
        _params = migrated;
        unawaited(_saveParams(prefs));
        unawaited(_addToDeviceIndex(prefs, addr));
        _notifyParams();
        await loadHistory();
        return _params;
      }
    }

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final loaded = ScaleCalibrationParams.fromJson(jsonStr);
        _params = loaded.copyWith(
          deviceAddress: addr ?? loaded.deviceAddress,
          deviceName:
              fallbackDeviceName ?? loaded.deviceName ?? _bluetooth.connectedDevice?.name,
        );
      } catch (e) {
        LoggerUtil.error('加载校准参数失败，使用默认值', e);
        _params = ScaleCalibrationParams(
          lastCalibrationTime: DateTime.now(),
          deviceAddress: addr,
          deviceName: fallbackDeviceName,
        );
      }
    } else {
      _params = ScaleCalibrationParams(
        lastCalibrationTime: DateTime.now(),
        deviceAddress: addr,
        deviceName: fallbackDeviceName,
      );
    }
    unawaited(_addToDeviceIndex(prefs, addr));
    _notifyParams();
    await loadHistory();
    return _params;
  }

  /// 保存当前设备参数
  Future<void> _saveParams([SharedPreferences? passedPrefs]) async {
    final prefs = passedPrefs ?? await SharedPreferences.getInstance();
    final String key = _paramsKeyForDevice(_params.deviceAddress);
    await prefs.setString(key, _params.toJson());
    await prefs.setString(StorageConstants.scaleZeroValue,
        _params.totalZeroOffset.toString());
    await prefs.setString(StorageConstants.scaleTareValue,
        _params.totalTare.toString());
    await _addToDeviceIndex(prefs, _params.deviceAddress);
    _notifyParams();
  }

  static Future<void> _addToDeviceIndex(
      SharedPreferences prefs, String? deviceId) async {
    if (deviceId == null || deviceId.isEmpty) return;
    final Set<String> idx = {
      ...(prefs.getStringList(_deviceIndexKey) ?? <String>[])
    };
    idx.add(deviceId);
    await prefs.setStringList(_deviceIndexKey, idx.toList());
  }

  /// 列出所有已校准设备的地址
  Future<List<String>> listCalibratedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_deviceIndexKey) ?? <String>[];
  }

  /// 删除指定设备的校准参数
  Future<bool> deleteDeviceParams(String deviceAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _paramsKeyForDevice(deviceAddress);
    await prefs.remove(key);
    final Set<String> idx = {
      ...(prefs.getStringList(_deviceIndexKey) ?? <String>[])
    };
    idx.remove(deviceAddress);
    await prefs.setStringList(_deviceIndexKey, idx.toList());
    // 如果删的是当前设备，重置为默认
    if (_params.deviceAddress == deviceAddress) {
      _params = ScaleCalibrationParams(
        lastCalibrationTime: DateTime.now(),
        deviceAddress: _bluetooth.deviceId,
      );
      _notifyParams();
    }
    return true;
  }

  // ===================================================================
  // 硬件/软件协同：归零 & 去皮（BUG 3 修复核心）
  // ===================================================================

  /// 策略说明：
  ///   hardwareFirst  → 先尝试硬件指令 sendScaleZeroCommand/sendScaleTareCommand；
  ///                    成功后将当前校准后重量写入 hardwareZeroOffset/hardwareTare，
  ///                    并将同名字段的 software* 清零；
  ///                    失败则自动 fallback 为软件偏移，记录 actionType = hardwareFallbackSoftware
  ///   softwareOnly   → 不发送硬件指令，仅在应用层扣减
  ///   hardwareOnly   → 只发硬件指令，失败直接抛错，不软件补偿
  Future<void> zero({CalibrationSynergyMode? mode}) async {
    final effectiveMode = mode ?? _params.synergyMode;
    final CalibrationActionType actionType;
    final oldParams = _params;
    Exception? hardwareError;

    // —— 等待重量稳定 ——
    final rawStable =
        await getStableRawWeight(timeout: const Duration(seconds: 8));
    final calibrated = _params.apply(rawStable);

    // —— 1. 硬件指令尝试 ——
    bool hwSuccess = false;
    if (effectiveMode != CalibrationSynergyMode.softwareOnly) {
      try {
        if (!_bluetooth.isConnected) {
          throw Exception('蓝牙未连接，无法发送硬件指令');
        }
        await _bluetooth.sendScaleZeroCommand();
        // 硬件执行：硬件寄存器已清零，之后蓝牙推送的 raw 就是去除零点后的值
        // 因此 hardwareZeroOffset 重置为 0，并清空 softwareZeroOffset
        hwSuccess = true;
      } catch (e) {
        hardwareError = e is Exception ? e : Exception(e.toString());
        LoggerUtil.warning('硬件归零指令失败: $e');
      }
    }

    // —— 2. 软件补偿决策 ——
    if (hwSuccess) {
      actionType = CalibrationActionType.hardware;
      _params = _params.copyWith(
        hardwareZeroOffset: 0.0,
        softwareZeroOffset: 0.0,
        lastCalibrationTime: DateTime.now(),
        isCalibrated: _params.isCalibrated || true,
      );
    } else {
      if (effectiveMode == CalibrationSynergyMode.hardwareOnly) {
        throw hardwareError ?? Exception('硬件归零失败');
      }
      // softwareOnly 或 hardwareFirst 回落
      actionType = (effectiveMode == CalibrationSynergyMode.softwareOnly)
          ? CalibrationActionType.software
          : CalibrationActionType.hardwareFallbackSoftware;
      _params = _params.copyWith(
        // 硬件失败时不触动 hardwareZeroOffset，仅把当前校准重量作为附加软件补偿
        softwareZeroOffset: _params.softwareZeroOffset + calibrated,
        lastCalibrationTime: DateTime.now(),
        isCalibrated: true,
      );
    }

    _appendHistory(
      oldParams: oldParams,
      newParams: _params,
      actionType: actionType,
      remark: hardwareError != null ? '硬件失败原因: ${hardwareError.message}' : null,
    );
    await _saveParams();
  }

  Future<void> tare({CalibrationSynergyMode? mode}) async {
    final effectiveMode = mode ?? _params.synergyMode;
    final CalibrationActionType actionType;
    final oldParams = _params;
    Exception? hardwareError;

    final rawStable =
        await getStableRawWeight(timeout: const Duration(seconds: 8));
    final net = _params.getNetWeight(rawStable);

    bool hwSuccess = false;
    if (effectiveMode != CalibrationSynergyMode.softwareOnly) {
      try {
        if (!_bluetooth.isConnected) {
          throw Exception('蓝牙未连接，无法发送硬件指令');
        }
        await _bluetooth.sendScaleTareCommand();
        hwSuccess = true;
      } catch (e) {
        hardwareError = e is Exception ? e : Exception(e.toString());
        LoggerUtil.warning('硬件去皮指令失败: $e');
      }
    }

    if (hwSuccess) {
      actionType = CalibrationActionType.hardware;
      _params = _params.copyWith(
        hardwareTare: 0.0,
        softwareTare: 0.0,
        lastCalibrationTime: DateTime.now(),
        isCalibrated: true,
      );
    } else {
      if (effectiveMode == CalibrationSynergyMode.hardwareOnly) {
        throw hardwareError ?? Exception('硬件去皮失败');
      }
      actionType = (effectiveMode == CalibrationSynergyMode.softwareOnly)
          ? CalibrationActionType.software
          : CalibrationActionType.hardwareFallbackSoftware;
      _params = _params.copyWith(
        softwareTare: _params.softwareTare + net,
        lastCalibrationTime: DateTime.now(),
        isCalibrated: true,
      );
    }

    _appendHistory(
      oldParams: oldParams,
      newParams: _params,
      actionType: actionType,
      remark: hardwareError != null ? '硬件失败原因: ${hardwareError.message}' : null,
    );
    await _saveParams();
  }

  /// 仅清皮重（不发硬件指令，仅复位软件皮重；如需硬件清皮另发指令）
  Future<void> clearTare() async {
    final oldParams = _params;
    _params = _params.copyWith(
      softwareTare: 0.0,
      // 保留 hardwareTare 不变，因为那是硬件端寄存器状态，
      // 用户若希望硬件端清皮请使用 tare(hardwareOnly) 重新去皮或硬件按键
    );
    _appendHistory(
      oldParams: oldParams,
      newParams: _params,
      actionType: CalibrationActionType.software,
      remark: '清除软件皮重',
    );
    await _saveParams();
  }

  // ===================================================================
  // 三点线性校准（核心：raw 为蓝牙真实 raw 驱动的值）
  // ===================================================================

  void startCalibration() {
    _calibrationStep = CalibrationStep.waitingZero;
    _calibrationRawZero = null;
    _calibrationRawFirst = null;
    _calibrationKnownFirst = null;
    _calibrationRawSecond = null;
    _calibrationKnownSecond = null;
    _setStatus(ScaleServiceStatus.calibrating);
    _calibrationStepController.add(_calibrationStep);
  }

  /// 捕获空秤的原始读数（蓝牙真实 raw）
  Future<double> captureZeroPoint({Duration? timeout}) async {
    _calibrationStep = CalibrationStep.waitingZero;
    _calibrationStepController.add(_calibrationStep);
    final raw = await getStableRawWeight(
      timeout: timeout ?? const Duration(seconds: 10),
      requiredSamples: 8,
      threshold: 0.003,
    );
    _calibrationRawZero = raw;
    _calibrationStep = CalibrationStep.waitingFirstWeight;
    _calibrationStepController.add(_calibrationStep);
    return raw;
  }

  Future<double> captureFirstPoint(double knownWeight, {Duration? timeout}) async {
    if (knownWeight <= 0) {
      throw Exception('标准砝码重量必须大于0');
    }
    _calibrationKnownFirst = knownWeight;
    final raw = await getStableRawWeight(
      timeout: timeout ?? const Duration(seconds: 10),
      requiredSamples: 8,
      threshold: 0.003,
    );
    _calibrationRawFirst = raw;
    _calibrationStep = CalibrationStep.waitingSecondWeight;
    _calibrationStepController.add(_calibrationStep);
    return raw;
  }

  Future<double> captureSecondPoint(double knownWeight, {Duration? timeout}) async {
    if (_calibrationKnownFirst == null || _calibrationRawFirst == null) {
      throw Exception('请先完成第一点校准');
    }
    if (knownWeight <= _calibrationKnownFirst!) {
      throw Exception('第二点砝码重量必须大于第一点');
    }
    _calibrationKnownSecond = knownWeight;
    final raw = await getStableRawWeight(
      timeout: timeout ?? const Duration(seconds: 10),
      requiredSamples: 8,
      threshold: 0.003,
    );
    _calibrationRawSecond = raw;
    return raw;
  }

  Future<ScaleCalibrationParams> applyCalibration() async {
    if (_calibrationRawFirst == null ||
        _calibrationRawSecond == null ||
        _calibrationKnownFirst == null ||
        _calibrationKnownSecond == null) {
      throw Exception('请完成所有校准点采集');
    }
    final raw1 = _calibrationRawFirst!;
    final raw2 = _calibrationRawSecond!;
    final w1 = _calibrationKnownFirst!;
    final w2 = _calibrationKnownSecond!;
    if ((raw2 - raw1).abs() < 0.0001) {
      throw Exception('两个校准点原始读数接近，无法校准');
    }

    final slope = (w2 - w1) / (raw2 - raw1);
    final intercept = w1 - slope * raw1;

    // 计算经过校准后的零点偏移（以「当前空秤校准后读数」作为新的零点）
    final raw0 = _calibrationRawZero ?? raw1;
    final double zeroAfterCal = slope * raw0 + intercept;

    final oldParams = _params;
    final now = DateTime.now();
    final points = [
      ScaleCalibrationPoint(knownWeight: 0, rawReading: raw0, timestamp: now),
      ScaleCalibrationPoint(knownWeight: w1, rawReading: raw1, timestamp: now),
      ScaleCalibrationPoint(knownWeight: w2, rawReading: raw2, timestamp: now),
    ];
    _params = _params.copyWith(
      slope: slope,
      intercept: intercept,
      // 校准后的零点用软件补偿来「置零」，避免重发硬件指令
      softwareZeroOffset: zeroAfterCal,
      hardwareZeroOffset: 0,
      calibrationPoints: points,
      lastCalibrationTime: now,
      calibrationCount: _params.calibrationCount + 1,
      isCalibrated: true,
    );
    _calibrationStep = CalibrationStep.completed;
    _calibrationStepController.add(_calibrationStep);
    _setStatus(
        _status == ScaleServiceStatus.calibrating
            ? (_bluetooth.isConnected
                ? ScaleServiceStatus.connected
                : ScaleServiceStatus.simulating)
            : _status);
    _appendHistory(
      oldParams: oldParams,
      newParams: _params,
      actionType: CalibrationActionType.software,
      remark: '三点线性校准完成: 0kg@$raw0 / ${w1}kg@$raw1 / ${w2}kg@$raw2',
    );
    await _saveParams();
    return _params;
  }

  void cancelCalibration() {
    _calibrationStep = CalibrationStep.cancelled;
    _calibrationRawZero = null;
    _calibrationRawFirst = null;
    _calibrationKnownFirst = null;
    _calibrationRawSecond = null;
    _calibrationKnownSecond = null;
    _calibrationStepController.add(_calibrationStep);
    _setStatus(_bluetooth.isConnected
        ? ScaleServiceStatus.connected
        : ScaleServiceStatus.simulating);
  }

  // ===================================================================
  // 稳定判定 & 工具方法
  // ===================================================================

  void _updateStability(double current) {
    final diff = (current - _previousRawWeight).abs();
    if (diff <= _defaultStableThreshold) {
      _stableSampleCount++;
    } else {
      _stableSampleCount = 0;
    }
    final bool nowStable = _stableSampleCount >= _defaultStableSamples;
    if (nowStable != _isWeightStable) {
      _isWeightStable = nowStable;
      _stableController.add(_isWeightStable);
    }
    _previousRawWeight = current;
  }

  Future<double> getStableRawWeight({
    Duration timeout = const Duration(seconds: 10),
    int requiredSamples = _defaultStableSamples,
    double threshold = _defaultStableThreshold,
  }) async {
    final stopwatch = Stopwatch()..start();
    int count = 0;
    double last = _rawWeight;
    final buffer = <double>[];
    final completer = Completer<double>();

    void check() {
      if (completer.isCompleted) return;
      if (buffer.length >= requiredSamples) {
        final recent = buffer.sublist(buffer.length - requiredSamples);
        final maxV = recent.reduce(max);
        final minV = recent.reduce(min);
        if (maxV - minV <= threshold) {
          final avg = recent.reduce((a, b) => a + b) / recent.length;
          completer.complete(avg);
        }
      }
      if (stopwatch.elapsed > timeout && !completer.isCompleted) {
        completer.complete(_rawWeight); // 超时返回当前值
      }
    }

    final subscription = _weightController.stream.listen((reading) {
      buffer.add(reading.rawWeight);
      if (buffer.length > requiredSamples * 3) {
        buffer.removeRange(0, buffer.length - requiredSamples * 3);
      }
      count++;
      last = reading.rawWeight;
      check();
    });

    try {
      // 立即用现有 _rawWeight 初值
      buffer.add(_rawWeight);
      check();
      final result = await completer.future.timeout(timeout, onTimeout: () => last);
      return result;
    } finally {
      await subscription.cancel();
      stopwatch.stop();
    }
  }

  Future<ScaleReading> getStableWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final raw = await getStableRawWeight(timeout: timeout);
    return ScaleReading(
      netWeight: _params.getNetWeight(raw),
      rawWeight: raw,
      calibratedWeight: _params.apply(raw),
      isStable: true,
      timestamp: DateTime.now(),
    );
  }

  Future<ScaleReading> readWeight() async {
    if (_bluetooth.isConnected && _status == ScaleServiceStatus.connected) {
      try {
        await _bluetooth.sendScaleReadCommand();
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (_) {}
    }
    return _currentReading();
  }

  ScaleReading _currentReading() {
    return ScaleReading(
      netWeight: _params.getNetWeight(_rawWeight),
      rawWeight: _rawWeight,
      calibratedWeight: _params.apply(_rawWeight),
      isStable: _isWeightStable,
      timestamp: _lastReadingTime,
    );
  }

  void _broadcastReading() {
    _weightController.add(_currentReading());
  }

  // ===================================================================
  // 状态广播
  // ===================================================================

  void _setStatus(ScaleServiceStatus s) {
    if (_status != s) {
      _status = s;
      _statusController.add(_status);
    }
  }

  void _notifyParams() {
    _paramsController.add(_params);
  }

  // ===================================================================
  // 历史记录
  // ===================================================================

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(StorageConstants.scaleCalibrationHistory);
      if (jsonStr == null || jsonStr.isEmpty) {
        _history.clear();
        return;
      }
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final all = list
          .map((e) =>
              ScaleCalibrationRecord.fromMap(e as Map<String, dynamic>))
          .toList();
      // 仅载入当前设备相关的（所有历史都保留，但UI按device过滤）
      _history
        ..clear()
        ..addAll(all);
    } catch (e) {
      LoggerUtil.error('加载校准历史失败', e);
    }
  }

  void _appendHistory({
    required ScaleCalibrationParams oldParams,
    required ScaleCalibrationParams newParams,
    required CalibrationActionType actionType,
    String? operatorName,
    String? remark,
  }) {
    final record = ScaleCalibrationRecord(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      deviceAddress: newParams.deviceAddress ?? '',
      deviceName: newParams.deviceName ?? '',
      oldSlope: oldParams.slope,
      oldIntercept: oldParams.intercept,
      newSlope: newParams.slope,
      newIntercept: newParams.intercept,
      oldZero: oldParams.totalZeroOffset,
      newZero: newParams.totalZeroOffset,
      oldTare: oldParams.totalTare,
      newTare: newParams.totalTare,
      actionType: actionType,
      operatorName: operatorName,
      remark: remark,
    );
    _history.insert(0, record);
    if (_history.length > _maxHistoryCount) {
      _history.removeRange(_maxHistoryCount, _history.length);
    }
    unawaited(_saveHistory());
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr =
          jsonEncode(_history.map((e) => e.toMap()).toList());
      await prefs.setString(StorageConstants.scaleCalibrationHistory, jsonStr);
    } catch (e) {
      LoggerUtil.error('保存校准历史失败', e);
    }
  }

  List<ScaleCalibrationRecord> historyForDevice(String? deviceAddress) {
    if (deviceAddress == null || deviceAddress.isEmpty) {
      return history;
    }
    return history.where((r) => r.deviceAddress == deviceAddress).toList();
  }

  // ===================================================================
  // 手动设置 & 重置
  // ===================================================================

  Future<void> setSynergyMode(CalibrationSynergyMode mode) async {
    _params = _params.copyWith(synergyMode: mode);
    await _saveParams();
  }

  Future<void> setParamsManually({
    required double slope,
    required double intercept,
    double? softwareZero,
    double? softwareTare,
  }) async {
    final oldParams = _params;
    _params = _params.copyWith(
      slope: slope,
      intercept: intercept,
      softwareZeroOffset: softwareZero ?? _params.softwareZeroOffset,
      softwareTare: softwareTare ?? _params.softwareTare,
      lastCalibrationTime: DateTime.now(),
      isCalibrated: true,
    );
    _appendHistory(
      oldParams: oldParams,
      newParams: _params,
      actionType: CalibrationActionType.software,
      remark: '手动设置校准参数',
    );
    await _saveParams();
  }

  Future<void> resetToDefault() async {
    final oldParams = _params;
    final now = DateTime.now();
    _params = ScaleCalibrationParams(
      lastCalibrationTime: now,
      deviceAddress: oldParams.deviceAddress,
      deviceName: oldParams.deviceName,
      synergyMode: oldParams.synergyMode,
    );
    _appendHistory(
      oldParams: oldParams,
      newParams: _params,
      actionType: CalibrationActionType.software,
      remark: '恢复默认参数',
    );
    await _saveParams();
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _weightController.close();
    _stableController.close();
    _calibrationStepController.close();
    _paramsController.close();
  }
}

extension on Exception {
  String get message => toString().replaceFirst('Exception: ', '');
}

void unawaited(Future<void>? future) {}
