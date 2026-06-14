import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'permission_util.dart';
import 'toast_util.dart';
import 'logger_util.dart';

class ImageUtil {
  ImageUtil._();

  static final ImagePicker _imagePicker = ImagePicker();

  static Future<File?> pickImageFromCamera({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final hasPermission = await PermissionUtil.requestCamera();
    if (!hasPermission) {
      ToastUtil.showError('请先授予相机权限');
      return null;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality ?? 80,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      LoggerUtil.error('pickImageFromCamera error', e);
      ToastUtil.showError('拍照失败');
    }
    return null;
  }

  static Future<File?> pickImageFromGallery({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final hasPermission = await PermissionUtil.requestPhotos();
    if (!hasPermission) {
      ToastUtil.showError('请先授予相册权限');
      return null;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality ?? 80,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      LoggerUtil.error('pickImageFromGallery error', e);
      ToastUtil.showError('选择图片失败');
    }
    return null;
  }

  static Future<List<File>> pickMultiImageFromGallery({
    int maxImages = 9,
    int imageQuality = 80,
  }) async {
    final hasPermission = await PermissionUtil.requestPhotos();
    if (!hasPermission) {
      ToastUtil.showError('请先授予相册权限');
      return [];
    }

    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: imageQuality,
      );
      return images.map((e) => File(e.path)).toList();
    } catch (e) {
      LoggerUtil.error('pickMultiImageFromGallery error', e);
      ToastUtil.showError('选择图片失败');
      return [];
    }
  }

  static Future<File?> pickVideo({
    Duration? maxDuration,
  }) async {
    final hasPermission = await PermissionUtil.requestPhotos();
    if (!hasPermission) {
      ToastUtil.showError('请先授予相册权限');
      return null;
    }

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
      if (video != null) {
        return File(video.path);
      }
    } catch (e) {
      LoggerUtil.error('pickVideo error', e);
      ToastUtil.showError('选择视频失败');
    }
    return null;
  }

  static Future<File?> pickVideoFromCamera({
    Duration? maxDuration,
  }) async {
    final hasPermission = await PermissionUtil.requestCamera();
    if (!hasPermission) {
      ToastUtil.showError('请先授予相机权限');
      return null;
    }

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
      );
      if (video != null) {
        return File(video.path);
      }
    } catch (e) {
      LoggerUtil.error('pickVideoFromCamera error', e);
      ToastUtil.showError('录像失败');
    }
    return null;
  }

  static Future<List<AssetEntity>> pickWeChatAssets({
    BuildContext? context,
    int maxAssets = 9,
    RequestType requestType = RequestType.image,
    List<AssetEntity>? selectedAssets,
  }) async {
    final hasPermission = await PermissionUtil.requestPhotos();
    if (!hasPermission) {
      ToastUtil.showError('请先授予相册权限');
      return [];
    }

    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context ?? _getCurrentContext(),
        pickerConfig: AssetPickerConfig(
          maxAssets: maxAssets,
          requestType: requestType,
          selectedAssets: selectedAssets,
        ),
      );
      return result ?? [];
    } catch (e) {
      LoggerUtil.error('pickWeChatAssets error', e);
      ToastUtil.showError('选择图片失败');
      return [];
    }
  }

  static BuildContext _getCurrentContext() {
    return WidgetsBinding.instance.focusManager.primaryFocus?.context ??
        BuildContext;
  }

  static Future<Uint8List?> getAssetEntityData(AssetEntity entity) async {
    try {
      final file = await entity.file;
      if (file != null) {
        return await file.readAsBytes();
      }
    } catch (e) {
      LoggerUtil.error('getAssetEntityData error', e);
    }
    return null;
  }

  static Future<File?> getAssetEntityFile(AssetEntity entity) async {
    try {
      return await entity.file;
    } catch (e) {
      LoggerUtil.error('getAssetEntityFile error', e);
      return null;
    }
  }

  static Future<Image?> getAssetEntityThumbnail(
    AssetEntity entity, {
    int width = 200,
    int height = 200,
  }) async {
    try {
      final data = await entity.thumbnailDataWithSize(
        ThumbnailSize(width, height),
      );
      if (data != null) {
        return Image.memory(data);
      }
    } catch (e) {
      LoggerUtil.error('getAssetEntityThumbnail error', e);
    }
    return null;
  }

  static ImageProvider getAssetEntityImageProvider(AssetEntity entity) {
    return AssetEntityImageProvider(entity);
  }

  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static bool isImageFile(String filePath) {
    final ext = filePath.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.webp');
  }

  static bool isVideoFile(String filePath) {
    final ext = filePath.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.wmv') ||
        ext.endsWith('.flv') ||
        ext.endsWith('.mkv');
  }
}
