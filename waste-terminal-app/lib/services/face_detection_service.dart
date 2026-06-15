import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

class FaceDetectionResult {
  final bool success;
  final Face? face;
  final List<Face> allFaces;
  final double livenessScore;
  final int faceQuality;
  final String? error;
  final Uint8List? croppedFaceImage;
  final List<double>? faceFeatures;

  FaceDetectionResult({
    required this.success,
    this.face,
    this.allFaces = const [],
    this.livenessScore = 0.0,
    this.faceQuality = 0,
    this.error,
    this.croppedFaceImage,
    this.faceFeatures,
  });

  bool get isLive => livenessScore >= 0.7;
  bool get hasValidFace => face != null && allFaces.length == 1;
}

class FaceDetectionService {
  static final FaceDetectionService _instance = FaceDetectionService._internal();
  factory FaceDetectionService() => _instance;

  final Logger _logger = Logger();
  late final FaceDetector _faceDetector;
  bool _isInitialized = false;

  static const double _minFaceSizeRatio = 0.15;
  static const double _maxFaceSizeRatio = 0.85;
  static const double _minEyeOpenProb = 0.5;
  static const int _featureVectorSize = 128;

  FaceDetectionService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: false,
          minFaceSize: _minFaceSizeRatio,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      _isInitialized = true;
      _logger.i('ML Kit 人脸检测引擎初始化成功');
    } catch (e) {
      _logger.e('ML Kit 人脸检测引擎初始化失败: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _faceDetector.close();
      _isInitialized = false;
      _logger.i('ML Kit 人脸检测引擎已释放');
    }
  }

  Future<FaceDetectionResult> detectAndExtract({
    required Uint8List imageBytes,
    bool requireLiveness = true,
    int minQuality = 60,
  }) async {
    try {
      await initialize();

      img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        return FaceDetectionResult(
          success: false,
          error: '无法解码图片',
        );
      }

      final inputImage = _convertToInputImage(decodedImage, imageBytes);

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceDetectionResult(
          success: false,
          allFaces: faces,
          error: '未检测到人脸，请正对摄像头',
        );
      }

      if (faces.length > 1) {
        return FaceDetectionResult(
          success: false,
          allFaces: faces,
          error: '检测到多张人脸，请确保画面中只有一人',
        );
      }

      final Face face = faces.first;

      double livenessScore = _calculateLivenessScore(face, decodedImage);
      if (requireLiveness && livenessScore < 0.7) {
        return FaceDetectionResult(
          success: false,
          face: face,
          allFaces: faces,
          livenessScore: livenessScore,
          error: '活体检测未通过，请确保是真人操作 (${(livenessScore * 100).toInt()}%)',
        );
      }

      int quality = _calculateFaceQuality(face, decodedImage);
      if (quality < minQuality) {
        return FaceDetectionResult(
          success: false,
          face: face,
          allFaces: faces,
          livenessScore: livenessScore,
          faceQuality: quality,
          error: '人脸质量不足，请调整光线和角度 (质量分: $quality)',
        );
      }

      Uint8List croppedFace = _cropFace(decodedImage, face);

      List<double> features = _extractFaceFeaturesFromCropped(croppedFace);

      return FaceDetectionResult(
        success: true,
        face: face,
        allFaces: faces,
        livenessScore: livenessScore,
        faceQuality: quality,
        croppedFaceImage: croppedFace,
        faceFeatures: features,
      );
    } catch (e) {
      _logger.e('人脸检测失败: $e');
      return FaceDetectionResult(
        success: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  InputImage _convertToInputImage(img.Image image, Uint8List rawBytes) {
    final bytes = rawBytes;
    final inputImageData = InputImageData(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      imageRotation: InputImageRotation.rotation0deg,
      inputImageFormat: InputImageFormat.nv21,
      planeData: [
        InputImagePlaneMetadata(
          bytesPerRow: image.width,
          height: image.height,
          width: image.width,
        ),
      ],
    );

    return InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImageData,
    );
  }

  double _calculateLivenessScore(Face face, img.Image image) {
    double score = 0.0;
    int weightSum = 0;

    double? leftEyeOpen = face.leftEyeOpenProbability;
    double? rightEyeOpen = face.rightEyeOpenProbability;
    if (leftEyeOpen != null && rightEyeOpen != null) {
      double eyeScore = (leftEyeOpen + rightEyeOpen) / 2;
      if (eyeScore > _minEyeOpenProb) {
        score += eyeScore * 25;
        weightSum += 25;
      }
    }

    double? smilingProb = face.smilingProbability;
    if (smilingProb != null) {
      double smileScore = 0.3 + 0.7 * smilingProb;
      score += smileScore * 20;
      weightSum += 20;
    }

    double headEulerAngleY = face.headEulerAngleY ?? 0;
    double yawScore = 1 - (headEulerAngleY.abs() / 30.0).clamp(0.0, 1.0);
    score += yawScore * 20;
    weightSum += 20;

    double headEulerAngleX = face.headEulerAngleX ?? 0;
    double pitchScore = 1 - (headEulerAngleX.abs() / 25.0).clamp(0.0, 1.0);
    score += pitchScore * 15;
    weightSum += 15;

    double headEulerAngleZ = face.headEulerAngleZ ?? 0;
    double rollScore = 1 - (headEulerAngleZ.abs() / 20.0).clamp(0.0, 1.0);
    score += rollScore * 10;
    weightSum += 10;

    if (face.contours[FaceContourType.face] != null) {
      final contour = face.contours[FaceContourType.face]!.points;
      if (contour.length >= 8) {
        score += 10;
        weightSum += 10;
      }
    }

    if (weightSum > 0) {
      return score / weightSum;
    }
    return 0.5;
  }

  int _calculateFaceQuality(Face face, img.Image image) {
    double brightnessScore = _calculateBrightnessScore(image, face.boundingBox);
    double contrastScore = _calculateContrastScore(image, face.boundingBox);
    double blurScore = _calculateBlurScore(image, face.boundingBox);
    double sizeScore = _calculateFaceSizeScore(face, image);
    double poseScore = _calculatePoseScore(face);

    double quality = (brightnessScore * 0.25 +
            contrastScore * 0.25 +
            blurScore * 0.2 +
            sizeScore * 0.15 +
            poseScore * 0.15) *
        100;

    return quality.round().clamp(0, 100);
  }

  double _calculateBrightnessScore(img.Image image, Rect bbox) {
    int startX = bbox.left.toInt().clamp(0, image.width - 1);
    int startY = bbox.top.toInt().clamp(0, image.height - 1);
    int endX = bbox.right.toInt().clamp(0, image.width);
    int endY = bbox.bottom.toInt().clamp(0, image.height);

    double sumLum = 0;
    int count = 0;

    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        int pixel = image.getPixel(x, y);
        double r = ((pixel >> 16) & 0xFF) / 255.0;
        double g = ((pixel >> 8) & 0xFF) / 255.0;
        double b = (pixel & 0xFF) / 255.0;
        sumLum += 0.299 * r + 0.587 * g + 0.114 * b;
        count++;
      }
    }

    double avgLum = count > 0 ? sumLum / count : 0.5;
    return 1 - (avgLum - 0.5).abs() * 2;
  }

  double _calculateContrastScore(img.Image image, Rect bbox) {
    int startX = bbox.left.toInt().clamp(0, image.width - 1);
    int startY = bbox.top.toInt().clamp(0, image.height - 1);
    int endX = bbox.right.toInt().clamp(0, image.width);
    int endY = bbox.bottom.toInt().clamp(0, image.height);

    List<double> lums = [];

    for (int y = startY; y < endY; y += 8) {
      for (int x = startX; x < endX; x += 8) {
        int pixel = image.getPixel(x, y);
        double lum = (pixel & 0xFF) / 255.0;
        lums.add(lum);
      }
    }

    if (lums.length < 2) return 0.5;

    double mean = lums.reduce((a, b) => a + b) / lums.length;
    double variance =
        lums.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            lums.length;
    double stdDev = sqrt(variance);

    return (stdDev * 4).clamp(0.0, 1.0);
  }

  double _calculateBlurScore(img.Image image, Rect bbox) {
    int startX = bbox.left.toInt().clamp(0, image.width - 1);
    int startY = bbox.top.toInt().clamp(0, image.height - 1);
    int endX = bbox.right.toInt().clamp(0, image.width);
    int endY = bbox.bottom.toInt().clamp(0, image.height);

    double totalGradient = 0;
    int count = 0;

    for (int y = startY; y < endY - 2; y += 4) {
      for (int x = startX; x < endX - 2; x += 4) {
        int p1 = image.getPixel(x, y) & 0xFF;
        int p2 = image.getPixel(x + 2, y) & 0xFF;
        int p3 = image.getPixel(x, y + 2) & 0xFF;
        totalGradient += (p1 - p2).abs() + (p1 - p3).abs();
        count += 2;
      }
    }

    double avgGradient = count > 0 ? totalGradient / count : 0;
    return (avgGradient / 30).clamp(0.0, 1.0);
  }

  double _calculateFaceSizeScore(Face face, img.Image image) {
    double faceWidth = face.boundingBox.width;
    double faceHeight = face.boundingBox.height;
    double faceArea = faceWidth * faceHeight;
    double imageArea = image.width * image.height;
    double ratio = faceArea / imageArea;

    if (ratio >= 0.25 && ratio <= 0.6) {
      return 1.0;
    } else if (ratio < 0.25) {
      return (ratio / 0.25).clamp(0.0, 1.0);
    } else {
      return ((1.0 - ratio) / 0.4).clamp(0.0, 1.0);
    }
  }

  double _calculatePoseScore(Face face) {
    double yaw = (face.headEulerAngleY ?? 0).abs();
    double pitch = (face.headEulerAngleX ?? 0).abs();
    double roll = (face.headEulerAngleZ ?? 0).abs();

    double yawScore = 1 - (yaw / 25.0).clamp(0.0, 1.0);
    double pitchScore = 1 - (pitch / 20.0).clamp(0.0, 1.0);
    double rollScore = 1 - (roll / 15.0).clamp(0.0, 1.0);

    return (yawScore * 0.4 + pitchScore * 0.4 + rollScore * 0.2);
  }

  Uint8List _cropFace(img.Image image, Face face) {
    final bbox = face.boundingBox;
    int padding = (bbox.width * 0.15).round();

    int startX = (bbox.left - padding).toInt().clamp(0, image.width);
    int startY = (bbox.top - padding).toInt().clamp(0, image.height);
    int endX = (bbox.right + padding).toInt().clamp(0, image.width);
    int endY = (bbox.bottom + padding).toInt().clamp(0, image.height);

    int width = endX - startX;
    int height = endY - startY;

    int size = max(width, height);
    int centerX = startX + width ~/ 2;
    int centerY = startY + height ~/ 2;

    startX = (centerX - size ~/ 2).clamp(0, image.width);
    startY = (centerY - size ~/ 2).clamp(0, image.height);
    int endX2 = (startX + size).clamp(0, image.width);
    int endY2 = (startY + size).clamp(0, image.height);

    img.Image cropped = img.copyCrop(
      image,
      x: startX,
      y: startY,
      width: endX2 - startX,
      height: endY2 - startY,
    );

    img.Image resized = img.copyResize(cropped, width: 96, height: 96);

    return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
  }

  List<double> _extractFaceFeaturesFromCropped(Uint8List croppedBytes) {
    img.Image? image = img.decodeImage(croppedBytes);
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
        double edgeResponse = 0.0;

        for (int cy = 0; cy < cellSize; cy++) {
          for (int cx = 0; cx < cellSize; cx++) {
            int px = gx * cellSize + cx;
            int py = gy * cellSize + cy;
            int pixel = resized.getPixel(px, py);
            double brightness = (pixel & 0xFF) / 255.0;
            sum += brightness;
            sumSq += brightness * brightness;

            if (cx > 0 && cx < cellSize - 1 && cy > 0 && cy < cellSize - 1) {
              int pxLeft = resized.getPixel(px - 1, py) & 0xFF;
              int pxRight = resized.getPixel(px + 1, py) & 0xFF;
              int pyUp = resized.getPixel(px, py - 1) & 0xFF;
              int pyDown = resized.getPixel(px, py + 1) & 0xFF;
              double gxVal = (pxRight - pxLeft) / 255.0;
              double gyVal = (pyDown - pyUp) / 255.0;
              edgeResponse += sqrt(gxVal * gxVal + gyVal * gyVal);
            }
          }
        }

        int idx = (gy * gridSize + gx) * 2;
        int pixelCount = cellSize * cellSize;
        features[idx] = sum / pixelCount;
        features[idx + 1] = sqrt(
            max(0.0, sumSq / pixelCount - features[idx] * features[idx]));

        if (idx + 2 < _featureVectorSize) {
          features[idx + 2] = (edgeResponse / pixelCount).clamp(0.0, 1.0);
        }
      }
    }

    double mean = features.reduce((a, b) => a + b) / features.length;
    double variance =
        features.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            features.length;
    double std = sqrt(variance);

    if (std > 0) {
      features = features.map((v) => (v - mean) / std).toList();
    }

    return features;
  }

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
          features[idx + 1] = sqrt(max(
              0.0,
              sumSq / (cellSize * cellSize) -
                  features[idx] * features[idx]));
        }
      }

      double mean = features.reduce((a, b) => a + b) / features.length;
      double variance =
          features.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
              features.length;
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

      double resolutionScore =
          ((image.width * image.height) / (1024 * 1024)).clamp(0.0, 1.0);

      double quality =
          (brightnessScore * 0.3 + contrastScore * 0.4 + resolutionScore * 0.3) *
              100;
      return quality.round().clamp(0, 100);
    } catch (e) {
      _logger.e('计算图像质量失败: $e');
      return 0;
    }
  }
}
