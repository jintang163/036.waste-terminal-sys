import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../db/inventory_check_db.dart';
import 'api_service.dart';

class InventoryCheckService {
  static final InventoryCheckService _instance = InventoryCheckService._internal();
  factory InventoryCheckService() => _instance;

  final InventoryCheckDb _inventoryCheckDb = InventoryCheckDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  InventoryCheckService._internal();

  Future<Map<String, dynamic>> createInventoryCheck(Map<String, dynamic> check) async {
    try {
      String offlineId = _uuid.v4();
      check['offline_id'] = offlineId;
      check['status'] = check['status'] ?? 0;
      check['sync_status'] = 0;
      check['create_time'] = DateTime.now().toIso8601String();
      check['update_time'] = DateTime.now().toIso8601String();
      check['is_deleted'] = 0;

      int id = await _inventoryCheckDb.insertCheck(check);
      _logger.i('创建盘点单成功，本地ID: $id, offlineId: $offlineId');

      return {...check, 'id': id};
    } catch (e) {
      _logger.e('创建盘点单失败: $e');
      rethrow;
    }
  }

  Future<int> addCheckDetail(Map<String, dynamic> detail) async {
    try {
      String detailId = _uuid.v4();
      detail['detail_id'] = detailId;
      detail['create_time'] = DateTime.now().toIso8601String();
      detail['update_time'] = DateTime.now().toIso8601String();
      detail['is_deleted'] = 0;

      int id = await _inventoryCheckDb.insertDetail(detail);
      _logger.d('添加盘点明细成功: $id');
      return id;
    } catch (e) {
      _logger.e('添加盘点明细失败: $e');
      rethrow;
    }
  }

  Future<void> batchAddCheckDetails(List<Map<String, dynamic>> detailList) async {
    try {
      for (var detail in detailList) {
        detail['detail_id'] = _uuid.v4();
        detail['create_time'] = DateTime.now().toIso8601String();
        detail['update_time'] = DateTime.now().toIso8601String();
        detail['is_deleted'] = 0;
      }
      await _inventoryCheckDb.batchInsertDetails(detailList);
      _logger.d('批量添加盘点明细成功，数量: ${detailList.length}');
    } catch (e) {
      _logger.e('批量添加盘点明细失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCheckList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    int? status,
    int? syncStatus,
    String? checkType,
    String? warehouseId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _inventoryCheckDb.queryChecksWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        status: status,
        syncStatus: syncStatus,
        checkType: checkType,
        warehouseId: warehouseId,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取盘点列表失败: $e');
      return [];
    }
  }

  Future<int> getCheckCount({
    String? keyword,
    int? status,
    int? syncStatus,
    String? checkType,
    String? warehouseId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _inventoryCheckDb.queryChecksCount(
        keyword: keyword,
        status: status,
        syncStatus: syncStatus,
        checkType: checkType,
        warehouseId: warehouseId,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取盘点数量失败: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getCheckDetail(String offlineId) async {
    try {
      return await _inventoryCheckDb.queryCheckByOfflineId(offlineId);
    } catch (e) {
      _logger.e('获取盘点单详情失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCheckItemDetails(String checkOfflineId) async {
    try {
      return await _inventoryCheckDb.queryDetailsByCheckOfflineId(checkOfflineId);
    } catch (e) {
      _logger.e('获取盘点明细失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedChecks() async {
    try {
      return await _inventoryCheckDb.queryUnsyncedChecks();
    } catch (e) {
      _logger.e('获取待同步盘点失败: $e');
      return [];
    }
  }

  Future<int> getUnsyncedCount() async {
    try {
      return await _inventoryCheckDb.queryUnsyncedChecksCount();
    } catch (e) {
      _logger.e('获取待同步盘点数量失败: $e');
      return 0;
    }
  }

  Future<bool> updateInventoryCheck(Map<String, dynamic> check) async {
    try {
      int count = await _inventoryCheckDb.updateCheck(check);
      return count > 0;
    } catch (e) {
      _logger.e('更新盘点单失败: $e');
      return false;
    }
  }

  Future<bool> updateCheckDetail(Map<String, dynamic> detail) async {
    try {
      int count = await _inventoryCheckDb.updateDetail(detail);
      return count > 0;
    } catch (e) {
      _logger.e('更新盘点明细失败: $e');
      return false;
    }
  }

  Future<void> syncInventoryChecks() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过盘点同步');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _inventoryCheckDb.queryUnsyncedChecks();
      if (unsynced.isEmpty) {
        _logger.d('无待同步盘点记录');
        return;
      }

      _logger.i('开始同步盘点记录，数量: ${unsynced.length}');

      for (var check in unsynced) {
        try {
          await _syncSingleCheck(check);
        } catch (e) {
          _logger.w('同步盘点记录失败: ${check['offline_id']}, $e');
        }
      }

      _logger.i('盘点记录同步完成');
    } catch (e) {
      _logger.e('同步盘点记录失败: $e');
    }
  }

  Future<void> _syncSingleCheck(Map<String, dynamic> check) async {
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
      _logger.d('盘点记录同步成功: $checkOfflineId');
    } catch (e) {
      _logger.e('同步盘点记录失败: $e');
      rethrow;
    }
  }

  Future<bool> deleteInventoryCheck(String offlineId) async {
    try {
      int count = await _inventoryCheckDb.deleteCheckByOfflineId(offlineId);
      return count > 0;
    } catch (e) {
      _logger.e('删除盘点单失败: $e');
      return false;
    }
  }

  Future<bool> deleteCheckDetail(String detailId) async {
    try {
      int count = await _inventoryCheckDb.deleteDetailByDetailId(detailId);
      return count > 0;
    } catch (e) {
      _logger.e('删除盘点明细失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    String? startTime,
    String? endTime,
  }) async {
    try {
      List<Map<String, dynamic>> allChecks = await _inventoryCheckDb.queryAllChecks();

      int totalCount = 0;
      int pendingCount = 0;
      int completedCount = 0;

      for (var check in allChecks) {
        if (check['is_deleted'] == 0) {
          totalCount++;
          int status = check['status'] as int? ?? 0;
          if (status == 0) {
            pendingCount++;
          } else if (status == 1) {
            completedCount++;
          }
        }
      }

      return {
        'total_count': totalCount,
        'pending_count': pendingCount,
        'completed_count': completedCount,
      };
    } catch (e) {
      _logger.e('获取盘点统计失败: $e');
      return {
        'total_count': 0,
        'pending_count': 0,
        'completed_count': 0,
      };
    }
  }
}
