import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../config/app_constants.dart';
import '../db/database_helper.dart';
import '../db/database_tables.dart';
import '../services/liquid_level_sensor_service.dart';
import '../utils/logger_util.dart';
import '../utils/sp_util.dart';
import 'api_service.dart';

class LiquidLevelAlertEvent {
  final LiquidLevelState state;
  final double level;
  final double threshold;
  final String? containerCode;
  final Map<String, dynamic>? inventoryData;
  final DateTime triggerTime;
  final String warningId;
  final String? transferOrderNo;

  LiquidLevelAlertEvent({
    required this.state,
    required this.level,
    required this.threshold,
    this.containerCode,
    this.inventoryData,
    required this.triggerTime,
    required this.warningId,
    this.transferOrderNo,
  });
}

class LiquidLevelLinkageService {
  static final LiquidLevelLinkageService _instance =
      LiquidLevelLinkageService._internal();
  factory LiquidLevelLinkageService() => _instance;

  final LiquidLevelSensorService _sensor = LiquidLevelSensorService();
  final DatabaseHelper _db = DatabaseHelper();
  final ApiService _api = ApiService();
  final Uuid _uuid = const Uuid();

  StreamSubscription<LiquidLevelState>? _stateSubscription;
  StreamSubscription<LiquidLevelReading>? _readingSubscription;

  final Set<String> _triggeredWarnings = <String>{};
  final Map<String, DateTime> _warningCooldown = <String, DateTime>{};
  static const Duration _warningCooldownDuration = Duration(minutes: 10);

  final StreamController<LiquidLevelAlertEvent> _alertController =
      StreamController<LiquidLevelAlertEvent>.broadcast();

  Stream<LiquidLevelAlertEvent> get alertStream => _alertController.stream;

  bool _isInitialized = false;

