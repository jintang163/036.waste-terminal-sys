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

class FaceAuthService {
  static final FaceAuthService _instance = FaceAuthService._internal();
  factory FaceAuthService() => _instance;

  final UserFaceService userFaceService = UserFaceService();
  final FaceAuthRecordService faceAuthRecordService = FaceAuthRecordService();
  final Logger _logger = Logger();
  final Uuid _uuid = Uuid();

  static const double _similarityThreshold = 0.85;
  static const int _featureVectorSize = 128;
  static const int _enrollMinQuality = 50;

  FaceAuthService._internal();

  List<double> extractFaceFeatures(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return List.generate(_featureVectorSize, (_) => 0.0);
      }

      img.Image gray = img.grayscale(image);
      img.Image resized = img.copyResize(gray, width: 64, height: 64);

      List<double> features = List.generate(_featureVectorSize, (_) => 0.0);
      int gridSize = 8;
      int cellSize = 8;

      for (int gy = 0; gy < gridSize; gy++) {
        for (int gx = 0; gx < gridSize; gx++) {
          double sum = 0.0;
          double sumSq = 0.0;

          for (int cy = 0; cy < cellSize; cy++) {
            for (int cx = 0; cx < cellSize; cx++) {
              int px = gx * cellSize + cx;
              int py = gy * cellSize + cy;
              int pixel = resized.getPixel(px, py);
              double brightness = (pixel & 0xFF) / 255.0;
              sum += brightness;
              sumSq += brightness * brightness;
            }
          }

          int idx = (gy * gridSize + gx) * 2;
          features[idx] = sum / (cellSize * cellSize);
          features[idx + 1] = sqrt(max(0.0, sumSq / (cellSize * cellSize) - features[idx] * features[idx]));
        }
      }

      double mean = features.reduce((a, b) => a + b) / features.length;
      double variance = features.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / features.length;
      double std = sqrt(variance);

      if (std > 0) {
        features = features.map((v) => (v - mean) / std).toList();
      }

