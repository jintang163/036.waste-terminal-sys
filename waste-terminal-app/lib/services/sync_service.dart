import 'dart:async';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../config/app_constants.dart';
import '../models/waste_in_record.dart';
import '../models/waste_out_record.dart';
import '../models/face_auth_record_model.dart';
import '../models/transport_track.dart';
import '../models/carbon_footprint_record.dart';
import '../db/sync_log_db.dart';
import '../db/waste_catalog_db.dart';
import '../db/waste_container_db.dart';
import '../db/waste_in_record_db.dart';
import '../db/waste_inventory_db.dart';
import '../db/waste_out_record_db.dart';
import '../db/transfer_order_db.dart';
import '../db/inventory_check_db.dart';
import '../db/warning_record_db.dart';
import '../db/user_face_db.dart';
import '../db/face_auth_record_db.dart';
import '../db/transport_vehicle_db.dart';
import '../db/transport_driver_db.dart';
import '../db/transport_track_db.dart';
import '../db/carbon_footprint_db.dart';

import 'api_service.dart';
import 'operation_log_service.dart';

enum SyncStatus { idle, syncing, success, failed }
enum SyncType { full, incremental }
enum SyncModule {
  wasteCatalog,
  wasteContainer,
  wasteInRecord,
  wasteOutRecord,
  transferOrder,
  inventory,
  inventoryCheck,
  warning,
  transportVehicle,
  transportDriver,
  transportTrack,
  carbonFootprint,
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  final WasteCatalogDb _wasteCatalogDb = WasteCatalogDb();
  final WasteContainerDb _wasteContainerDb = WasteContainerDb();
  final WasteInRecordDb _wasteInRecordDb = WasteInRecordDb();
  final WasteInventoryDb _wasteInventoryDb = WasteInventoryDb();
  final WasteOutRecordDb _wasteOutRecordDb = WasteOutRecordDb();
  final TransferOrderDb _transferOrderDb = TransferOrderDb();
  final InventoryCheckDb _inventoryCheckDb = InventoryCheckDb();
  final WarningRecordDb _warningRecordDb = WarningRecordDb();
  final CameraDb _cameraDb = CameraDb();
  final AiCaptureEventDb _aiCaptureEventDb = AiCaptureEventDb();
  final LocalRecordTaskDb _localRecordTaskDb = LocalRecordTaskDb();
  final UserFaceDb _userFaceDb = UserFaceDb();
  final FaceAuthRecordDb _faceAuthRecordDb = FaceAuthRecordDb();
  final TransportVehicleDb _transportVehicleDb = TransportVehicleDb();
  final TransportDriverDb _transportDriverDb = TransportDriverDb();
  final TransportTrackDb _transportTrackDb = TransportTrackDb();
  final CarbonFootprintDb _carbonFootprintDb = CarbonFootprintDb();
  final SyncLogDb _syncLogDb = SyncLogDb();

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncType? _currentSyncType;
  double _progress = 0.0;
  String? _currentModule;
  int _totalCount = 0;
  int _completedCount = 0;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _autoSyncEnabled = true;

  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  final StreamController<double> _progressController = StreamController<double>.broadcast();
  final StreamController<String> _moduleController = StreamController<String>.broadcast();

  SyncService._internal();

  SyncStatus get syncStatus => _syncStatus;
  double get progress => _progress;
  String? get currentModule => _currentModule;
  bool get isSyncing => _syncStatus == SyncStatus.syncing;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<String> get moduleStream => _moduleController.stream;

