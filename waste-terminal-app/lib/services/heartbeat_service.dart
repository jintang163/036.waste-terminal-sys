import 'dart:async';

import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';
import '../services/device_self_check_service.dart';
import '../utils/logger_util.dart';
import '../utils/sp_util.dart';
import '../providers/app_provider.dart';

class HeartbeatService {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;

  final ApiService _apiService = ApiService();
  final BluetoothService _bluetoothService = BluetoothService();
  final DeviceSelfCheckService _selfCheckService = DeviceSelfCheckService();

  Timer? _heartbeatTimer;
  bool _isRunning = false;
  DateTime? _lastHeartbeatTime;
  int _consecutiveFailures = 0;

  bool get isRunning => _isRunning;
  DateTime? get lastHeartbeatTime => _lastHeartbeatTime;
  int get consecutiveFailures => _consecutiveFailures;

  HeartbeatService._internal();

  Future<void> start() async {
    if (_isRunning) {
      LoggerUtil.info('心跳服务已在运行中');
      return;
    }

    _isRunning = true;
    LoggerUtil.info('启动心跳服务，间隔: ${AppConfig.heartbeatIntervalMinutes}分钟');

    unawaited(sendHeartbeat());

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(minutes: AppConfig.heartbeatIntervalMinutes),
      (_) => sendHeartbeat(),
    );
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
    LoggerUtil.info('心跳服务已停止');
  }

  Future<void> sendHeartbeat() async {
    try {
      final isOnline = await _apiService.isNetworkAvailable();
      if (!isOnline) {
        LoggerUtil.info('网络不可用，跳过心跳上报');
        _saveLocalHeartbeat(isOnline: false);
        return;
      }

      final heartbeatData = await _buildHeartbeatData();

      final response = await _apiService.post(
        ApiConstants.deviceHeartbeat,
        data: heartbeatData,
        checkNetwork: false,
      );

      _lastHeartbeatTime = DateTime.now();
      _consecutiveFailures = 0;

      await SpUtil.putInt(
        StorageConstants.lastHeartbeatTime,
        _lastHeartbeatTime!.millisecondsSinceEpoch,
      );

      _saveLocalHeartbeat(isOnline: true);

      LoggerUtil.info('心跳上报成功: $heartbeatData');
    } catch (e) {
      _consecutiveFailures++;
      LoggerUtil.warning(
        '心跳上报失败(连续$_consecutiveFailures次): $e',
      );
      _saveLocalHeartbeat(
        isOnline: false,
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _buildHeartbeatData() async {
    final deviceId = SpUtil.getDeviceId() ?? '';
    final userId = SpUtil.getUserId();
    final username = SpUtil.getString(StorageConstants.loginUsername);
    final enterpriseId = SpUtil.getEnterpriseId();

    String networkType = BusinessConstants.networkTypeNone;
    try {
      networkType = await _apiService.getNetworkType();
    } catch (_) {}

    final deviceInfo = await _selfCheckService.getDeviceDetailInfo();
    final storageInfo = deviceInfo.freeStorage != null && deviceInfo.totalStorage != null
        ? {
            'total': deviceInfo.totalStorage,
            'free': deviceInfo.freeStorage,
            'usagePercent': deviceInfo.storageUsagePercent.toStringAsFixed(1),
          }
        : null;

    return {
      'deviceId': deviceId,
      'deviceName': deviceInfo.deviceName,
      'deviceModel': deviceInfo.deviceModel,
      'platform': deviceInfo.platform,
      'osVersion': deviceInfo.osVersion,
      'userId': userId,
      'username': username,
      'enterpriseId': enterpriseId,
      'networkType': networkType,
      'batteryLevel': await _getBatteryLevel(),
      'storage': storageInfo,
      'bluetooth': {
        'available': await _bluetoothService.isBluetoothAvailable(),
        'enabled': await _bluetoothService.isBluetoothOn(),
        'connected': _bluetoothService.isConnected,
        'connectedDeviceName': _bluetoothService.connectedDeviceName,
        'connectedDeviceType': _bluetoothService.connectedDeviceType?.name,
      },
      'appVersion': AppConfig.appVersion,
      'buildNumber': AppConfig.buildNumber.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<int?> _getBatteryLevel() async {
    try {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalHeartbeat({
    required bool isOnline,
    String? error,
  }) async {
    try {
      final logService = OperationLogService();
      final extra = <String, dynamic>{
        'isOnline': isOnline,
        'consecutiveFailures': _consecutiveFailures,
      };
      if (error != null) extra['error'] = error;

      await logService.logInfo(
        isOnline ? '设备心跳上报成功' : '设备心跳上报跳过（离线）',
        category: BusinessConstants.logCategoryDevice,
        extra: extra,
        forceOffline: !isOnline,
      );
    } catch (_) {}
  }

  DateTime? getLastHeartbeatTime() {
    final timestamp = SpUtil.getInt(StorageConstants.lastHeartbeatTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  bool isDeviceAbnormal() {
    final lastTime = getLastHeartbeatTime();
    if (lastTime == null) return true;

    final diff = DateTime.now().difference(lastTime);
    return diff.inHours >= AppConfig.deviceAbnormalThresholdHours;
  }

  String getHeartbeatStatusText() {
    if (_isRunning && _consecutiveFailures == 0) {
      return '正常';
    }
    if (_consecutiveFailures > 0 && _consecutiveFailures < 3) {
      return '不稳定';
    }
    if (isDeviceAbnormal()) {
      return '异常';
    }
    return '未启动';
  }
}
