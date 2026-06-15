import 'package:logger/logger.dart';

import '../models/local_record_task.dart';
import '../models/page_result.dart';
import 'api_service.dart';

class LocalRecordService {
  static final LocalRecordService _instance = LocalRecordService._internal();
  factory LocalRecordService() => _instance;

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  LocalRecordService._internal();

  Future<PageResult<LocalRecordTask>> getRecordPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? cameraCode,
    String? triggerType,
    int? status,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final response = await _apiService.get(
        '/local-record/page',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (keyword != null) 'keyword': keyword,
          if (cameraCode != null) 'cameraCode': cameraCode,
          if (triggerType != null) 'triggerType': triggerType,
          if (status != null) 'status': status,
          if (syncStatus != null) 'syncStatus': syncStatus,
          if (startTime != null) 'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
        },
      );
      return _apiService.parsePage<LocalRecordTask>(response, (e) => LocalRecordTask.fromJson(e));
    } catch (e) {
      _logger.e('分页获取本地录像记录失败: $e');
      rethrow;
    }
  }

  Future<LocalRecordTask?> getRecordDetail(int id) async {
    try {
      final response = await _apiService.get('/local-record/$id');
      return _apiService.parseData<LocalRecordTask>(response, (e) => LocalRecordTask.fromJson(e));
    } catch (e) {
      _logger.e('获取本地录像详情失败: $e');
      rethrow;
    }
  }

  Future<List<LocalRecordTask>> getUnsyncedRecords() async {
    try {
      final response = await _apiService.get('/local-record/unsynced');
      return _apiService.parseList<LocalRecordTask>(response, (e) => LocalRecordTask.fromJson(e));
    } catch (e) {
      _logger.e('获取未同步录像记录失败: $e');
      rethrow;
    }
  }

  Future<LocalRecordTask?> triggerRecord({
    required String cameraCode,
    required String triggerType,
    String? triggerId,
    int preSeconds = 10,
    int postSeconds = 30,
  }) async {
    try {
      final response = await _apiService.post(
        '/local-record/trigger',
        data: {
          'cameraCode': cameraCode,
          'triggerType': triggerType,
          if (triggerId != null) 'triggerId': triggerId,
          'preSeconds': preSeconds,
          'postSeconds': postSeconds,
        },
      );
      return _apiService.parseData<LocalRecordTask>(response, (e) => LocalRecordTask.fromJson(e));
    } catch (e) {
      _logger.e('触发录像失败: $e');
      rethrow;
    }
  }

  Future<bool> updateSyncStatus(int id, int syncStatus) async {
    try {
      final response = await _apiService.put(
        '/local-record/sync-status/$id',
        data: {'syncStatus': syncStatus},
      );
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('更新同步状态失败: $e');
      rethrow;
    }
  }

  Future<bool> batchUpdateSyncStatus(List<int> ids, int syncStatus) async {
    try {
      final response = await _apiService.put(
        '/local-record/batch-sync-status',
        data: {
          'ids': ids,
          'syncStatus': syncStatus,
        },
      );
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('批量更新同步状态失败: $e');
      rethrow;
    }
  }
}
