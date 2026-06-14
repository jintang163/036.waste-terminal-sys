import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../db/waste_in_record_db.dart';
import 'api_service.dart';

class WasteInService {
  static final WasteInService _instance = WasteInService._internal();
  factory WasteInService() => _instance;

  final WasteInRecordDb _wasteInRecordDb = WasteInRecordDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  WasteInService._internal();

  Future<Map<String, dynamic>> addWasteInRecord(Map<String, dynamic> record) async {
    try {
      String offlineId = _uuid.v4();
      record['offline_id'] = offlineId;
      record['sync_status'] = 0;
      record['create_time'] = DateTime.now().toIso8601String();
      record['update_time'] = DateTime.now().toIso8601String();
      record['is_deleted'] = 0;

      int id = await _wasteInRecordDb.insert(record);
      _logger.i('新增入库记录成功，本地ID: $id, offlineId: $offlineId');

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        try {
          await _syncSingleRecord(record);
        } catch (e) {
          _logger.w('立即同步入库记录失败，将在下次同步时重试: $e');
        }
      }

      return {...record, 'id': id};
    } catch (e) {
      _logger.e('新增入库记录失败: $e');
      rethrow;
    }
  }

  Future<void> _syncSingleRecord(Map<String, dynamic> record) async {
    try {
      final response = await _apiService.post(
        '/waste-in/add',
        data: record,
      );

      String? recordId = response.data['data']?['recordId'];
      await _wasteInRecordDb.updateSyncStatus(
        record['offline_id'],
        1,
        syncTime: DateTime.now().toIso8601String(),
        recordId: recordId,
      );
      _logger.d('入库记录同步成功: ${record['offline_id']}');
    } catch (e) {
      _logger.e('同步入库记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWasteInList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _wasteInRecordDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        syncStatus: syncStatus,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取入库记录列表失败: $e');
      return [];
    }
  }

  Future<int> getWasteInCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _wasteInRecordDb.queryCount(
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        syncStatus: syncStatus,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取入库记录数量失败: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getWasteInByOfflineId(String offlineId) async {
    try {
      return await _wasteInRecordDb.queryByOfflineId(offlineId);
    } catch (e) {
      _logger.e('根据离线ID获取入库记录失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWasteInByRecordId(String recordId) async {
    try {
      Map<String, dynamic>? record = await _wasteInRecordDb.queryByRecordId(recordId);
      if (record != null) {
        return record;
      }

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        final response = await _apiService.get('/waste-in/$recordId');
        if (response.data['data'] != null) {
          Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data']);
          return data;
        }
      }
      return null;
    } catch (e) {
      _logger.e('根据记录ID获取入库记录失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    try {
      return await _wasteInRecordDb.queryUnsynced();
    } catch (e) {
      _logger.e('获取待同步入库记录失败: $e');
      return [];
    }
  }

  Future<int> getUnsyncedCount() async {
    try {
      return await _wasteInRecordDb.queryUnsyncedCount();
    } catch (e) {
      _logger.e('获取待同步入库记录数量失败: $e');
      return 0;
    }
  }

  Future<bool> isRecordSynced(String offlineId) async {
    try {
      Map<String, dynamic>? record = await _wasteInRecordDb.queryByOfflineId(offlineId);
      if (record == null) {
        return false;
      }
      return record['sync_status'] == 1;
    } catch (e) {
      _logger.e('检查入库记录同步状态失败: $e');
      return false;
    }
  }

  Future<void> syncWasteInRecords() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过入库记录同步');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _wasteInRecordDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步入库记录');
        return;
      }

      _logger.i('开始同步入库记录，数量: ${unsynced.length}');

      for (var record in unsynced) {
        try {
          await _syncSingleRecord(record);
        } catch (e) {
          _logger.w('同步入库记录失败: ${record['offline_id']}, $e');
        }
      }

      _logger.i('入库记录同步完成');
    } catch (e) {
      _logger.e('同步入库记录失败: $e');
    }
  }

  Future<bool> updateWasteInRecord(Map<String, dynamic> record) async {
    try {
      int count = await _wasteInRecordDb.update(record);
      if (count > 0) {
        bool hasNetwork = await _apiService.isNetworkAvailable();
        if (hasNetwork) {
          try {
            await _wasteInRecordDb.updateSyncStatus(
              record['offline_id'],
              0,
            );
          } catch (e) {
            _logger.w('更新同步状态失败: $e');
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('更新入库记录失败: $e');
      return false;
    }
  }

  Future<bool> deleteWasteInRecord(String offlineId) async {
    try {
      int count = await _wasteInRecordDb.deleteByOfflineId(offlineId);
      return count > 0;
    } catch (e) {
      _logger.e('删除入库记录失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    String? startTime,
    String? endTime,
  }) async {
    try {
      List<Map<String, dynamic>> allRecords = await _wasteInRecordDb.queryAll();

      double totalWeight = 0;
      double totalQuantity = 0;
      int totalCount = 0;

      for (var record in allRecords) {
        if (record['is_deleted'] == 0) {
          totalWeight += (record['weight'] ?? 0) as double;
          totalQuantity += (record['quantity'] ?? 0) as double;
          totalCount++;
        }
      }

      return {
        'total_count': totalCount,
        'total_weight': totalWeight,
        'total_quantity': totalQuantity,
      };
    } catch (e) {
      _logger.e('获取入库统计失败: $e');
      return {
        'total_count': 0,
        'total_weight': 0.0,
        'total_quantity': 0.0,
      };
    }
  }
}
