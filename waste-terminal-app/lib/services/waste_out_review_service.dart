import 'dart:convert';
import 'package:logger/logger.dart';

import '../config/app_constants.dart';
import '../models/waste_out_review.dart';
import '../db/waste_out_review_db.dart';
import 'api_service.dart';
import 'operation_log_service.dart';
import 'package:uuid/uuid.dart';

class WasteOutReviewService {
  final Logger _logger = Logger();
  final WasteOutReviewDb _reviewDb = WasteOutReviewDb();
  final ApiService _apiService = ApiService();
  final Uuid _uuid = const Uuid();

  static final WasteOutReviewService _instance = WasteOutReviewService._internal();
  factory WasteOutReviewService() => _instance;
  WasteOutReviewService._internal();

  Future<Map<String, dynamic>> createReview({
    required int outRecordId,
    required String outNo,
    String? reviewQrCode,
    String? offlineId,
  }) async {
    final appProvider = await _apiService.getCurrentAppProvider();
    final userId = appProvider?.userInfo?['id'];
    final username = appProvider?.username;
    final enterpriseId = appProvider?.enterpriseInfo?['id'];

    final reviewOfflineId = offlineId ?? _uuid.v4();
    final reviewNo = 'WR${DateTime.now().millisecondsSinceEpoch}';

    final review = WasteOutReview(
      reviewNo: reviewNo,
      outRecordId: outRecordId,
      outNo: outNo,
      operatorId: userId,
      operatorName: username,
      reviewQrCode: reviewQrCode,
      syncStatus: 0,
      offlineId: reviewOfflineId,
      enterpriseId: enterpriseId,
    );

    final dbId = await _reviewDb.insert(review.toDbMap());

    try {
      await OperationLogService().logInfo(
        '创建出库复核记录',
        category: BusinessConstants.logCategoryOperation,
        module: 'waste_out_review',
        action: 'create',
        extra: {
          'outNo': outNo,
          'reviewNo': reviewNo,
        },
      );
    } catch (_) {}

    final hasNetwork = await _apiService.isNetworkAvailable();
    if (hasNetwork) {
      try {
        final payload = {
          'reviewNo': reviewNo,
          'outRecordId': outRecordId,
          'outNo': outNo,
          'operatorId': userId,
          'operatorName': username,
          'reviewQrCode': reviewQrCode,
          'offlineId': reviewOfflineId,
        };
        final response = await _apiService.post(
          ApiConstants.wasteOutReviewCreate,
          data: payload,
        );
        if (response != null && response['code'] == 200) {
          await _reviewDb.updateSyncStatus(dbId, 2);
          final result = Map<String, dynamic>.from(response['data'] as Map? ?? {});
          result['id'] = dbId;
          result['reviewNo'] = reviewNo;
          result['offlineId'] = reviewOfflineId;
          return result;
        }
      } catch (e) {
        _logger.w('同步创建复核记录到后端失败，将在下次同步时重试: $e');
      }
    }

    return {
      'needReview': true,
      'id': dbId,
      'reviewNo': reviewNo,
      'reviewQrCode': reviewQrCode,
      'offlineId': reviewOfflineId,
      'message': '复核创建成功，请通知复核员扫码确认',
    };
  }

