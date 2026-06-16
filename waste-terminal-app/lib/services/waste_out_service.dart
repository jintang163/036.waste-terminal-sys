import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../config/app_constants.dart';
import '../db/waste_out_record_db.dart';
import 'api_service.dart';
import 'operation_log_service.dart';

class WasteOutService {
  static final WasteOutService _instance = WasteOutService._internal();
  factory WasteOutService() => _instance;

  final WasteOutRecordDb _wasteOutRecordDb = WasteOutRecordDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  WasteOutService._internal();

  Future<Map<String, dynamic>> addWasteOutRecord(Map<String, dynamic> record) async {
    try {
      String offlineId = _uuid.v4();
      record['offline_id'] = offlineId;
      record['sync_status'] = 0;
      record['create_time'] = DateTime.now().toIso8601String();
      record['update_time'] = DateTime.now().toIso8601String();
      record['is_deleted'] = 0;

      int id = await _wasteOutRecordDb.insert(record);
      _logger.i('新增出库记录成功，本地ID: $id, offlineId: $offlineId');

      bool hasNetwork = await _apiService.isNetworkAvailable();

      try {
        await OperationLogService().logInfo(
          '新增出库记录',
          category: BusinessConstants.logCategoryOperation,
          module: 'waste_out',
          action: 'add',
          extra: {
            'offlineId': offlineId,
            'wasteCode': record['waste_code'],
            'wasteName': record['waste_name'],
            'weight': record['weight'],
          },
        );
      } catch (_) {}

      if (hasNetwork) {
        try {
          await _syncSingleRecord(record);
        } catch (e) {
          _logger.w('立即同步出库记录失败，将在下次同步时重试: $e');
        }
      }

      return {...record, 'id': id};
    } catch (e) {
      _logger.e('新增出库记录失败: $e');
      try {
        await OperationLogService().logError(
          '新增出库记录失败: $e',
          category: BusinessConstants.logCategoryOperation,
          module: 'waste_out',
          action: 'add',
          extra: {
            'error': e.toString(),
            'wasteCode': record['waste_code'],
          },
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _syncSingleRecord(Map<String, dynamic> record) async {
    try {
      final response = await _apiService.post(
        '/waste-out/add',
        data: record,
      );

      String? recordId = response.data['data']?['recordId'];
      await _wasteOutRecordDb.updateSyncStatus(
        record['offline_id'],
        1,
        syncTime: DateTime.now().toIso8601String(),
        recordId: recordId,
      );
      _logger.d('出库记录同步成功: ${record['offline_id']}');
    } catch (e) {
      _logger.e('同步出库记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWasteOutList({
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
      return await _wasteOutRecordDb.queryWithPagination(
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
      _logger.e('获取出库记录列表失败: $e');
      return [];
    }
  }

  Future<int> getWasteOutCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _wasteOutRecordDb.queryCount(
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        syncStatus: syncStatus,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取出库记录数量失败: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getWasteOutByOfflineId(String offlineId) async {
    try {
      return await _wasteOutRecordDb.queryByOfflineId(offlineId);
    } catch (e) {
      _logger.e('根据离线ID获取出库记录失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWasteOutByRecordId(String recordId) async {
    try {
      Map<String, dynamic>? record = await _wasteOutRecordDb.queryByRecordId(recordId);
      if (record != null) {
        return record;
      }

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        final response = await _apiService.get('/waste-out/$recordId');
        if (response.data['data'] != null) {
          Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data']);
          return data;
        }
      }
      return null;
    } catch (e) {
      _logger.e('根据记录ID获取出库记录失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    try {
      return await _wasteOutRecordDb.queryUnsynced();
    } catch (e) {
      _logger.e('获取待同步出库记录失败: $e');
      return [];
    }
  }

  Future<int> getUnsyncedCount() async {
    try {
      return await _wasteOutRecordDb.queryUnsyncedCount();
    } catch (e) {
      _logger.e('获取待同步出库记录数量失败: $e');
      return 0;
    }
  }

  Future<bool> isRecordSynced(String offlineId) async {
    try {
      Map<String, dynamic>? record = await _wasteOutRecordDb.queryByOfflineId(offlineId);
      if (record == null) {
        return false;
      }
      return record['sync_status'] == 1;
    } catch (e) {
      _logger.e('检查出库记录同步状态失败: $e');
      return false;
    }
  }

  Future<void> syncWasteOutRecords() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过出库记录同步');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _wasteOutRecordDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步出库记录');
        return;
      }

      _logger.i('开始同步出库记录，数量: ${unsynced.length}');

      for (var record in unsynced) {
        try {
          await _syncSingleRecord(record);
        } catch (e) {
          _logger.w('同步出库记录失败: ${record['offline_id']}, $e');
        }
      }

      _logger.i('出库记录同步完成');
    } catch (e) {
      _logger.e('同步出库记录失败: $e');
    }
  }

  Future<bool> updateWasteOutRecord(Map<String, dynamic> record) async {
    try {
      int count = await _wasteOutRecordDb.update(record);
      if (count > 0) {
        bool hasNetwork = await _apiService.isNetworkAvailable();
        if (hasNetwork) {
          try {
            await _wasteOutRecordDb.updateSyncStatus(
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
      _logger.e('更新出库记录失败: $e');
      return false;
    }
  }

  Future<bool> deleteWasteOutRecord(String offlineId) async {
    try {
      int count = await _wasteOutRecordDb.deleteByOfflineId(offlineId);
      return count > 0;
    } catch (e) {
      _logger.e('删除出库记录失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    String? startTime,
    String? endTime,
  }) async {
    try {
      List<Map<String, dynamic>> allRecords = await _wasteOutRecordDb.queryAll();

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
      _logger.e('获取出库统计失败: $e');
      return {
        'total_count': 0,
        'total_weight': 0.0,
        'total_quantity': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> checkDoubleReviewRequired(int wasteId) async {
    final result = <String, dynamic>{
      'required': false,
      'reasons': <String>[],
    };

    final hasNetwork = await _apiService.isNetworkAvailable();
    if (hasNetwork) {
      try {
        final response = await _apiService.get(
          ApiConstants.wasteOutCheckDoubleReview,
          queryParameters: {'wasteId': wasteId},
        );
        if (response != null && response['code'] == 200) {
          final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
          result['required'] = data['required'] as bool? ?? false;
          result['reasons'] = List<String>.from(data['reasons'] as List? ?? []);
          return result;
        }
      } catch (e) {
        _logger.w('检查是否需要双人复核失败: $e');
      }
    }

    return result;
  }

  Future<int> updateReviewStatus({
    required String outNo,
    required int reviewStatus,
    String? reviewRemark,
    int? reviewerId,
    String? reviewerName,
    String? reviewerFaceAuthId,
    String? reviewerFaceId,
    String? reviewerFaceImage,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'review_status': reviewStatus,
        'review_time': DateTime.now().toIso8601String(),
        'review_remark': reviewRemark,
        'reviewer_id': reviewerId,
        'reviewer_name': reviewerName,
        'reviewer_face_auth_id': reviewerFaceAuthId,
        'reviewer_face_id': reviewerFaceId,
        'reviewer_face_image': reviewerFaceImage,
        'sync_status': 0,
        'update_time': DateTime.now().toIso8601String(),
      };
      return await _wasteOutRecordDb.updateByOutNo(outNo, updateData);
    } catch (e) {
      _logger.e('更新出库记录复核状态失败: $e');
      return 0;
    }
  }

  Future<int> updateOutRecordStatus({
    required String outNo,
    required int status,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'sync_status': 0,
        'update_time': DateTime.now().toIso8601String(),
      };
      return await _wasteOutRecordDb.updateByOutNo(outNo, updateData);
    } catch (e) {
      _logger.e('更新出库记录状态失败: $e');
      return 0;
    }
  }
}
