import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';

import '../config/app_constants.dart';
import '../models/scale_calibration.dart';
import '../utils/sp_util.dart';

enum ScaleStatus { disconnected, connecting, connected, error }

enum CalibrationStep {
  idle,
  zeroPoint,
  firstPoint,
  secondPoint,
  completed,
  failed,
}

class ScaleService {
  static final ScaleService _instance = ScaleService._internal();
  factory ScaleService() => _instance;

  final Logger _logger = Logger();

  ScaleStatus _status = ScaleStatus.disconnected;
  double _rawWeight = 0.0;
  String? _currentUnit = 'kg';
  bool _isStable = false;

  String? _deviceAddress;
  int? _baudRate = 9600;

  ScaleCalibrationParams _params = ScaleCalibrationParams(
    lastCalibrationTime: DateTime.now(),
  );
  final List<ScaleCalibrationRecord> _history = [];

  CalibrationStep _calibrationStep = CalibrationStep.idle;
  ScaleCalibrationPoint? _zeroCalibrationPoint;
  ScaleCalibrationPoint? _firstCalibrationPoint;
  ScaleCalibrationPoint? _secondCalibrationPoint;
  final StreamController<CalibrationStep> _calibrationStepController =
      StreamController<CalibrationStep>.broadcast();

  final StreamController<double> _weightStreamController =
      StreamController<double>.broadcast();
  final StreamController<ScaleStatus> _statusStreamController =
      StreamController<ScaleStatus>.broadcast();
  final StreamController<bool> _stableStreamController =
      StreamController<bool>.broadcast();
  final StreamController<ScaleCalibrationParams> _paramsStreamController =
      StreamController<ScaleCalibrationParams>.broadcast();

  Timer? _simulationTimer;

  ScaleService._internal();

  ScaleStatus get status => _status;
  double get rawWeight => _rawWeight;
  double get calibratedWeight => _params.apply(_rawWeight);
  double get netWeight => _params.getNetWeight(_rawWeight);
  double get tareWeight => _params.currentTare;
  double get zeroOffset => _params.zeroOffset;
  double get slope => _params.slope;
  double get intercept => _params.intercept;
  String? get currentUnit => _currentUnit;
  bool get isStable => _isStable;
  bool get isConnected => _status == ScaleStatus.connected;
  bool get isCalibrated => _params.isCalibrated;
  ScaleCalibrationParams get calibrationParams => _params;
  CalibrationStep get calibrationStep => _calibrationStep;
  List<ScaleCalibrationRecord> get history => List.unmodifiable(_history);

  Stream<double> get weightStream => _weightStreamController.stream;
  Stream<ScaleStatus> get statusStream => _statusStreamController.stream;
  Stream<bool> get stableStream => _stableStreamController.stream;
  Stream<ScaleCalibrationParams> get paramsStream => _paramsStreamController.stream;
  Stream<CalibrationStep> get calibrationStepStream =>
      _calibrationStepController.stream;

  Future<void> loadSavedParams() async {
    try {
      final json = SpUtil.getString(StorageConstants.scaleCalibrationParams);
      if (json != null && json.isNotEmpty) {
        _params = ScaleCalibrationParams.fromJson(json);
        _paramsStreamController.add(_params);
        _logger.i('加载地磅校准参数: slope=${_params.slope}, '
            'intercept=${_params.intercept}, zero=${_params.zeroOffset}, '
            'tare=${_params.currentTare}');
      }
      final historyJson =
          SpUtil.getStringList(StorageConstants.scaleCalibrationHistory);
      if (historyJson != null) {
        _history.clear();
        _history.addAll(
            historyJson.map((e) => ScaleCalibrationRecord.fromJson(e)));
      }
    } catch (e) {
      _logger.w('加载地磅校准参数失败: $e');
    }
  }

  Future<void> _saveParams() async {
    await SpUtil.putString(
        StorageConstants.scaleCalibrationParams, _params.toJson());
    await SpUtil.putDouble(
        StorageConstants.scaleZeroValue, _params.zeroOffset);
    await SpUtil.putDouble(
        StorageConstants.scaleTareValue, _params.currentTare);
    _paramsStreamController.add(_params);
  }