  Future<Map<String, dynamic>> confirmReview({
    required String reviewNo,
    required int reviewResult,
    required String reviewerName,
    String? reviewRemark,
    String? reviewerFaceAuthId,
    String? reviewerFaceId,
    List<int>? reviewerFaceImage,
  }) async {
    final appProvider = await _apiService.getCurrentAppProvider();
    final reviewerId = appProvider?.userInfo?['id'];
    final reviewerNameActual = appProvider?.username ?? reviewerName;
    final enterpriseId = appProvider?.enterpriseInfo?['id'];

    final existingReview = await _reviewDb.getByReviewNo(reviewNo);
    if (existingReview == null) {
      throw Exception('复核记录不存在');
    }

    if (existingReview['operator_id'] == reviewerId) {
      throw Exception('操作员和复核员不能为同一人');
    }

    if (existingReview['review_result'] != null) {
      throw Exception('该复核已处理，请勿重复操作');
    }

    final updateData = {
      'reviewer_id': reviewerId,
      'reviewer_name': reviewerNameActual,
      'review_result': reviewResult,
      'review_time': DateTime.now().toIso8601String(),
      'review_remark': reviewRemark,
      'reviewer_face_auth_id': reviewerFaceAuthId,
      'reviewer_face_id': reviewerFaceId,
      'reviewer_face_image': reviewerFaceImage != null ? base64Encode(reviewerFaceImage) : null,
      'sync_status': 0,
      'update_time': DateTime.now().toIso8601String(),
    };

    await _reviewDb.update(existingReview['id'] as int, updateData);

    try {
      await OperationLogService().logInfo(
        reviewResult == 1 ? '出库复核通过' : '出库复核拒绝',
        category: BusinessConstants.logCategoryOperation,
        module: 'waste_out_review',
        action: 'confirm',
        extra: {
          'reviewNo': reviewNo,
          'reviewResult': reviewResult == 1 ? '通过' : '拒绝',
          'reviewer': reviewerNameActual,
        },
      );
    } catch (_) {}

    final hasNetwork = await _apiService.isNetworkAvailable();
    if (hasNetwork) {
      try {
        final payload = {
          'reviewerId': reviewerId,
          'reviewerName': reviewerNameActual,
          'reviewResult': reviewResult,
          'reviewRemark': reviewRemark,
          'reviewerFaceAuthId': reviewerFaceAuthId,
          'reviewerFaceId': reviewerFaceId,
          'reviewerFaceImage': reviewerFaceImage != null ? base64Encode(reviewerFaceImage) : null,
        };
        final response = await _apiService.post(
          '${ApiConstants.wasteOutReviewConfirm}/$reviewNo',
          data: payload,
        );
        if (response != null && response['code'] == 200) {
          await _reviewDb.updateSyncStatus(existingReview['id'] as int, 2);
        }
      } catch (e) {
        _logger.w('同步复核结果到后端失败，将在下次同步时重试: $e');
      }
    }

    return {
      'success': true,
      'reviewResult': reviewResult == 1 ? '通过' : '拒绝',
      'message': reviewResult == 1 ? '复核通过，出库已完成' : '复核已拒绝',
    };
  }

  Future<WasteOutReview?> getByReviewNo(String reviewNo) async {
    final hasNetwork = await _apiService.isNetworkAvailable();
    if (hasNetwork) {
      try {
        final response = await _apiService.get(
          '${ApiConstants.wasteOutReviewGetByNo}/$reviewNo',
        );
        if (response != null && response['code'] == 200) {
          final data = response['data'];
          if (data != null) {
            return WasteOutReview.fromJson(Map<String, dynamic>.from(data as Map));
          }
        }
      } catch (e) {
        _logger.w('从后端获取复核记录失败，尝试本地查询: $e');
      }
    }

    final localData = await _reviewDb.getByReviewNo(reviewNo);
    if (localData != null) {
      return WasteOutReview.fromDbMap(localData);
    }
    return null;
  }

  Future<WasteOutReview?> getByOutNo(String outNo) async {
    final hasNetwork = await _apiService.isNetworkAvailable();
    if (hasNetwork) {
      try {
        final response = await _apiService.get(
          '${ApiConstants.wasteOutReviewGetByOutNo}/$outNo',
        );
        if (response != null && response['code'] == 200) {
          final data = response['data'];
          if (data != null) {
            return WasteOutReview.fromJson(Map<String, dynamic>.from(data as Map));
          }
        }
      } catch (e) {
        _logger.w('从后端获取复核记录失败，尝试本地查询: $e');
      }
    }

    final localData = await _reviewDb.getByOutNo(outNo);
    if (localData != null) {
      return WasteOutReview.fromDbMap(localData);
    }
    return null;
  }

  Future<bool> checkDoubleReviewRequired(int wasteId) async {
    final hasNetwork = await _apiService.isNetworkAvailable();
    if (hasNetwork) {
      try {
        final response = await _apiService.get(
          ApiConstants.wasteOutCheckDoubleReview,
          queryParameters: {'wasteId': wasteId},
        );
        if (response != null && response['code'] == 200) {
          final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
          return data['required'] as bool? ?? false;
        }
      } catch (e) {
        _logger.w('检查是否需要双人复核失败: $e');
      }
    }
    return false;
  }

  Future<void> syncPendingReviews() async {
    try {
      final pendingList = await _reviewDb.getPendingSyncList();
      if (pendingList.isEmpty) {
        return;
      }

      final payload = pendingList.map((e) => WasteOutReview.fromDbMap(e).toJson()).toList();
      final response = await _apiService.post(
        ApiConstants.wasteOutReviewBatchSync,
        data: payload,
      );

      if (response != null && response['code'] == 200) {
        for (var item in pendingList) {
          await _reviewDb.updateSyncStatus(item['id'] as int, 2);
        }
        _logger.i('批量同步出库复核记录成功，数量: ${pendingList.length}');
      }
    } catch (e) {
      _logger.e('批量同步出库复核记录失败: $e');
    }
  }
}
