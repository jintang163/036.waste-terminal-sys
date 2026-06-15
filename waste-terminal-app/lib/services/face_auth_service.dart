import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import '../models/user_face_model.dart';
import '../models/face_auth_record_model.dart';
import 'user_face_service.dart';
import 'face_auth_record_service.dart';
import 'face_detection_service.dart';

class FaceAuthResult {
  final bool success;
  final double similarity;
  final UserFaceModel? userFace;
  final String? authId;
  final String? error;
  final Uint8List? capturedImage;
  final double? livenessScore;
  final int? faceQuality;

  FaceAuthResult({
    required this.success,
    required this.similarity,
    this.userFace,
    this.authId,
    this.error,
    this.capturedImage,
    this.livenessScore,
    this.faceQuality,
  });

  String get similarityText => '${(similarity * 100).toStringAsFixed(1)}%';

  bool get hasError => error != null;
}

class FaceAuthService {
  static final FaceAuthService._internal();
  factory FaceAuthService() => _instance;

  final UserFaceService userFaceService = UserFaceService();
  final FaceAuthRecordService faceAuthRecordService = FaceAuthRecordService();
  final FaceDetectionService _detectionService = FaceDetectionService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const double _similarityThreshold = 0.85;
  static const int _featureVectorSize = 128;
  static const int _enrollMinQuality = 60;
  static const double _minLivenessThreshold = 0.7;

  FaceAuthService._internal();

  double get threshold => _similarityThreshold;
  double get livenessThreshold => _minLivenessThreshold;
  int get featureSize => _featureVectorSize;
  int get minEnrollQuality => _enrollMinQuality;

  Future<UserFaceModel?> enrollFace({
    required int userId,
    required String username,
    required Uint8List faceImage,
    String? faceImagePath,
    int? enterpriseId,
    String? deviceId,
  }) async {
    try {
      final detectResult = await _detectionService.detectAndExtract(
        imageBytes: faceImage,
        requireLiveness: true,
        minQuality: _enrollMinQuality,
      );

      if (!detectResult.success) {
        throw Exception(detectResult.error ?? '人脸检测失败');
      }

      List<double> features = detectResult.faceFeatures ??
          _detectionService.extractFaceFeatures(faceImage);
      Uint8List? croppedImage =
          detectResult.croppedFaceImage ?? faceImage;

      String featureStr = encodeFeatures(features);
      String faceId = _uuid.v4().replaceAll('-', '');

      UserFaceModel face = UserFaceModel(
        userId: userId,
        username: username,
        faceId: faceId,
        faceFeature: featureStr,
        faceImage: faceImagePath,
        status: 1,
        enrollQuality: detectResult.faceQuality,
        deviceId: deviceId,
        enterpriseId: enterpriseId,
        createTime: DateTime.now(),
        updateTime: DateTime.now(),
      );

      int id = await userFaceService.saveFace(face);
      face = face.copyWith(id: id);

      await userFaceService.syncFaceToServer(face);

      _logger.i(
          '人脸录入成功，faceId: $faceId, 质量分: ${detectResult.faceQuality}, 活体分: ${(detectResult.livenessScore * 100).toInt()}%');
      return face;
    } catch (e) {
      _logger.e('人脸录入失败: $e');
      rethrow;
    }
  }