  LiquidLevelLinkageService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _sensor.connectAndAttach();
    } catch (e) {
      LoggerUtil.warning('液位传感器初始连接失败，已降级为模拟模式: $e');
    }

    _stateSubscription = _sensor.stateStream.listen((state) {
      _handleStateChange(state);
    });

    _readingSubscription = _sensor.readingStream.listen((reading) {
      if (reading.state != LiquidLevelState.normal && reading.isStable) {
        _maybeTriggerAlert(reading);
      }
    });

    _isInitialized = true;
    LoggerUtil.info('液位满溢联动服务已初始化');
  }

  void _handleStateChange(LiquidLevelState state) {
    LoggerUtil.info('液位状态变化: $state, 当前液位: ${_sensor.smoothedLevel}%');
    if (state == LiquidLevelState.normal) {
      _clearContainerWarnings();
    }
  }

  Future<void> _maybeTriggerAlert(LiquidLevelReading reading) async {
    final containerCode = await _sensor.getBoundContainerCode();
    final dedupKey = '${reading.state}_${containerCode ?? 'unknown'}';

    if (_triggeredWarnings.contains(dedupKey)) {
      final last = _warningCooldown[dedupKey];
      if (last != null &&
          DateTime.now().difference(last) < _warningCooldownDuration) {
        return;
      }
    }

    _triggeredWarnings.add(dedupKey);
    _warningCooldown[dedupKey] = DateTime.now();

    try {
      final event = await _triggerLinkageFlow(reading, containerCode);
      _alertController.add(event);
    } catch (e) {
      LoggerUtil.error('触发液位联动流程失败: $e');
    }
  }

  Future<LiquidLevelAlertEvent> _triggerLinkageFlow(
    LiquidLevelReading reading,
    String? containerCode,
  ) async {
    final threshold = reading.state == LiquidLevelState.full
        ? _sensor.fullThreshold
        : _sensor.nearFullThreshold;

    final warningType = reading.state == LiquidLevelState.full
        ? BusinessConstants.warningTypeLiquidLevel
        : BusinessConstants.warningTypeLiquidNearFull;

    final warningLevel = reading.state == LiquidLevelState.full
        ? StatusConstants.warningLevelHigh
        : StatusConstants.warningLevelMedium;

    final inventory =
        containerCode != null ? await _findInventory(containerCode) : null;

    final warningId = _uuid.v4();
    final warningTime = DateTime.now().toIso8601String();

    final warningTitle = reading.state == LiquidLevelState.full
        ? '废液桶已满，请立即转运'
        : '废液桶接近满，请准备转运';

    final warningContent = reading.state == LiquidLevelState.full
        ? '容器 ${containerCode ?? '未知'} 液位已达 ${reading.smoothedLevel.toStringAsFixed(1)}%，超过满溢阈值 ${threshold.toStringAsFixed(1)}%，存在溢流风险！'
        : '容器 ${containerCode ?? '未知'} 液位已达 ${reading.smoothedLevel.toStringAsFixed(1)}%，已接近满溢阈值 ${threshold.toStringAsFixed(1)}%，请及时安排转运。';

    final warningRecord = {
      'warning_id': warningId,
      'warning_type': warningType,
      'warning_level': warningLevel,
      'warning_title': warningTitle,
      'warning_content': warningContent,
      'waste_code': inventory?['waste_code'] as String?,
      'waste_name': inventory?['waste_name'] as String?,
      'container_code': containerCode,
      'threshold': threshold,
      'current_value': reading.smoothedLevel,
      'unit': '%',
      'status': StatusConstants.handleStatusUnhandled,
      'warning_time': warningTime,
      'create_time': warningTime,
      'update_time': warningTime,
      'is_deleted': 0,
    };

    await _insertWarning(warningRecord);
    LoggerUtil.info(
        '写入液位预警: $warningId, type=$warningType, level=$warningLevel');

    String? transferOrderNo;
    try {
      transferOrderNo = await _autoCreateTransferOrder(
        containerCode: containerCode,
        inventory: inventory,
        warningId: warningId,
        isNearFull: reading.state == LiquidLevelState.nearFull,
      );
    } catch (e) {
      LoggerUtil.error('自动生成转运联单失败: $e');
    }

    return LiquidLevelAlertEvent(
      state: reading.state,
      level: reading.smoothedLevel,
      threshold: threshold,
      containerCode: containerCode,
      inventoryData: inventory,
      triggerTime: reading.timestamp,
      warningId: warningId,
      transferOrderNo: transferOrderNo,
    );
  }

  Future<Map<String, dynamic>?> _findInventory(String containerCode) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        DatabaseTables.tableWasteInventory,
        where: 'container_code = ? AND is_deleted = 0',
        whereArgs: [containerCode],
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first;
      }
    } catch (e) {
      LoggerUtil.warning('查询库存信息失败: $e');
    }
    return null;
  }

  Future<int> _insertWarning(Map<String, dynamic> record) async {
    try {
      final db = await _db.database;
      return await db.insert(DatabaseTables.tableWarningRecord, record);
    } catch (e) {
      LoggerUtil.error('插入预警记录失败: $e');
      rethrow;
    }
  }

  Future<String> _autoCreateTransferOrder({
    String? containerCode,
    Map<String, dynamic>? inventory,
    required String warningId,
    bool isNearFull = false,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final offlineId = _uuid.v4();
    final orderNo = _generateOrderNo();

    final enterpriseInfo = SpUtil.getString(StorageConstants.enterpriseInfo);
    String? enterpriseName;
    String? enterpriseId;
    if (enterpriseInfo != null) {
      try {
        final enterprise = _tryJsonDecode(enterpriseInfo);
        if (enterprise is Map<String, dynamic>) {
          enterpriseName = enterprise['name'] as String? ??
              enterprise['enterpriseName'] as String?;
          enterpriseId = enterprise['id']?.toString() ??
              enterprise['enterpriseId']?.toString();
        }
      } catch (_) {}
    }

    final userInfo = SpUtil.getString(StorageConstants.userInfo);
    String? operatorName;
    String? operatorId;
    if (userInfo != null) {
      try {
        final user = _tryJsonDecode(userInfo);
        if (user is Map<String, dynamic>) {
          operatorName = user['realName'] as String? ??
              user['name'] as String? ??
              user['username'] as String?;
          operatorId = user['id']?.toString() ?? user['userId']?.toString();
        }
      } catch (_) {}
    }

    final weight = (inventory?['weight'] as num?)?.toDouble() ?? 0.0;
    final orderStatus = isNearFull
        ? StatusConstants.orderStatusDraft
        : StatusConstants.orderStatusPending;
    final triggerDesc = isNearFull ? '接近满' : '满溢';
    final order = {
      'offline_id': offlineId,
      'order_id': offlineId,
      'order_no': orderNo,
      'waste_code': inventory?['waste_code'] as String? ?? '',
      'waste_name': inventory?['waste_name'] as String? ?? '未知危废',
      'waste_category': inventory?['waste_category'] as String? ?? '',
      'quantity': 1.0,
      'unit': '桶',
      'weight': weight,
      'weight_unit': 'kg',
      'transferor': enterpriseName ?? '',
      'transferor_id': enterpriseId ?? '',
      'transferee': '',
      'transferee_id': '',
      'carrier': '',
      'carrier_id': '',
      'driver': '',
      'vehicle_no': '',
      'start_time': now.toIso8601String(),
      'end_time': null,
      'status': orderStatus,
      'remark': '液位${triggerDesc}自动生成，关联预警: $warningId，容器: ${containerCode ?? '未知'}',
      'sync_status': StatusConstants.syncStatusNotSynced,
      'sync_time': null,
      'create_time': now.toIso8601String(),
      'update_time': now.toIso8601String(),
      'is_deleted': 0,
    };

    await db.insert(DatabaseTables.tableTransferOrder, order);
    LoggerUtil.info('自动生成转运联单($triggerDesc): $orderNo, 容器: $containerCode');

    try {
      final hasNetwork = await _api.isNetworkAvailable();
      if (hasNetwork) {
        try {
          await _api.post('/transfer-order/create', data: order);
          order['sync_status'] = StatusConstants.syncStatusSuccess;
          order['sync_time'] = DateTime.now().toIso8601String();
          await db.update(
            DatabaseTables.tableTransferOrder,
            order,
            where: 'offline_id = ?',
            whereArgs: [offlineId],
          );
          LoggerUtil.info('转运联单已同步: $orderNo');
        } catch (e) {
          LoggerUtil.warning('转运联单同步失败，将在下次同步时重试: $e');
        }
      }
    } catch (_) {}

    return orderNo;
  }

  String _generateOrderNo() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart =
        (DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'ZZ$datePart$randomPart';
  }

  void _clearContainerWarnings() {
    _triggeredWarnings.clear();
    _warningCooldown.clear();
    LoggerUtil.debug('液位预警触发缓存已清除');
  }

  Future<void> dismissWarning(String key) async {
    _triggeredWarnings.remove(key);
    _warningCooldown.remove(key);
  }

  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _readingSubscription?.cancel();
    _readingSubscription = null;
    _sensor.dispose();
    _alertController.close();
    _isInitialized = false;
  }
}

dynamic _tryJsonDecode(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}
