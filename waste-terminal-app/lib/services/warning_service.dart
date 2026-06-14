import 'package:logger/logger.dart';

import '../db/warning_record_db.dart';
import 'api_service.dart';

class WarningService {
  static final WarningService _instance = WarningService._internal();
  factory WarningService() => _instance;

  final WarningRecordDb _warningRecordDb = WarningRecordDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  WarningService._internal();

  Future<List<Map<String, dynamic>>> getWarningList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? warningType,
    int? warningLevel,
    int? status,
    String? wasteCode,
    String? startTime,
    String? endTime,
    bool forceRefresh = false,
  }) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();

      if (forceRefresh && hasNetwork) {
        await _syncWarningFromNetwork();
      }

      return await _warningRecordDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        warningType: warningType,
        warningLevel: warningLevel,
        status: status,
        wasteCode: wasteCode,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取预警列表失败: $e');
      return await _warningRecordDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        warningType: warningType,
        warningLevel: warningLevel,
        status: status,
        wasteCode: wasteCode,
        startTime: startTime,
        endTime: endTime,
      );
    }
  }

  Future<int> getWarningCount({
    String? keyword,
    String? warningType,
    int? warningLevel,
    int? status,
    String? wasteCode,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _warningRecordDb.queryCount(
        keyword: keyword,
        warningType: warningType,
        warningLevel: warningLevel,
        status: status,
        wasteCode: wasteCode,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取预警数量失败: $e');
      return 0;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      return await _warningRecordDb.queryUnreadCount();
    } catch (e) {
      _logger.e('获取未处理预警数量失败: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getWarningDetail(String warningId) async {
    try {
      Map<String, dynamic>? warning = await _warningRecordDb.queryByWarningId(warningId);
      if (warning != null) {
        return warning;
      }

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        final response = await _apiService.get('/warning/$warningId');
        if (response.data['data'] != null) {
          Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data']);
          return data;
        }
      }
      return null;
    } catch (e) {
      _logger.e('获取预警详情失败: $e');
      return null;
    }
  }

  Future<bool> handleWarning(
    String warningId, {
    String? handler,
    String? handlerId,
    String? handleRemark,
  }) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();

      if (hasNetwork) {
        try {
          await _apiService.post(
            '/warning/handle',
            data: {
              'warningId': warningId,
              'handler': handler,
              'handlerId': handlerId,
              'handleRemark': handleRemark,
            },
          );
        } catch (e) {
          _logger.w('网络处理预警失败: $e');
        }
      }

      int count = await _warningRecordDb.updateHandleStatus(
        warningId,
        1,
        handleTime: DateTime.now().toIso8601String(),
        handler: handler,
        handlerId: handlerId,
        handleRemark: handleRemark,
      );

      return count > 0;
    } catch (e) {
      _logger.e('处理预警失败: $e');
      return false;
    }
  }

  Future<void> syncWarning() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过预警同步');
        return;
      }
      await _syncWarningFromNetwork();
    } catch (e) {
      _logger.e('同步预警失败: $e');
      rethrow;
    }
  }

  Future<void> _syncWarningFromNetwork() async {
    try {
      final response = await _apiService.get('/warning/list');
      List<dynamic> data = response.data['data'] ?? [];
      List<Map<String, dynamic>> warningList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _warningRecordDb.replaceAll(warningList);
      _logger.i('预警信息同步完成，数量: ${warningList.length}');
    } catch (e) {
      _logger.e('从网络同步预警信息失败: $e');
      rethrow;
    }
  }

  Future<bool> updateWarning(Map<String, dynamic> warning) async {
    try {
      int count = await _warningRecordDb.update(warning);
      return count > 0;
    } catch (e) {
      _logger.e('更新预警失败: $e');
      return false;
    }
  }

  Future<bool> deleteWarning(String warningId) async {
    try {
      int count = await _warningRecordDb.deleteByWarningId(warningId);
      return count > 0;
    } catch (e) {
      _logger.e('删除预警失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      List<Map<String, dynamic>> allWarnings = await _warningRecordDb.queryAll();

      int totalCount = 0;
      int unhandledCount = 0;
      int handledCount = 0;
      int highLevelCount = 0;
      int mediumLevelCount = 0;
      int lowLevelCount = 0;

      for (var warning in allWarnings) {
        if (warning['is_deleted'] == 0) {
          totalCount++;

          int status = warning['status'] as int? ?? 0;
          if (status == 0) {
            unhandledCount++;
          } else {
            handledCount++;
          }

          int? level = warning['warning_level'] as int?;
          if (level == 3) {
            highLevelCount++;
          } else if (level == 2) {
            mediumLevelCount++;
          } else if (level == 1) {
            lowLevelCount++;
          }
        }
      }

      return {
        'total_count': totalCount,
        'unhandled_count': unhandledCount,
        'handled_count': handledCount,
        'high_level_count': highLevelCount,
        'medium_level_count': mediumLevelCount,
        'low_level_count': lowLevelCount,
      };
    } catch (e) {
      _logger.e('获取预警统计失败: $e');
      return {
        'total_count': 0,
        'unhandled_count': 0,
        'handled_count': 0,
        'high_level_count': 0,
        'medium_level_count': 0,
        'low_level_count': 0,
      };
    }
  }

  Future<List<String>> getWarningTypes() async {
    try {
      List<Map<String, dynamic>> all = await _warningRecordDb.queryAll();
      Set<String> types = {};
      for (var item in all) {
        if (item['warning_type'] != null && item['warning_type'].toString().isNotEmpty) {
          types.add(item['warning_type'].toString());
        }
      }
      return types.toList();
    } catch (e) {
      _logger.e('获取预警类型失败: $e');
      return [];
    }
  }
}
