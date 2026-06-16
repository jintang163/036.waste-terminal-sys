import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../models/waste_ai_recognition.dart';
import '../models/waste_catalog.dart';
import '../services/api_service.dart';
import '../utils/toast_util.dart';

class WasteAiRecognitionWidget extends StatefulWidget {
  final void Function(WasteAiRecognitionResult result, WasteCatalog? catalog)
      onResultSelected;

  const WasteAiRecognitionWidget({
    super.key,
    required this.onResultSelected,
  });

  @override
  State<WasteAiRecognitionWidget> createState() =>
      _WasteAiRecognitionWidgetState();
}

class _WasteAiRecognitionWidgetState extends State<WasteAiRecognitionWidget> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isRecognizing = false;
  double _uploadProgress = 0;
  File? _selectedImage;
  WasteAiRecognitionResponse? _response;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: AppSize.iconSmall, color: AppTheme.primaryColor),
              SizedBox(width: 6.w),
              Text('AI 智能识别', style: AppTextStyle.subtitle),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '拍照识别危废类别',
                  style: AppTextStyle.caption.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildActionButtons(),
          if (_selectedImage != null) ...[
            SizedBox(height: 12.h),
            _buildImagePreview(),
          ],
          if (_isRecognizing) ...[
            SizedBox(height: 12.h),
            _buildProgressIndicator(),
          ],
          if (_errorMessage != null) ...[
            SizedBox(height: 12.h),
            _buildErrorMessage(),
          ],
          if (_response != null && !_isRecognizing) ...[
            SizedBox(height: 12.h),
            _buildResultsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isRecognizing ? null : _takePhoto,
            icon: Icon(Icons.camera_alt, size: AppSize.iconSmall),
            label: Text('拍照识别'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isRecognizing ? null : _pickFromGallery,
            icon: Icon(Icons.photo_library, size: AppSize.iconSmall),
            label: Text('相册选择'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 180.h),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (!_isRecognizing)
          Positioned(
            top: 4.r,
            right: 4.r,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImage = null;
                  _response = null;
                  _errorMessage = null;
                });
              },
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.close, color: Colors.white, size: 14.r),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 4.h,
            backgroundColor: AppTheme.bgSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _uploadProgress < 1.0 ? '正在上传图片...' : 'AI 识别中，请稍候...',
          style: AppTextStyle.caption.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: AppSize.iconSmall, color: AppTheme.dangerColor),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTextStyle.caption.copyWith(color: AppTheme.dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final results = _response?.results ?? [];
    if (results.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: AppSize.iconSmall, color: AppTheme.warningColor),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                _response?.message ?? '未识别到危废类别，请手动选择',
                style:
                    AppTextStyle.caption.copyWith(color: AppTheme.warningColor),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('识别结果', style: AppTextStyle.subtitle),
            SizedBox(width: 8.w),
            Text(
              '共 ${results.length} 项（点击选择）',
              style: AppTextStyle.small.copyWith(color: AppTheme.textHint),
            ),
            const Spacer(),
            if (_response?.processingTime != null)
              Text(
                '耗时 ${_response!.processingTime}ms',
                style: AppTextStyle.small.copyWith(color: AppTheme.textHint),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        ...results.map((result) => _buildResultItem(result)),
      ],
    );
  }

  Widget _buildResultItem(WasteAiRecognitionResult result) {
    final confidence = result.confidence ?? 0;
    final confidenceColor = confidence >= 0.8
        ? AppTheme.successColor
        : confidence >= 0.6
            ? AppTheme.warningColor
            : AppTheme.textHint;

    return InkWell(
      onTap: () => _selectResult(result),
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                result.wasteCode ?? '',
                style: AppTextStyle.caption.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.wasteName ?? '未知',
                    style: AppTextStyle.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.wasteCategory != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      result.wasteCategory!,
                      style: AppTextStyle.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(confidence * 100).toStringAsFixed(0)}%',
                  style: AppTextStyle.caption.copyWith(
                    color: confidenceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  width: 48.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: confidence.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: confidenceColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right,
                size: AppSize.iconSmall, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: AppConfig.imageMaxWidth.toDouble(),
        maxHeight: AppConfig.imageMaxHeight.toDouble(),
        imageQuality: AppConfig.imageCompressQuality,
      );
      if (photo != null) {
        await _processImage(photo);
      }
    } catch (e) {
      ToastUtil.showError('拍照失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConfig.imageMaxWidth.toDouble(),
        maxHeight: AppConfig.imageMaxHeight.toDouble(),
        imageQuality: AppConfig.imageCompressQuality,
      );
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      ToastUtil.showError('选择图片失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    setState(() {
      _isRecognizing = true;
      _uploadProgress = 0;
      _response = null;
      _errorMessage = null;
      _selectedImage = File(imageFile.path);
    });

    try {
      String filePath = imageFile.path;

      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/ai_recognize_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: AppConfig.imageCompressQuality,
        minWidth: AppConfig.imageMaxWidth,
        minHeight: AppConfig.imageMaxHeight,
      );
      if (compressed != null) {
        filePath = compressed.path;
      }

      final response = await _apiService.recognizeWaste(
        filePath,
        onSendProgress: (sent, total) {
          if (total > 0) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      setState(() {
        _isRecognizing = false;
        _uploadProgress = 1.0;
        _response = response;
        if (response == null || !response.success) {
          _errorMessage = response?.message ?? 'AI识别返回异常';
        }
      });
    } catch (e) {
      setState(() {
        _isRecognizing = false;
        _errorMessage = 'AI识别失败: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  void _selectResult(WasteAiRecognitionResult result) {
    WasteCatalog? catalog;
    if (result.catalogId != null) {
      catalog = WasteCatalog(
        id: result.catalogId,
        wasteCode: result.wasteCode,
        wasteName: result.wasteName,
        wasteCategory: result.wasteCategory,
        wasteType: result.wasteType,
      );
    }
    widget.onResultSelected(result, catalog);
    ToastUtil.showSuccess('已选择: ${result.wasteCode} ${result.wasteName}');
  }
}