  Future<FaceAuthResult> verifyFace({
    required Uint8List faceImage,
    String authType = 'verify',
    String? businessType,
    String? businessId,
    String? businessNo,
    String? deviceId,
    int? enterpriseId,
    bool requireLiveness = true,
  }) async {
    try {
      final detectResult = await _detectionService.detectAndExtract(
        imageBytes: faceImage,
        requireLiveness: requireLiveness,
        minQuality: 50,
      );

      if (!detectResult.success) {
        return FaceAuthResult(
          success: false,
          similarity: 0.0,
          error: detectResult.error,
          livenessScore: detectResult.livenessScore,
          faceQuality: detectResult.faceQuality,
        );
      }

      List<double> probeFeatures = detectResult.faceFeatures ??
          _detectionService.extractFaceFeatures(faceImage);
      List<UserFaceModel> allFaces = await userFaceService.getEnabledFaceList();

      double bestSimilarity = 0.0;
      UserFaceModel? bestMatch;

      for (var face in allFaces) {
        if (face.faceFeature == null || face.faceFeature!.isEmpty) continue;
        List<double> enrolledFeatures = decodeFeatures(face.faceFeature!);
        double sim = calculateSimilarity(probeFeatures, enrolledFeatures);
        if (sim > bestSimilarity) {
          bestSimilarity = sim;
          bestMatch = face;
        }
      }

      bool isSuccess =
          bestSimilarity >= _similarityThreshold && bestMatch != null;

      String authId = _uuid.v4().replaceAll('-', '');

      FaceAuthRecordModel record = FaceAuthRecordModel(
        authId: authId,
        userId: bestMatch?.userId,
        username: bestMatch?.username,
        realName: bestMatch?.username,
        faceId: bestMatch?.faceId,
        similarity: bestSimilarity,
        authStatus: isSuccess ? 1 : 0,
        authType: authType,
        businessType: businessType,
        businessId: businessId,
        businessNo: businessNo,
        deviceId: deviceId,
        authTime: DateTime.now(),
        enterpriseId: enterpriseId,
        livenessScore: detectResult.livenessScore,
        faceQuality: detectResult.faceQuality,
      );

      await faceAuthRecordService.saveAuthRecord(record);

      _logger.i(
          '人脸认证完成，结果: ${isSuccess ? "成功" : "失败"}, 相似度: ${(bestSimilarity * 100).toStringAsFixed(1)}%, 用户: ${bestMatch?.username ?? "未知"}, 活体: ${(detectResult.livenessScore * 100).toInt()}%');

      return FaceAuthResult(
        success: isSuccess,
        similarity: bestSimilarity,
        userFace: bestMatch,
        authId: authId,
        capturedImage: detectResult.croppedFaceImage ?? faceImage,
        livenessScore: detectResult.livenessScore,
        faceQuality: detectResult.faceQuality,
      );
    } catch (e) {
      _logger.e('人脸认证失败: $e');
      return FaceAuthResult(
        success: false,
        similarity: 0.0,
        userFace: null,
        authId: null,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<FaceAuthResult> verifyFaceForUser({
    required String username,
    required Uint8List faceImage,
    String authType = 'verify',
    String? businessType,
    String? businessId,
    String? businessNo,
    String? deviceId,
    int? enterpriseId,
    bool requireLiveness = true,
  }) async {
    try {
      final detectResult = await _detectionService.detectAndExtract(
        imageBytes: faceImage,
        requireLiveness: requireLiveness,
        minQuality: 50,
      );

      if (!detectResult.success) {
        return FaceAuthResult(
          success: false,
          similarity: 0.0,
          error: detectResult.error,
          livenessScore: detectResult.livenessScore,
          faceQuality: detectResult.faceQuality,
        );
      }

      UserFaceModel? userFace = await userFaceService.getByUsername(username);
      if (userFace == null ||
          userFace.faceFeature == null ||
          userFace.faceFeature!.isEmpty) {
        throw Exception('用户尚未录入人脸信息');
      }

      List<double> probeFeatures = detectResult.faceFeatures ??
          _detectionService.extractFaceFeatures(faceImage);
      List<double> enrolledFeatures = decodeFeatures(userFace.faceFeature!);
      double similarity = calculateSimilarity(probeFeatures, enrolledFeatures);
      bool isSuccess = similarity >= _similarityThreshold;

      String authId = _uuid.v4().replaceAll('-', '');

      FaceAuthRecordModel record = FaceAuthRecordModel(
        authId: authId,
        userId: userFace.userId,
        username: userFace.username,
        realName: userFace.username,
        faceId: userFace.faceId,
        similarity: similarity,
        authStatus: isSuccess ? 1 : 0,
        authType: authType,
        businessType: businessType,
        businessId: businessId,
        businessNo: businessNo,
        deviceId: deviceId,
        authTime: DateTime.now(),
        enterpriseId: enterpriseId,
        livenessScore: detectResult.livenessScore,
        faceQuality: detectResult.faceQuality,
      );

      await faceAuthRecordService.saveAuthRecord(record);

      _logger.i(
          '指定用户人脸认证完成，用户: $username, 结果: ${isSuccess ? "成功" : "失败"}, 相似度: ${(similarity * 100).toStringAsFixed(1)}%, 活体: ${(detectResult.livenessScore * 100).toInt()}%');

      return FaceAuthResult(
        success: isSuccess,
        similarity: similarity,
        userFace: userFace,
        authId: authId,
        capturedImage: detectResult.croppedFaceImage ?? faceImage,
        livenessScore: detectResult.livenessScore,
        faceQuality: detectResult.faceQuality,
      );
    } catch (e) {
      _logger.e('指定用户人脸认证失败: $e');
      return FaceAuthResult(
        success: false,
        similarity: 0.0,
        userFace: null,
        authId: null,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> hasEnrolledFace(String username) async {
    try {
      UserFaceModel? face = await userFaceService.getByUsername(username);
      return face != null &&
          face.isEnabled && (face.faceFeature?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFace(String faceId) async {
    try {
      await userFaceService.saveFace(UserFaceModel(faceId: faceId, status: 0));
      return true;
    } catch (e) {
      _logger.e('删除人脸失败: $e');
      return false;
    }
  }

  List<double> extractFaceFeatures(Uint8List imageBytes) {
    return _detectionService.extractFaceFeatures(imageBytes);
  }

  int calculateQuality(Uint8List imageBytes) {
    return _detectionService.calculateQuality(imageBytes);
  }

  double calculateSimilarity(List<double> features1, List<double> features2) {
    if (features1.length != features2.length) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < features1.length; i++) {
      dotProduct += features1[i] * features2[i];
      norm1 += features1[i] * features1[i];
      norm2 += features2[i] * features2[i];
    }

    if (norm1 == 0 || norm2 == 0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  String encodeFeatures(List<double> features) {
    return base64Encode(
        Float64List.fromList(features).buffer.asUint8List());
  }

  List<double> decodeFeatures(String encoded) {
    try {
      Uint8List bytes = base64Decode(encoded);
      return Float64List.view(bytes.buffer).toList();
    } catch (e) {
      _logger.e('解码特征数据失败: $e');
      return List.generate(_featureVectorSize, (_) => 0.0);
    }
  }
}