      return features;
    } catch (e) {
      _logger.e('提取人脸特征失败: $e');
      return List.generate(_featureVectorSize, (_) => 0.0);
    }
  }

  int calculateQuality(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return 0;

      double brightnessSum = 0.0;
      double contrastSum = 0.0;
      int count = 0;

      for (int y = 0; y < image.height; y += 4) {
        for (int x = 0; x < image.width; x += 4) {
          int pixel = image.getPixel(x, y);
          double r = ((pixel >> 16) & 0xFF) / 255.0;
          double g = ((pixel >> 8) & 0xFF) / 255.0;
          double b = (pixel & 0xFF) / 255.0;
          double lum = 0.299 * r + 0.587 * g + 0.114 * b;
          brightnessSum += lum;
          count++;
        }
      }

      double avgBrightness = brightnessSum / count;
      double brightnessScore = 1 - (avgBrightness - 0.5).abs() * 2;
      brightnessScore = brightnessScore.clamp(0.0, 1.0);

      for (int y = 0; y < image.height - 4; y += 4) {
        for (int x = 0; x < image.width - 4; x += 4) {
          int p1 = image.getPixel(x, y);
          int p2 = image.getPixel(x + 4, y);
          double l1 = ((p1 & 0xFF)) / 255.0;
          double l2 = ((p2 & 0xFF)) / 255.0;
          contrastSum += (l1 - l2).abs();
        }
      }

      double avgContrast = contrastSum / count;
      double contrastScore = (avgContrast * 5).clamp(0.0, 1.0);

      double resolutionScore = ((image.width * image.height) / (1024 * 1024)).clamp(0.0, 1.0);

      double quality = (brightnessScore * 0.3 + contrastScore * 0.4 + resolutionScore * 0.3) * 100;
      return quality.round().clamp(0, 100);
    } catch (e) {
      _logger.e('计算图像质量失败: $e');
      return 0;
    }
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
    return base64Encode(Float64List.fromList(features).buffer.asUint8List());
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

  Future<UserFaceModel?> enrollFace({
    required int userId,
    required String username,
    required Uint8List faceImage,
    String? faceImagePath,
    int? enterpriseId,
    String? deviceId,
  }) async {
    try {
      int quality = calculateQuality(faceImage);
      if (quality < _enrollMinQuality) {
        throw Exception('人脸图像质量不足，请确保光线充足且面部清晰 (质量分: $quality)');
      }

      List<double> features = extractFaceFeatures(faceImage);
      String featureStr = encodeFeatures(features);
      String faceId = _uuid.v4().replaceAll('-', '');

      UserFaceModel face = UserFaceModel(
        userId: userId,
        username: username,
        faceId: faceId,
        faceFeature: featureStr,
        faceImage: faceImagePath,
        status: 1,
        enrollQuality: quality,
        deviceId: deviceId,
        enterpriseId: enterpriseId,
        createTime: DateTime.now(),
        updateTime: DateTime.now(),
      );

      int id = await userFaceService.saveFace(face);
      face = face.copyWith(id: id);

      await userFaceService.syncFaceToServer(face);

      _logger.i('人脸录入成功，faceId: $faceId, 质量分: $quality');
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
  }) async {
    try {
      List<double> probeFeatures = extractFaceFeatures(faceImage);
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

      bool isSuccess = bestSimilarity >= _similarityThreshold && bestMatch != null;

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
      );

      await faceAuthRecordService.saveAuthRecord(record);

      _logger.i(
          '人脸认证完成，结果: ${isSuccess ? "成功" : "失败"}, 相似度: ${(bestSimilarity * 100).toStringAsFixed(1)}%, 用户: ${bestMatch?.username ?? "未知"}');

      return FaceAuthResult(
        success: isSuccess,
        similarity: bestSimilarity,
        userFace: bestMatch,
        authId: authId,
        capturedImage: faceImage,
      );
    } catch (e) {
      _logger.e('人脸认证失败: $e');
      return FaceAuthResult(
        success: false,
        similarity: 0.0,
        userFace: null,
        authId: null,
        error: e.toString(),
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
  }) async {
    try {
      UserFaceModel? userFace = await userFaceService.getByUsername(username);
      if (userFace == null || userFace.faceFeature == null || userFace.faceFeature!.isEmpty) {
        throw Exception('用户尚未录入人脸信息');
      }

      List<double> probeFeatures = extractFaceFeatures(faceImage);
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
      );

      await faceAuthRecordService.saveAuthRecord(record);

      _logger.i(
          '指定用户人脸认证完成，用户: $username, 结果: ${isSuccess ? "成功" : "失败"}, 相似度: ${(similarity * 100).toStringAsFixed(1)}%');

      return FaceAuthResult(
        success: isSuccess,
        similarity: similarity,
        userFace: userFace,
        authId: authId,
        capturedImage: faceImage,
      );
    } catch (e) {
      _logger.e('指定用户人脸认证失败: $e');
      return FaceAuthResult(
        success: false,
        similarity: 0.0,
        userFace: null,
        authId: null,
        error: e.toString(),
      );
    }
  }

  Future<bool> hasEnrolledFace(String username) async {
    try {
      UserFaceModel? face = await userFaceService.getByUsername(username);
      return face != null && face.isEnabled && (face.faceFeature?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFace(String faceId) async {
    try {
      await userFaceService.saveFace(UserFaceModel(faceId: faceId, status: 0));
      return true;
    } catch (e) {
      _logger.e('删除人脸信息失败: $e');
      return false;
    }
  }

  double get threshold => _similarityThreshold;
  int get featureSize => _featureVectorSize;
  int get minEnrollQuality => _enrollMinQuality;
}

class FaceAuthResult {
  final bool success;
  final double similarity;
  final UserFaceModel? userFace;
  final String? authId;
  final String? error;
  final Uint8List? capturedImage;

  FaceAuthResult({
    required this.success,
    required this.similarity,
    this.userFace,
    this.authId,
    this.error,
    this.capturedImage,
  });

  String get similarityText => '${(similarity * 100).toStringAsFixed(1)}%';

  bool get hasError => error != null;
}