  Future<void> _saveHistory() async {
    if (_history.length > 50) {
      _history.removeRange(0, _history.length - 50);
    }
    await SpUtil.putStringList(StorageConstants.scaleCalibrationHistory,
        _history.map((e) => e.toJson()).toList());
  }

  void setDeviceConfig({
    required String deviceAddress,
    int baudRate = 9600,
  }) {
    _deviceAddress = deviceAddress;
    _baudRate = baudRate;
    _logger.d('地磅设备配置: $deviceAddress, 波特率: $baudRate');
  }

  Future<void> connect() async {
    try {
      if (_status == ScaleStatus.connecting) {
        _logger.w('地磅正在连接中');
        return;
      }

      if (_deviceAddress == null || _deviceAddress!.isEmpty) {
        throw Exception('未配置地磅设备地址');
      }

      _updateStatus(ScaleStatus.connecting);
      _logger.d('正在连接地磅: $_deviceAddress');

      await Future.delayed(const Duration(seconds: 2));
      await loadSavedParams();

      _updateStatus(ScaleStatus.connected);
      _startWeightSimulation();

      _logger.i('地磅连接成功: $_deviceAddress, 校准状态: ${_params.statusText}');
    } catch (e) {
      _logger.e('连接地磅失败: $e');
      _updateStatus(ScaleStatus.error);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      _simulationTimer?.cancel();
      _simulationTimer = null;

      _rawWeight = 0.0;
      _isStable = false;
      _calibrationStep = CalibrationStep.idle;
      _zeroCalibrationPoint = null;
      _firstCalibrationPoint = null;
      _secondCalibrationPoint = null;

      _weightStreamController.add(0.0);
      _stableStreamController.add(false);
      _calibrationStepController.add(CalibrationStep.idle);

      _updateStatus(ScaleStatus.disconnected);
      _logger.i('地磅已断开连接');
    } catch (e) {
      _logger.e('断开地磅失败: $e');
    }
  }

  void _startWeightSimulation() {
    double targetWeight = 125.5;
    double variation = 0.1;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_status != ScaleStatus.connected) {
        timer.cancel();
        return;
      }

