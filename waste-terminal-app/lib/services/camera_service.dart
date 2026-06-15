import 'package:logger/logger.dart';

import '../config/app_constants.dart';
import '../models/camera_model.dart';
import '../models/page_result.dart';
import 'api_service.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  CameraService._internal();

  Future<List<CameraModel>> getCameraList({
    String? keyword,
    String? cameraType,
    int? status,
    String? warehouseCode,
  }) async {
    try {
      final response = await _apiService.get(
        '/camera/list',
        queryParameters: {
          if (keyword != null) 'keyword': keyword,
          if (cameraType != null) 'cameraType': cameraType,
          if (status != null) 'status': status,
          if (warehouseCode != null) 'warehouseCode': warehouseCode,
        },
      );
      return _apiService.parseList<CameraModel>(response, (e) => CameraModel.fromJson(e));
    } catch (e) {
      _logger.e('获取摄像头列表失败: $e');
      rethrow;
    }
  }

  Future<PageResult<CameraModel>> getCameraPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? cameraType,
    int? status,
    String? warehouseCode,
  }) async {
    try {
      final response = await _apiService.get(
        '/camera/page',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (keyword != null) 'keyword': keyword,
          if (cameraType != null) 'cameraType': cameraType,
          if (status != null) 'status': status,
          if (warehouseCode != null) 'warehouseCode': warehouseCode,
        },
      );
      return _apiService.parsePage<CameraModel>(response, (e) => CameraModel.fromJson(e));
    } catch (e) {
      _logger.e('分页获取摄像头失败: $e');
      rethrow;
    }
  }

  Future<CameraModel?> getCameraDetail(int id) async {
    try {
      final response = await _apiService.get('/camera/$id');
      return _apiService.parseData<CameraModel>(response, (e) => CameraModel.fromJson(e));
    } catch (e) {
      _logger.e('获取摄像头详情失败: $e');
      rethrow;
    }
  }

  Future<String?> getPreviewUrl(int id) async {
    try {
      final response = await _apiService.get('/camera/$id/preview-url');
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        return data['previewUrl'] as String?;
      }
      return data as String?;
    } catch (e) {
      _logger.e('获取预览地址失败: $e');
      rethrow;
    }
  }

  Future<String?> getSnapshotUrl(int id) async {
    try {
      final response = await _apiService.get('/camera/$id/snapshot-url');
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        return data['snapshotUrl'] as String?;
      }
      return data as String?;
    } catch (e) {
      _logger.e('获取抓拍地址失败: $e');
      rethrow;
    }
  }

  Future<bool> toggleAi(int id, bool enabled) async {
    try {
      final response = await _apiService.put(
        '/camera/ai/$id',
        queryParameters: {'enabled': enabled},
      );
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('切换AI检测状态失败: $e');
      rethrow;
    }
  }
}
