import 'package:logger/logger.dart';

import '../config/app_constants.dart';
import '../db/face_auth_record_db.dart';
import '../models/face_auth_record_model.dart';
import '../models/page_result.dart';
import 'api_service.dart';

class FaceAuthRecordService {
  static final FaceAuthRecordService _instance = FaceAuthRecordService._internal();
  factory FaceAuthRecordService() => _instance;

  final ApiService _apiService = ApiService();
  final FaceAuthRecordDb _faceAuthRecordDb = FaceAuthRecordDb();
  final Logger _logger = Logger();

  FaceAuthRecordService._internal();

  Future<int> saveAuthRecord(FaceAuthRecordModel record) async {
    try {
      final dbMap = record.toDbMap();
      return await _faceAuthRecordDb.insert(dbMap);
    } catch (e) {
      _logger.e('保存人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<List<FaceAuthRecordModel>> getUnsyncedRecords() async {
    try {
      final list = await _faceAuthRecordDb.queryUnsynced();
      return list.map((e) => FaceAuthRecordModel.fromDbMap(e)).toList();
    } catch (e) {
      _logger.e('获取未同步认证记录失败: $e');
      return [];
    }
  }

  Future<List<FaceAuthRecordModel>> getRecordsByBusiness(
      String businessType, String businessId) async {
    try {
      final list = await _faceAuthRecordDb.queryByBusiness(businessType, businessId);
      return list.map((e) => FaceAuthRecordModel.fromDbMap(e)).toList();
    } catch (e) {
      _logger.e('根据业务获取认证记录失败: $e');
      return [];
    }
  }

  Future<List<FaceAuthRecordModel>> getRecordsByUserId(int userId) async {
    try {
      final list = await _faceAuthRecordDb.queryByUserId(userId);
      return list.map((e) => FaceAuthRecordModel.fromDbMap(e)).toList();
    } catch (e) {
      _logger.e('根据用户获取认证记录失败: $e');
      return [];
    }
  }

  Future<bool> updateSyncStatus(String authId, int syncStatus) async {
    try {
      final count = await _faceAuthRecordDb.updateSyncStatus(authId, syncStatus);
      return count > 0;
    } catch (e) {
      _logger.e('更新认证记录同步状态失败: $e');
      return false;
    }
  }

  Future<bool> syncUnsyncedToServer() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，暂不同步认证记录');
        return false;
      }

      final unsynced = await getUnsyncedRecords();
      if (unsynced.isEmpty) {
        return true;
      }

      _logger.d('待同步人脸认证记录数量: ${unsynced.length}');

      final response = await _apiService.post(
        AppConstants.faceAuthBatchAdd,
        data: unsynced.map((e) => e.toJson()).toList(),
      );

      if (response.data['code'] == 200) {
        final authIds = unsynced.map((e) => e.authId!).toList();
        await _faceAuthRecordDb.batchUpdateSyncStatus(authIds, 1);
        _logger.d('人脸认证记录同步成功，数量: ${unsynced.length}');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('同步人脸认证记录失败: $e');
      return false;
    }
  }

  Future<PageResult<FaceAuthRecordModel>> getServerAuthPage({
    int pageNum = 1,
    int pageSize = 20,
    String? businessType,
    String? businessNo,
    int? userId,
  }) async {
    try {
      final response = await _apiService.get(
        AppConstants.faceAuthPage,
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (businessType != null) 'businessType': businessType,
          if (businessNo != null) 'businessNo': businessNo,
          if (userId != null) 'userId': userId,
        },
      );
      return _apiService.parsePage<FaceAuthRecordModel>(
          response, (e) => FaceAuthRecordModel.fromJson(e));
    } catch (e) {
      _logger.e('获取服务器认证记录分页列表失败: $e');
      rethrow;
    }
  }
}