      double randomVariation =
          (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
      randomVariation = (randomVariation - 0.5) * 2 * variation;
      double newWeight = targetWeight + randomVariation;

      if ((newWeight - _rawWeight).abs() < 0.02) {
        if (!_isStable) {
          _isStable = true;
          _stableStreamController.add(true);
        }
      } else {
        if (_isStable) {
          _isStable = false;
          _stableStreamController.add(false);
        }
      }

      _rawWeight = double.parse(newWeight.toStringAsFixed(3));
      _weightStreamController.add(_params.getNetWeight(_rawWeight));
    });
  }

  Future<double> readRawWeight() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }
      return _rawWeight;
    } catch (e) {
      _logger.e('读取原始重量失败: $e');
      rethrow;
    }
  }

  Future<double> readWeight() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }
      return netWeight;
    } catch (e) {
      _logger.e('读取重量失败: $e');
      rethrow;
    }
  }

  Future<double> getStableWeight({
    Duration timeout = const Duration(seconds: 5),
    int stableCount = 3,
  }) async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }

      if (_isStable) {
        return netWeight;
      }

      Completer<double> completer = Completer<double>();
      Timer? timeoutTimer;
      int currentStableCount = 0;
      double lastWeight = 0;

      StreamSubscription<double>? subscription;

      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(ScaleTimeoutException('等待重量稳定超时'));
        }
      });

      subscription = _weightStreamController.stream.listen((weight) {
        if ((weight - lastWeight).abs() < 0.01) {
          currentStableCount++;
          if (currentStableCount >= stableCount) {
            subscription?.cancel();
            timeoutTimer?.cancel();
            if (!completer.isCompleted) {
              completer.complete(weight);
            }
          }
        } else {
          currentStableCount = 0;
          lastWeight = weight;
        }
      });

      return completer.future;
    } catch (e) {
      _logger.e('获取稳定重量失败: $e');
      rethrow;
    }
  }

  Future<double> getStableRawWeight({
    Duration timeout = const Duration(seconds: 5),
    int stableCount = 5,
  }) async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }
      if (_isStable) {
        return _rawWeight;
      }
      final rawStream = Stream.periodic(const Duration(milliseconds: 250), (_) {
        return _rawWeight;
      });
      double last = _rawWeight;
      int stable = 0;
      final completer = Completer<double>();
      Timer? t;
      t = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(ScaleTimeoutException('获取稳定重量超时'));
        }
      });
      final sub = rawStream.listen((v) {
        if ((v - last).abs() < 0.005) {
          stable++;
          if (stable >= stableCount) {
            t?.cancel();
            if (!completer.isCompleted) completer.complete(v);
          }
        } else {
          stable = 0;
          last = v;
        }
      });
      final result = await completer.future;
      sub.cancel();
      return result;
    } catch (e) {
      _logger.e('获取稳定原始重量失败: $e');
      rethrow;
    }
  }

  // ============== 一键归零 ==============
  Future<void> zero() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }

      _logger.d('执行归零操作');

      final stableRaw = await getStableRawWeight(
          timeout: const Duration(seconds: 3), stableCount: 5);

      final double oldZero = _params.zeroOffset;
      final double oldSlope = _params.slope;
      final double oldIntercept = _params.intercept;

      _params = _params.copyWith(
        zeroOffset: _params.apply(stableRaw),
        lastCalibrationTime: DateTime.now(),
        calibrationCount: _params.calibrationCount + 1,
        isCalibrated: true,
        deviceAddress: _deviceAddress ?? _params.deviceAddress,
      );

      await _saveParams();
      _addHistoryRecord(
        oldSlope: oldSlope,
        oldIntercept: oldIntercept,
        newSlope: _params.slope,
        newIntercept: _params.intercept,
        oldZero: oldZero,
        newZero: _params.zeroOffset,
        remark: '一键归零 (raw=$stableRaw)',
      );

      _weightStreamController.add(_params.getNetWeight(_rawWeight));
      _logger.i('归零完成: 零点从 $oldZero → ${_params.zeroOffset}');
    } catch (e) {
      _logger.e('归零失败: $e');
      rethrow;
    }
  }

  // ============== 去皮 ==============
  Future<void> tare() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }
      _logger.d('执行去皮操作');
      final stable = await getStableRawWeight(
          timeout: const Duration(seconds: 3), stableCount: 5);
      final netCalibrated = _params.apply(stable) - _params.zeroOffset;
      _params = _params.copyWith(
        currentTare: netCalibrated < 0 ? 0.0 : netCalibrated,
      );
      await _saveParams();
      _weightStreamController.add(_params.getNetWeight(_rawWeight));
      _logger.i('去皮完成: 皮重 = ${_params.currentTare} kg');
    } catch (e) {
      _logger.e('去皮失败: $e');
      rethrow;
    }
  }

  // ============== 清除皮重 ==============
  Future<void> clearTare() async {
    _params = _params.copyWith(currentTare: 0.0);
    await _saveParams();
    _weightStreamController.add(_params.getNetWeight(_rawWeight));
    _logger.i('皮重已清除');
  }

  // ============== 线性校准流程 ==============
  void startCalibration() {
    _calibrationStep = CalibrationStep.zeroPoint;
    _zeroCalibrationPoint = null;
    _firstCalibrationPoint = null;
    _secondCalibrationPoint = null;
    _calibrationStepController.add(_calibrationStep);
    _logger.i('开始线性校准流程');
  }

  Future<ScaleCalibrationPoint> captureZeroPoint() async {
    if (_status != ScaleStatus.connected) {
      throw Exception('地磅未连接');
    }
    if (_calibrationStep != CalibrationStep.zeroPoint) {
      throw Exception('校准步骤错误');
    }
    final raw = await getStableRawWeight(
        timeout: const Duration(seconds: 5), stableCount: 8);
    _zeroCalibrationPoint = ScaleCalibrationPoint(
      knownWeight: 0.0,
      rawReading: raw,
      timestamp: DateTime.now(),
    );
    _calibrationStep = CalibrationStep.firstPoint;
    _calibrationStepController.add(_calibrationStep);
    _logger.i('零点捕获: raw=$raw');
    return _zeroCalibrationPoint!;
  }

  Future<ScaleCalibrationPoint> captureFirstPoint(double knownWeight) async {
    if (_status != ScaleStatus.connected) {
      throw Exception('地磅未连接');
    }
    if (_calibrationStep != CalibrationStep.firstPoint) {
      throw Exception('校准步骤错误');
    }
    if (knownWeight <= 0) {
      throw Exception('已知重量必须大于0');
    }
    final raw = await getStableRawWeight(
        timeout: const Duration(seconds: 5), stableCount: 8);
    _firstCalibrationPoint = ScaleCalibrationPoint(
      knownWeight: knownWeight,
      rawReading: raw,
      timestamp: DateTime.now(),
    );
    _calibrationStep = CalibrationStep.secondPoint;
    _calibrationStepController.add(_calibrationStep);
    _logger.i('第一点捕获: known=$knownWeight, raw=$raw');
    return _firstCalibrationPoint!;
  }

  Future<ScaleCalibrationPoint> captureSecondPoint(double knownWeight) async {
    if (_status != ScaleStatus.connected) {
      throw Exception('地磅未连接');
    }
    if (_calibrationStep != CalibrationStep.secondPoint) {
      throw Exception('校准步骤错误');
    }
    if (_firstCalibrationPoint == null ||
        knownWeight <= _firstCalibrationPoint!.knownWeight) {
      throw Exception('第二点重量必须大于第一点');
    }
    final raw = await getStableRawWeight(
        timeout: const Duration(seconds: 5), stableCount: 8);
    _secondCalibrationPoint = ScaleCalibrationPoint(
      knownWeight: knownWeight,
      rawReading: raw,
      timestamp: DateTime.now(),
    );
    _logger.i('第二点捕获: known=$knownWeight, raw=$raw');
    return _secondCalibrationPoint!;
  }

  Future<ScaleCalibrationParams> applyCalibration({String? remark}) async {
    if (_zeroCalibrationPoint == null ||
        _firstCalibrationPoint == null ||
        _secondCalibrationPoint == null) {
      throw Exception('校准点不完整');
    }
    final double raw0 = _zeroCalibrationPoint!.rawReading;
    final double w1 = _firstCalibrationPoint!.knownWeight;
    final double raw1 = _firstCalibrationPoint!.rawReading;
    final double w2 = _secondCalibrationPoint!.knownWeight;
    final double raw2 = _secondCalibrationPoint!.rawReading;

    double slope, intercept;
    if ((raw2 - raw1).abs() < 1e-9) {
      slope = 1.0;
      intercept = 0.0;
    } else {
      slope = (w2 - w1) / (raw2 - raw1);
      intercept = w1 - slope * raw1;
    }
    final double zeroOffset = slope * raw0 + intercept;

    final double oldSlope = _params.slope;
    final double oldIntercept = _params.intercept;
    final double oldZero = _params.zeroOffset;

    final points = <ScaleCalibrationPoint>[
      _zeroCalibrationPoint!,
      _firstCalibrationPoint!,
      _secondCalibrationPoint!,
    ];

    _params = _params.copyWith(
      slope: slope,
      intercept: intercept,
      zeroOffset: zeroOffset,
      currentTare: 0.0,
      calibrationPoints: points,
      lastCalibrationTime: DateTime.now(),
      calibrationCount: _params.calibrationCount + 1,
      isCalibrated: true,
      deviceAddress: _deviceAddress,
    );
    await _saveParams();
    _addHistoryRecord(
      oldSlope: oldSlope,
      oldIntercept: oldIntercept,
      newSlope: slope,
      newIntercept: intercept,
      oldZero: oldZero,
      newZero: zeroOffset,
      remark: remark ?? '线性校准 (3点)',
    );

    _calibrationStep = CalibrationStep.completed;
    _calibrationStepController.add(_calibrationStep);
    _weightStreamController.add(_params.getNetWeight(_rawWeight));

    _logger.i(
        '校准完成: slope=$slope, intercept=$intercept, zeroOffset=$zeroOffset');
    return _params;
  }

  void cancelCalibration() {
    _calibrationStep = CalibrationStep.idle;
    _zeroCalibrationPoint = null;
    _firstCalibrationPoint = null;
    _secondCalibrationPoint = null;
    _calibrationStepController.add(_calibrationStep);
    _logger.i('校准已取消');
  }

  Future<void> resetCalibration() async {
    final oldSlope = _params.slope;
    final oldIntercept = _params.intercept;
    final oldZero = _params.zeroOffset;

    _params = ScaleCalibrationParams(
      lastCalibrationTime: DateTime.now(),
      deviceAddress: _deviceAddress,
      deviceName: _params.deviceName,
    );
    await _saveParams();
    _addHistoryRecord(
      oldSlope: oldSlope,
      oldIntercept: oldIntercept,
      newSlope: 1.0,
      newIntercept: 0.0,
      oldZero: oldZero,
      newZero: 0.0,
      remark: '重置校准参数',
    );
    _weightStreamController.add(0.0);
    _logger.i('校准参数已重置为默认值');
  }

  void _addHistoryRecord({
    required double oldSlope,
    required double oldIntercept,
    required double newSlope,
    required double newIntercept,
    required double oldZero,
    required double newZero,
    String? remark,
    String? operatorName,
  }) {
    _history.insert(
      0,
      ScaleCalibrationRecord(
        id: 'CAL_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        deviceAddress: _deviceAddress ?? '',
        deviceName: _params.deviceName ?? '',
        oldSlope: oldSlope,
        oldIntercept: oldIntercept,
        newSlope: newSlope,
        newIntercept: newIntercept,
        oldZero: oldZero,
        newZero: newZero,
        operatorName: operatorName,
        remark: remark,
      ),
    );
    _saveHistory();
  }

  void setCalibrationParamsManually({
    double? slope,
    double? intercept,
    double? zeroOffset,
    double? tare,
    String? remark,
  }) {
    final oldSlope = _params.slope;
    final oldIntercept = _params.intercept;
    final double oldZero = _params.zeroOffset;

    _params = _params.copyWith(
      slope: slope,
      intercept: intercept,
      zeroOffset: zeroOffset,
      currentTare: tare,
      lastCalibrationTime: DateTime.now(),
      calibrationCount: _params.calibrationCount + 1,
      isCalibrated: true,
    );
    _saveParams();
    _addHistoryRecord(
      oldSlope: oldSlope,
      oldIntercept: oldIntercept,
      newSlope: _params.slope,
      newIntercept: _params.intercept,
      oldZero: oldZero,
      newZero: _params.zeroOffset,
      remark: remark ?? '手动设置校准参数',
    );
    _weightStreamController.add(_params.getNetWeight(_rawWeight));
  }

  void updateRawWeightFromBluetooth(double rawValue) {
    if (_status != ScaleStatus.connected) return;
    _rawWeight = rawValue;
    final net = _params.getNetWeight(rawValue);
    _weightStreamController.add(net);
  }

  void _updateStatus(ScaleStatus status) {
    _status = status;
    _statusStreamController.add(status);
  }

  String formatWeight(double weight, {String unit = 'kg'}) {
    return '${weight.toStringAsFixed(3)} $unit';
  }

  void dispose() {
    _simulationTimer?.cancel();
    _weightStreamController.close();
    _statusStreamController.close();
    _stableStreamController.close();
    _paramsStreamController.close();
    _calibrationStepController.close();
  }
}

class ScaleTimeoutException implements Exception {
  final String message;
  ScaleTimeoutException(this.message);

  @override
  String toString() => 'ScaleTimeoutException: $message';
}