  void init() {
    _initConnectivityListener();
    _logger.i('同步服务初始化完成');
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.isNotEmpty) {
          final result = results.first;
          if (result != ConnectivityResult.none && _autoSyncEnabled && !isSyncing) {
            _logger.d('网络已连接，触发自动同步');
            incrementalSync();
          }
        }
      },
    );
  }

  void setAutoSyncEnabled(bool enabled) {
    _autoSyncEnabled = enabled;
    _logger.d('自动同步${enabled ? "已开启" : "已关闭"}');
  }

  Future<void> fullSync() async {
    if (isSyncing) {
      _logger.w('同步进行中，忽略重复请求');
      return;
    }

    _logger.i('开始全量同步');
    String logId = _uuid.v4();
    DateTime startTime = DateTime.now();

    try {
      await OperationLogService().logInfo(
        '开始全量同步',
        category: BusinessConstants.logCategorySync,
        module: 'sync',
        action: 'full_sync_start',
        extra: {
          'syncId': logId,
        },
      );
    } catch (_) {}

    try {
      _updateStatus(SyncStatus.syncing);
      _currentSyncType = SyncType.full;
      _progress = 0.0;
      _totalCount = 17;
      _completedCount = 0;

      await _syncCamera();
      _updateProgress(1);

      await _syncWasteCatalog();
      _updateProgress(2);

      await _syncWasteContainer();
      _updateProgress(3);

      await _syncInventory();
      _updateProgress(4);

      await _syncWarning();
      _updateProgress(5);

      await _syncAiCaptureEvent();
      _updateProgress(6);

      await _syncUserFace();
      _updateProgress(7);

      await _syncTransportVehicle();
      _updateProgress(8);

      await _syncTransportDriver();
      _updateProgress(9);

      await _uploadWasteInRecords();
      _updateProgress(10);

      await _uploadWasteOutRecords();
      _updateProgress(11);

      await _uploadTransferOrders();
      _updateProgress(12);

      await _uploadInventoryChecks();
      _updateProgress(13);

      await _uploadLocalRecords();
      _updateProgress(14);

      await _uploadFaceAuthRecords();
      _updateProgress(15);

      await _uploadTransportTracks();
      _updateProgress(16);

      await _uploadCarbonFootprintRecords();
      _updateProgress(17);

      _updateStatus(SyncStatus.success);

      await _syncLogDb.insert({
        'log_id': logId,
        'sync_type': 'full',
        'sync_module': 'all',
        'sync_status': 1,
        'sync_start_time': startTime.toIso8601String(),
        'sync_end_time': DateTime.now().toIso8601String(),
        'total_count': _totalCount,
        'success_count': _completedCount,
        'fail_count': 0,
        'create_time': DateTime.now().toIso8601String(),
      });

      try {
        await OperationLogService().logInfo(
          '全量同步完成',
          category: BusinessConstants.logCategorySync,
          module: 'sync',
          action: 'full_sync_success',
          extra: {
            'syncId': logId,
            'durationSeconds': DateTime.now().difference(startTime).inSeconds,
            'totalCount': _totalCount,
            'successCount': _completedCount,
          },
        );
      } catch (_) {}

      _logger.i('全量同步完成');
    } catch (e) {
      _logger.e('全量同步失败: $e');
      _updateStatus(SyncStatus.failed);

      await _syncLogDb.insert({
        'log_id': logId,
        'sync_type': 'full',
        'sync_module': 'all',
        'sync_status': 0,
        'sync_start_time': startTime.toIso8601String(),
        'sync_end_time': DateTime.now().toIso8601String(),
        'total_count': _totalCount,
        'success_count': _completedCount,
        'fail_count': _totalCount - _completedCount,
        'error_msg': e.toString(),
        'create_time': DateTime.now().toIso8601String(),
      });

      try {
        await OperationLogService().logError(
          '全量同步失败: $e',
          category: BusinessConstants.logCategorySync,
          module: 'sync',
          action: 'full_sync_failed',
          extra: {
            'syncId': logId,
            'error': e.toString(),
            'durationSeconds': DateTime.now().difference(startTime).inSeconds,
          },
        );
      } catch (_) {}

      rethrow;
    }
  }

  Future<void> incrementalSync() async {
    if (isSyncing) {
      _logger.w('同步进行中，忽略重复请求');
      return;
    }

    _logger.i('开始增量同步');
    String logId = _uuid.v4();
    DateTime startTime = DateTime.now();

    try {
      await OperationLogService().logInfo(
        '开始增量同步',
        category: BusinessConstants.logCategorySync,
        module: 'sync',
        action: 'incremental_sync_start',
        extra: {
          'syncId': logId,
        },
      );
    } catch (_) {}

    try {
      _updateStatus(SyncStatus.syncing);
      _currentSyncType = SyncType.incremental;
      _progress = 0.0;
      _totalCount = 17;
      _completedCount = 0;

      await _syncCamera();
      _updateProgress(1);

      await _syncWasteCatalog();
      _updateProgress(2);

      await _syncWasteContainer();
      _updateProgress(3);

      await _syncInventory();
      _updateProgress(4);

      await _syncWarning();
      _updateProgress(5);

      await _syncAiCaptureEvent();
      _updateProgress(6);

      await _syncUserFace();
      _updateProgress(7);

      await _syncTransportVehicle();
      _updateProgress(8);

      await _syncTransportDriver();
      _updateProgress(9);

      await _uploadWasteInRecords();
      _updateProgress(10);

      await _uploadWasteOutRecords();
      _updateProgress(11);

      await _uploadTransferOrders();
      _updateProgress(12);

      await _uploadInventoryChecks();
      _updateProgress(13);

      await _uploadLocalRecords();
      _updateProgress(14);

      await _uploadFaceAuthRecords();
      _updateProgress(15);

      await _uploadTransportTracks();
      _updateProgress(16);

      await _uploadCarbonFootprintRecords();
      _updateProgress(17);

      _updateStatus(SyncStatus.success);

      await _syncLogDb.insert({
        'log_id': logId,
        'sync_type': 'incremental',
        'sync_module': 'all',
        'sync_status': 1,
        'sync_start_time': startTime.toIso8601String(),
        'sync_end_time': DateTime.now().toIso8601String(),
        'total_count': _totalCount,
        'success_count': _completedCount,
        'fail_count': 0,
        'create_time': DateTime.now().toIso8601String(),
      });

      try {
        await OperationLogService().logInfo(
          '增量同步完成',
          category: BusinessConstants.logCategorySync,
          module: 'sync',
          action: 'incremental_sync_success',
          extra: {
            'syncId': logId,
            'durationSeconds': DateTime.now().difference(startTime).inSeconds,
            'totalCount': _totalCount,
            'successCount': _completedCount,
          },
        );
      } catch (_) {}

      _logger.i('增量同步完成');
    } catch (e) {
      _logger.e('增量同步失败: $e');
      _updateStatus(SyncStatus.failed);

      await _syncLogDb.insert({
        'log_id': logId,
        'sync_type': 'incremental',
        'sync_module': 'all',
        'sync_status': 0,
        'sync_start_time': startTime.toIso8601String(),
        'sync_end_time': DateTime.now().toIso8601String(),
        'total_count': _totalCount,
        'success_count': _completedCount,
        'fail_count': _totalCount - _completedCount,
        'error_msg': e.toString(),
        'create_time': DateTime.now().toIso8601String(),
      });

      try {
        await OperationLogService().logError(
          '增量同步失败: $e',
          category: BusinessConstants.logCategorySync,
          module: 'sync',
          action: 'incremental_sync_failed',
          extra: {
            'syncId': logId,
            'error': e.toString(),
            'durationSeconds': DateTime.now().difference(startTime).inSeconds,
          },
        );
      } catch (_) {}
    }
  }

  Future<void> _syncWasteCatalog() async {
    _currentModule = '危废名录';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过危废名录同步');
        return;
      }

      final response = await _apiService.get('/waste-catalog/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> catalogList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _wasteCatalogDb.replaceAll(catalogList);
      _logger.d('危废名录同步完成，数量: ${catalogList.length}');
    } catch (e) {
      _logger.w('危废名录同步失败: $e');
    }
  }

  Future<void> _syncWasteContainer() async {
    _currentModule = '容器信息';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过容器同步');
        return;
      }

      final response = await _apiService.get('/waste-container/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> containerList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _wasteContainerDb.replaceAll(containerList);
      _logger.d('容器信息同步完成，数量: ${containerList.length}');
    } catch (e) {
      _logger.w('容器信息同步失败: $e');
    }
  }

  Future<void> _syncInventory() async {
    _currentModule = '库存数据';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过库存同步');
        return;
      }

      final response = await _apiService.get('/inventory/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> inventoryList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _wasteInventoryDb.replaceAll(inventoryList);
      _logger.d('库存数据同步完成，数量: ${inventoryList.length}');
    } catch (e) {
      _logger.w('库存数据同步失败: $e');
    }
  }

  Future<void> _syncWarning() async {
    _currentModule = '预警信息';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过预警同步');
        return;
      }

      final response = await _apiService.get('/warning/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> warningList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _warningRecordDb.replaceAll(warningList);
      _logger.d('预警信息同步完成，数量: ${warningList.length}');
    } catch (e) {
      _logger.w('预警信息同步失败: $e');
    }
  }

  Future<void> _uploadWasteInRecords() async {
    _currentModule = '入库记录';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过入库记录上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _wasteInRecordDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步入库记录');
        return;
      }

      _logger.d('待同步入库记录数量: ${unsynced.length}');

      for (var record in unsynced) {
        try {
          final wasteInRecord = WasteInRecord.fromDbMap(record);
          final response = await _apiService.post(
            '/waste-in/add',
            data: wasteInRecord.toJson(),
          );

          String? recordId = response.data['data']?['recordId'];
          await _wasteInRecordDb.updateSyncStatus(
            record['offline_id'],
            1,
            syncTime: DateTime.now().toIso8601String(),
            recordId: recordId,
          );
        } catch (e) {
          _logger.w('上传入库记录失败: ${record['offline_id']}, $e');
        }
      }

      _logger.d('入库记录上传完成');
    } catch (e) {
      _logger.w('入库记录上传失败: $e');
    }
  }

  Future<void> _uploadWasteOutRecords() async {
    _currentModule = '出库记录';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过出库记录上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _wasteOutRecordDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步出库记录');
        return;
      }

      _logger.d('待同步出库记录数量: ${unsynced.length}');

      for (var record in unsynced) {
        try {
          final wasteOutRecord = WasteOutRecord.fromDbMap(record);
          final response = await _apiService.post(
            '/waste-out/add',
            data: wasteOutRecord.toJson(),
          );

          String? recordId = response.data['data']?['recordId'];
          await _wasteOutRecordDb.updateSyncStatus(
            record['offline_id'],
            1,
            syncTime: DateTime.now().toIso8601String(),
            recordId: recordId,
          );
        } catch (e) {
          _logger.w('上传出库记录失败: ${record['offline_id']}, $e');
        }
      }

      _logger.d('出库记录上传完成');
    } catch (e) {
      _logger.w('出库记录上传失败: $e');
    }
  }

  Future<void> _uploadTransferOrders() async {
    _currentModule = '转移联单';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过转移联单上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _transferOrderDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步转移联单');
        return;
      }

      _logger.d('待同步转移联单数量: ${unsynced.length}');

      for (var order in unsynced) {
        try {
          final response = await _apiService.post(
            '/transfer-order/add',
            data: order,
          );

          String? orderId = response.data['data']?['orderId'];
          await _transferOrderDb.updateSyncStatus(
            order['offline_id'],
            1,
            syncTime: DateTime.now().toIso8601String(),
            orderId: orderId,
          );
        } catch (e) {
          _logger.w('上传转移联单失败: ${order['offline_id']}, $e');
        }
      }

      _logger.d('转移联单上传完成');
    } catch (e) {
      _logger.w('转移联单上传失败: $e');
    }
  }

  Future<void> _uploadInventoryChecks() async {
    _currentModule = '盘点记录';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过盘点记录上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _inventoryCheckDb.queryUnsyncedChecks();
      if (unsynced.isEmpty) {
        _logger.d('无待同步盘点记录');
        return;
      }

      _logger.d('待同步盘点记录数量: ${unsynced.length}');

      for (var check in unsynced) {
        try {
          String checkOfflineId = check['offline_id'];
          List<Map<String, dynamic>> details =
              await _inventoryCheckDb.queryDetailsByCheckOfflineId(checkOfflineId);

          final response = await _apiService.post(
            '/inventory-check/add',
            data: {
              ...check,
              'details': details,
            },
          );

          String? checkId = response.data['data']?['checkId'];
          await _inventoryCheckDb.updateCheckSyncStatus(
            checkOfflineId,
            1,
            syncTime: DateTime.now().toIso8601String(),
            checkId: checkId,
          );
        } catch (e) {
          _logger.w('上传盘点记录失败: ${check['offline_id']}, $e');
        }
      }

      _logger.d('盘点记录上传完成');
    } catch (e) {
      _logger.w('盘点记录上传失败: $e');
    }
  }

  Future<int> getUnsyncedTotalCount() async {
    int count = 0;
    count += await _wasteInRecordDb.queryUnsyncedCount();
    count += await _wasteOutRecordDb.queryUnsyncedCount();
    count += await _transferOrderDb.queryUnsyncedCount();
    count += await _inventoryCheckDb.queryUnsyncedChecksCount();
    count += await _localRecordTaskDb.queryUnsyncedCount();
    final authRecords = await _faceAuthRecordDb.queryUnsynced();
    count += authRecords.length;
    final trackPoints = await _transportTrackDb.queryUnsyncedPoints();
    count += trackPoints.length;
    final carbonRecords = await _carbonFootprintDb.queryUnsynced();
    count += carbonRecords.length;
    return count;
  }

  Future<Map<String, int>> getUnsyncedCountByModule() async {
    final authRecords = await _faceAuthRecordDb.queryUnsynced();
    final trackPoints = await _transportTrackDb.queryUnsyncedPoints();
    final carbonRecords = await _carbonFootprintDb.queryUnsynced();
    return {
      'wasteIn': await _wasteInRecordDb.queryUnsyncedCount(),
      'wasteOut': await _wasteOutRecordDb.queryUnsyncedCount(),
      'transferOrder': await _transferOrderDb.queryUnsyncedCount(),
      'inventoryCheck': await _inventoryCheckDb.queryUnsyncedChecksCount(),
      'localRecord': await _localRecordTaskDb.queryUnsyncedCount(),
      'faceAuthRecord': authRecords.length,
      'transportTrack': trackPoints.length,
      'carbonFootprint': carbonRecords.length,
    };
  }

  Future<void> _syncCamera() async {
    _currentModule = '摄像头';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过摄像头同步');
        return;
      }

      final response = await _apiService.get('/camera/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> cameraList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _cameraDb.replaceAll(cameraList);
      _logger.d('摄像头同步完成，数量: ${cameraList.length}');
    } catch (e) {
      _logger.w('摄像头同步失败: $e');
    }
  }

  Future<void> _syncAiCaptureEvent() async {
    _currentModule = 'AI抓拍事件';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过AI抓拍事件同步');
        return;
      }

      final response = await _apiService.get('/ai-capture/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> eventList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _aiCaptureEventDb.replaceAll(eventList);
      _logger.d('AI抓拍事件同步完成，数量: ${eventList.length}');
    } catch (e) {
      _logger.w('AI抓拍事件同步失败: $e');
    }
  }

  Future<void> _syncUserFace() async {
    _currentModule = '人脸信息';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过人脸信息同步');
        return;
      }

      final response = await _apiService.get('/user-face/list');
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> faceList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _userFaceDb.replaceAll(faceList);
      _logger.d('人脸信息同步完成，数量: ${faceList.length}');
    } catch (e) {
      _logger.w('人脸信息同步失败: $e');
    }
  }

  Future<void> _syncTransportVehicle() async {
    _currentModule = '运输车辆';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过运输车辆同步');
        return;
      }

      final response = await _apiService.getTransportVehicles();
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> vehicleList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _transportVehicleDb.replaceAll(vehicleList);
      _logger.d('运输车辆同步完成，数量: ${vehicleList.length}');
    } catch (e) {
      _logger.w('运输车辆同步失败: $e');
    }
  }

  Future<void> _syncTransportDriver() async {
    _currentModule = '驾驶员';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过驾驶员同步');
        return;
      }

      final response = await _apiService.getTransportDrivers();
      List<dynamic> data = response.data['data'] ?? [];

      List<Map<String, dynamic>> driverList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _transportDriverDb.replaceAll(driverList);
      _logger.d('驾驶员同步完成，数量: ${driverList.length}');
    } catch (e) {
      _logger.w('驾驶员同步失败: $e');
    }
  }

  Future<void> _uploadTransportTracks() async {
    _currentModule = '运输轨迹';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过运输轨迹上传');
        return;
      }

      List<Map<String, dynamic>> unsyncedPoints = await _transportTrackDb.queryUnsyncedPoints();
      if (unsyncedPoints.isEmpty) {
        _logger.d('无待同步轨迹点');
        return;
      }

      _logger.d('待同步轨迹点数量: ${unsyncedPoints.length}');

      final batchSize = 50;
      for (var i = 0; i < unsyncedPoints.length; i += batchSize) {
        final end = (i + batchSize < unsyncedPoints.length) ? i + batchSize : unsyncedPoints.length;
        final batch = unsyncedPoints.sublist(i, end);

        try {
          final pointList = batch.map((e) => TrackPoint.fromDbMap(e).toJson()).toList();
          final response = await _apiService.uploadTrackPoints(pointList);

          if (response.data['code'] == 200) {
            final pointIds = batch
                .map((e) => e['point_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();

            for (var pointId in pointIds) {
              await _transportTrackDb.updatePointSyncStatus(
                pointId,
                1,
                syncTime: DateTime.now().toIso8601String(),
              );
            }

            _logger.d('批量上传轨迹点成功，数量: ${pointIds.length}');
          } else {
            _logger.w('批量上传轨迹点失败: ${response.data['msg']}');
          }
        } catch (e) {
          _logger.w('批量上传轨迹点异常: $e');
        }
      }

      _logger.d('运输轨迹上传完成');
    } catch (e) {
      _logger.w('运输轨迹上传失败: $e');
    }
  }

  Future<void> _uploadFaceAuthRecords() async {
    _currentModule = '人脸认证记录';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过人脸认证记录上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _faceAuthRecordDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步人脸认证记录');
        return;
      }

      _logger.d('待同步人脸认证记录数量: ${unsynced.length}');

      final List<Map<String, dynamic>> uploadData = unsynced
          .map((map) => FaceAuthRecordModel.fromDbMap(map).toJson())
          .toList();

      final response = await _apiService.post(
        '/face-auth/batch',
        data: uploadData,
      );

      if (response.data['code'] == 200) {
        final authIds = unsynced
            .map((e) => e['auth_id']?.toString() ?? e['authId']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (authIds.isNotEmpty) {
          await _faceAuthRecordDb.batchUpdateSyncStatus(authIds, 1);
        }
        _logger.d('人脸认证记录上传成功，数量: ${unsynced.length}');
      } else {
        _logger.w('人脸认证记录上传失败: ${response.data['msg']}');
      }
    } catch (e) {
      _logger.w('人脸认证记录上传失败: $e');
    }
  }

  Future<void> _uploadLocalRecords() async {
    _currentModule = '本地录像';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过本地录像上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _localRecordTaskDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步本地录像');
        return;
      }

      _logger.d('待同步本地录像数量: ${unsynced.length}');

      for (var record in unsynced) {
        try {
          String? filePath = record['file_path'];
          if (filePath == null || filePath.isEmpty) {
            _logger.w('录像文件路径为空，跳过: ${record['task_id']}');
            continue;
          }

          final file = File(filePath);
          if (!await file.exists()) {
            _logger.w('录像文件不存在，跳过: $filePath');
            continue;
          }

          _logger.d('上传录像文件: ${record['task_id']}');

          final uploadResponse = await _apiService.uploadFile(
            filePath,
            bizType: 'local_record',
            bizId: record['task_id'],
          );

          if (uploadResponse == null || uploadResponse.data == null) {
            _logger.w('录像上传返回空结果，跳过: ${record['task_id']}');
            continue;
          }

          String? serverFilePath = uploadResponse.data['data']?['filePath'] ??
              uploadResponse.data['data']?['url'];

          bool confirmSuccess = false;
          try {
            final confirmResponse = await _apiService.post(
              '/local-record/confirm-upload',
              data: {
                'taskId': record['task_id'],
                'filePath': serverFilePath ?? filePath,
                'fileSize': record['file_size'] ?? 0,
                'durationSeconds': record['duration_seconds'] ?? 0,
                'startTime': record['start_time'],
                'endTime': record['end_time'],
              },
            );

            confirmSuccess = confirmResponse.data['code'] == 200;
          } catch (e) {
            _logger.w('确认录像上传失败: ${record['task_id']}, $e');
          }

          if (confirmSuccess) {
            await _localRecordTaskDb.updateSyncStatus(
              record['task_id'],
              1,
              syncTime: DateTime.now().toIso8601String(),
            );
            _logger.d('录像上传并确认成功: ${record['task_id']}');
          } else {
            _logger.w('录像确认失败，保持未同步状态: ${record['task_id']}');
          }
        } catch (e) {
          _logger.w('上传本地录像失败: ${record['task_id']}, $e');
        }
      }

      _logger.d('本地录像上传完成');
    } catch (e) {
      _logger.w('本地录像上传失败: $e');
    }
  }

  Future<void> _uploadCarbonFootprintRecords() async {
    _currentModule = '碳足迹记录';
    _moduleController.add(_currentModule!);

    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过碳足迹记录上传');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _carbonFootprintDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步碳足迹记录');
        return;
      }

      _logger.d('待同步碳足迹记录数量: ${unsynced.length}');

      final List<CarbonFootprintRecord> records = unsynced
          .map((e) => CarbonFootprintRecord.fromJson(e))
          .toList();

      final SyncResult result =
          await _apiService.submitCarbonFootprintBatch(records);

      final now = DateTime.now();
      final syncTime = now.toIso8601String();

      for (var record in unsynced) {
        final id = record['id'] as int?;
        if (id == null) continue;

        final offlineId = record['offline_id'] as String?;
        final isSuccess = !result.failedIds.contains(offlineId);

        if (isSuccess) {
          await _carbonFootprintDb.update({
            'id': id,
            'sync_status': 1,
            'sync_time': syncTime,
            'update_time': now.toIso8601String(),
          });
        } else {
          await _carbonFootprintDb.updateSyncStatus(id, 2);
        }
      }

      _logger.d(
          '碳足迹记录上传完成，成功: ${result.success}/${result.total}, 失败: ${result.failed}');
    } catch (e) {
      _logger.w('碳足迹记录上传失败: $e');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      Map<String, dynamic>? latestLog = await _syncLogDb.getLatestSync(null);
      if (latestLog != null) {
        String? endTime = latestLog['sync_end_time'];
        if (endTime != null && endTime.isNotEmpty) {
          return DateTime.parse(endTime);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _updateStatus(SyncStatus status) {
    _syncStatus = status;
    _statusController.add(status);
  }

  void _updateProgress(int completed) {
    _completedCount = completed;
    if (_totalCount > 0) {
      _progress = completed / _totalCount;
      _progressController.add(_progress);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
    _progressController.close();
    _moduleController.close();
  }
}
