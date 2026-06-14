import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'api_service.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  FileService._internal();

  Future<String?> uploadFile(
    String filePath, {
    String fileKey = 'file',
    String? uploadPath,
    Function(double)? onProgress,
  }) async {
    try {
      _logger.d('上传文件: $filePath');

      File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      String url = uploadPath ?? '/file/upload';

      final response = await _apiService.uploadFile(
        url,
        filePath,
        fileKey: fileKey,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      String? fileUrl = response.data['data']?['url'];
      _logger.i('文件上传成功: $fileUrl');
      return fileUrl;
    } catch (e) {
      _logger.e('文件上传失败: $e');
      rethrow;
    }
  }

  Future<List<String>?> uploadFiles(
    List<String> filePaths, {
    String fileKey = 'files',
    String? uploadPath,
    Function(int, int, double)? onProgress,
  }) async {
    try {
      _logger.d('批量上传文件，数量: ${filePaths.length}');

      List<String> uploadedUrls = [];
      int total = filePaths.length;

      for (int i = 0; i < filePaths.length; i++) {
        try {
          String? url = await uploadFile(
            filePaths[i],
            fileKey: fileKey,
            uploadPath: uploadPath,
          );
          if (url != null) {
            uploadedUrls.add(url);
          }

          if (onProgress != null) {
            onProgress(i + 1, total, (i + 1) / total);
          }
        } catch (e) {
          _logger.w('文件上传失败，跳过: ${filePaths[i]}, $e');
        }
      }

      _logger.i('批量上传完成，成功: ${uploadedUrls.length}/$total');
      return uploadedUrls;
    } catch (e) {
      _logger.e('批量上传文件失败: $e');
      rethrow;
    }
  }

  Future<String> getFileUrl(String fileId) async {
    try {
      final response = await _apiService.get('/file/$fileId');
      String url = response.data['data']?['url'] ?? '';
      return url;
    } catch (e) {
      _logger.e('获取文件URL失败: $e');
      rethrow;
    }
  }

  Future<bool> deleteFile(String fileId) async {
    try {
      final response = await _apiService.delete('/file/$fileId');
      return response.data['code'] == 200;
    } catch (e) {
      _logger.e('删除文件失败: $e');
      return false;
    }
  }

  String getFileName(String filePath) {
    return p.basename(filePath);
  }

  String getFileExtension(String filePath) {
    return p.extension(filePath);
  }

  bool isImageFile(String filePath) {
    String ext = getFileExtension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }

  bool isPdfFile(String filePath) {
    String ext = getFileExtension(filePath).toLowerCase();
    return ext == '.pdf';
  }

  bool isVideoFile(String filePath) {
    String ext = getFileExtension(filePath).toLowerCase();
    return ['.mp4', '.avi', '.mov', '.mkv', '.wmv'].contains(ext);
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
