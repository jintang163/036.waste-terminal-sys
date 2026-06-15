import 'package:logger/logger.dart';

import '../models/ai_capture_event.dart';
import '../models/page_result.dart';
import 'api_service.dart';

class AiCaptureService {
  static final AiCaptureService _instance = AiCaptureService._internal();
  factory AiCaptureService() => _instance;

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  AiCaptureService._internal();

  Future<PageResult<AiCaptureEvent>> getCaptureEventPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? eventType,
    String? eventCategory,
    int? handleStatus,
    String? cameraCode,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final response = await _apiService.get(
        '/ai-capture/page',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (keyword != null) 'keyword': keyword,
          if (eventType != null) 'eventType': eventType,
          if (eventCategory != null) 'eventCategory': eventCategory,
          if (handleStatus != null) 'handleStatus': handleStatus,
          if (cameraCode != null) 'cameraCode': cameraCode,
          if (startTime != null) 'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
        },
      );
      return _apiService.parsePage<AiCaptureEvent>(response, (e) => AiCaptureEvent.fromJson(e));
    } catch (e) {
      _logger.e('分页获取AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<AiCaptureEvent?> getCaptureEventDetail(int id) async {
    try {
      final response = await _apiService.get('/ai-capture/$id');
      return _apiService.parseData<AiCaptureEvent>(response, (e) => AiCaptureEvent.fromJson(e));
    } catch (e) {
      _logger.e('获取AI抓拍事件详情失败: $e');
      rethrow;
    }
  }

  Future<List<AiCaptureEvent>> getUnhandledList() async {
    try {
      final response = await _apiService.get('/ai-capture/unhandled');
      return _apiService.parseList<AiCaptureEvent>(response, (e) => AiCaptureEvent.fromJson(e));
    } catch (e) {
      _logger.e('获取未处理AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<List<AiCaptureEvent>> getCaptureEventList({
    String? eventType,
    String? eventCategory,
    int? handleStatus,
    String? cameraCode,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final response = await _apiService.get(
        '/ai-capture/list',
        queryParameters: {
          if (eventType != null) 'eventType': eventType,
          if (eventCategory != null) 'eventCategory': eventCategory,
          if (handleStatus != null) 'handleStatus': handleStatus,
          if (cameraCode != null) 'cameraCode': cameraCode,
          if (startTime != null) 'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
        },
      );
      return _apiService.parseList<AiCaptureEvent>(response, (e) => AiCaptureEvent.fromJson(e));
    } catch (e) {
      _logger.e('获取AI抓拍事件列表失败: $e');
      rethrow;
    }
  }

  Future<bool> handleEvent(int id, String handleRemark) async {
    try {
      final response = await _apiService.put(
        '/ai-capture/handle/$id',
        data: {'handleRemark': handleRemark},
      );
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('处理AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<bool> ignoreEvent(int id) async {
    try {
      final response = await _apiService.put('/ai-capture/ignore/$id');
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('忽略AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _apiService.get('/ai-capture/statistics');
      return Map<String, dynamic>.from(response.data['data'] ?? {});
    } catch (e) {
      _logger.e('获取AI抓拍统计失败: $e');
      rethrow;
    }
  }
}
