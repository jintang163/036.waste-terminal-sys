import 'dart:async';
import 'package:logger/logger.dart';

enum ScaleStatus { disconnected, connecting, connected, error }

class ScaleService {
  static final ScaleService _instance = ScaleService._internal();
  factory ScaleService() => _instance;

  final Logger _logger = Logger();

  ScaleStatus _status = ScaleStatus.disconnected;
  double _currentWeight = 0.0;
  String? _currentUnit = 'kg';
  bool _isStable = false;

  String? _deviceAddress;
  int? _baudRate = 9600;

  final StreamController<double> _weightStreamController =
      StreamController<double>.broadcast();
  final StreamController<ScaleStatus> _statusStreamController =
      StreamController<ScaleStatus>.broadcast();
  final StreamController<bool> _stableStreamController =
      StreamController<bool>.broadcast();

  Timer? _simulationTimer;

  ScaleService._internal();

  ScaleStatus get status => _status;
  double get currentWeight => _currentWeight;
  String? get currentUnit => _currentUnit;
  bool get isStable => _isStable;
  bool get isConnected => _status == ScaleStatus.connected;

  Stream<double> get weightStream => _weightStreamController.stream;
  Stream<ScaleStatus> get statusStream => _statusStreamController.stream;
  Stream<bool> get stableStream => _stableStreamController.stream;

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

      _updateStatus(ScaleStatus.connected);
      _startWeightSimulation();

      _logger.i('地磅连接成功: $_deviceAddress');
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

      _currentWeight = 0.0;
      _isStable = false;
      _weightStreamController.add(0.0);
      _stableStreamController.add(false);

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

      double randomVariation = (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
      randomVariation = (randomVariation - 0.5) * 2 * variation;
      double newWeight = targetWeight + randomVariation;

      if ((newWeight - _currentWeight).abs() < 0.02) {
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

      _currentWeight = double.parse(newWeight.toStringAsFixed(3));
      _weightStreamController.add(_currentWeight);
    });
  }

  Future<double> readWeight() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }

      return _currentWeight;
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
        return _currentWeight;
      }

      Completer<double> completer = Completer<double>();
      Timer? timeoutTimer;
      int currentStableCount = 0;
      double lastWeight = 0;

      StreamSubscription<double>? subscription;

      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('等待重量稳定超时'));
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

  Future<void> tare() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }

      _logger.d('执行去皮操作');

      await Future.delayed(const Duration(milliseconds: 500));

      _logger.i('去皮完成');
    } catch (e) {
      _logger.e('去皮失败: $e');
      rethrow;
    }
  }

  Future<void> zero() async {
    try {
      if (_status != ScaleStatus.connected) {
        throw Exception('地磅未连接');
      }

      _logger.d('执行归零操作');

      await Future.delayed(const Duration(milliseconds: 500));

      _currentWeight = 0.0;
      _weightStreamController.add(0.0);

      _logger.i('归零完成');
    } catch (e) {
      _logger.e('归零失败: $e');
      rethrow;
    }
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
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
