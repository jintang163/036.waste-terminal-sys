import 'package:logger/logger.dart';

import '../config/app_constants.dart';
import '../db/user_face_db.dart';
import '../models/user_face_model.dart';
import '../models/page_result.dart';
import 'api_service.dart';

class UserFaceService {
  static final UserFaceService _instance = UserFaceService._internal();
  factory UserFaceService() => _instance;

  final ApiService _apiService = ApiService();
  final UserFaceDb _userFaceDb = UserFaceDb();
  final Logger _logger = Logger();

  UserFaceService._internal();

  Future<List<UserFaceModel>> getFaceList() async {
    try {
      return await _userFaceDb.queryAllModels();
    } catch (e) {
      _logger.e('获取本地人脸列表失败: $e');
      rethrow;
    }
  }

  Future<List<UserFaceModel>> getEnabledFaceList() async {
    try {
      return await _userFaceDb.queryEnabledModels();
    } catch (e) {
      _logger.e('获取启用的人脸列表失败: $e');
      rethrow;
    }
  }

  Future<UserFaceModel?> getByUserId(int userId) async {
    try {
      return await _userFaceDb.queryModelByUserId(userId);
    } catch (e) {
      _logger.e('根据用户ID获取人脸失败: $e');
      return null;
    }
  }

  Future<UserFaceModel?> getByUsername(String username) async {
    try {
      return await _userFaceDb.queryModelByUsername(username);
    } catch (e) {
      _logger.e('根据用户名获取人脸失败: $e');
      return null;
    }
  }

  Future<UserFaceModel?> getByFaceId(String faceId) async {
    try {
      return await _userFaceDb.queryModelByFaceId(faceId);
    } catch (e) {
      _logger.e('根据faceId获取人脸失败: $e');
      return null;
    }
  }

  Future<int> saveFace(UserFaceModel face) async {
    try {
      return await _userFaceDb.insertUserFace(face);
    } catch (e) {
      _logger.e('保存人脸信息失败: $e');
      rethrow;
    }
  }

  Future<void> batchSaveFace(List<UserFaceModel> faceList) async {
    try {
      await _userFaceDb.batchInsert(faceList.map((e) => e.toDbMap()).toList());
    } catch (e) {
      _logger.e('批量保存人脸信息失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAllFace(List<UserFaceModel> faceList) async {
    try {
      await _userFaceDb.replaceAll(faceList.map((e) => e.toDbMap()).toList());
    } catch (e) {
      _logger.e('替换人脸信息失败: $e');
      rethrow;
    }
  }

  Future<bool> syncFaceToServer(UserFaceModel face) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，暂不同步人脸信息');
        return false;
      }
      final response = await _apiService.post(
        AppConstants.userFaceSync,
        data: face.toJson(),
      );
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('同步人脸信息到服务器失败: $e');
      return false;
    }
  }

  Future<bool> pullFaceFromServer() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，暂不同步人脸信息');
        return false;
      }
      final response = await _apiService.get(AppConstants.userFaceList);
      final list = _apiService.parseList<UserFaceModel>(
          response, (e) => UserFaceModel.fromJson(e));
      await replaceAllFace(list);
      _logger.d('从服务器拉取人脸信息成功，数量: ${list.length}');
      return true;
    } catch (e) {
      _logger.e('从服务器拉取人脸信息失败: $e');
      return false;
    }
  }

  Future<PageResult<UserFaceModel>> getServerFacePage({
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiService.get(
        AppConstants.userFacePage,
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
        },
      );
      return _apiService.parsePage<UserFaceModel>(
          response, (e) => UserFaceModel.fromJson(e));
    } catch (e) {
      _logger.e('获取服务器人脸分页列表失败: $e');
      rethrow;
    }
  }
}
