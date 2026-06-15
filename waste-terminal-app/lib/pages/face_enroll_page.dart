import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../services/face_auth_service.dart';
import '../providers/app_provider.dart';
import '../utils/toast_util.dart';
import '../widgets/common_button.dart';

class FaceEnrollPage extends StatefulWidget {
  const FaceEnrollPage({super.key});

  @override
  State<FaceEnrollPage> createState() => _FaceEnrollPageState();
}

class _FaceEnrollPageState extends State<FaceEnrollPage> {
  final FaceAuthService _faceAuthService = FaceAuthService();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _capturedImage;
  bool _isProcessing = false;
  int? _quality;
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _checkEnrolledStatus();
  }

  Future<void> _checkEnrolledStatus() async {
    try {
      final appProvider = context.read<AppProvider>();
      final userInfo = appProvider.userInfo;
      if (userInfo != null && userInfo['username'] != null) {
        bool enrolled = await _faceAuthService.hasEnrolledFace(userInfo['username']);
        if (mounted) {
          setState(() {
            _isEnrolled = enrolled;
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<bool> _requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      ToastUtil.showError('相机权限被拒绝，请在设置中开启');
      return false;
    }
    ToastUtil.showError('需要相机权限进行人脸录入');
    return false;
  }

  Future<void> _captureFace() async {
    try {
      bool granted = await _requestCameraPermission();
      if (!granted) return;

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        Uint8List imageBytes = await pickedFile.readAsBytes();
        int quality = _faceAuthService.calculateQuality(imageBytes);

        setState(() {
          _capturedImage = imageBytes;
          _quality = quality;
        });
      }
    } catch (e) {
      ToastUtil.showError('拍照失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _enrollFace() async {
    if (_capturedImage == null) {
      ToastUtil.showWarning('请先拍摄人脸照片');
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    EasyLoading.show(status: '正在录入人脸...');

    try {
      final appProvider = context.read<AppProvider>();
      final userInfo = appProvider.userInfo;

      if (userInfo == null) {
        throw Exception('用户未登录');
      }

      await _faceAuthService.enrollFace(
        userId: userInfo['userId'] ?? 0,
        username: userInfo['username'] ?? '',
        faceImage: _capturedImage!,
        enterpriseId: userInfo['enterpriseId'],
        deviceId: appProvider.deviceId,
      );

      ToastUtil.showSuccess('人脸录入成功');
      setState(() {
        _isEnrolled = true;
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ToastUtil.showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      EasyLoading.dismiss();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Color _getQualityColor() {
    if (_quality == null) return AppTheme.textSecondary;
    if (_quality! >= 80) return Colors.green;
    if (_quality! >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getQualityText() {
    if (_quality == null) return '未检测';
    if (_quality! >= 80) return '优秀';
    if (_quality! >= 60) return '一般';
    return '较差';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: const Text('人脸录入', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _isEnrolled
                            ? '您已录入人脸，可重新拍摄覆盖现有数据'
                            : '请确保光线充足，面部正对摄像头，保持表情自然',
                        style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
              _buildFacePreview(),
              SizedBox(height: 20.h),
              _buildQualityIndicator(),
              SizedBox(height: 30.h),
              CommonButton(
                text: _capturedImage == null ? '拍摄人脸' : '重新拍摄',
                onPressed: _isProcessing ? null : _captureFace,
                icon: Icons.camera_alt,
              ),
              SizedBox(height: 16.h),
              if (_capturedImage != null)
                CommonButton(
                  text: '确认录入',
                  onPressed: _isProcessing ? null : _enrollFace,
                  type: ButtonType.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacePreview() {
    return Container(
      width: 240.w,
      height: 240.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor,
          width: 3.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 20.r,
          ),
        ],
      ),
      child: ClipOval(
        child: _capturedImage != null
            ? Image.memory(
                _capturedImage!,
                fit: BoxFit.cover,
              )
            : Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 80.sp,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '点击下方按钮拍摄',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildQualityIndicator() {
    if (_quality == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('图像质量:', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary)),
            SizedBox(width: 8.w),
            Text(
              '$_quality% (${_getQualityText()})',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: _getQualityColor()),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: (_quality ?? 0) / 100,
            minHeight: 8.h,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_getQualityColor()),
          ),
        ),
        if (_quality != null && _quality! < _faceAuthService.minEnrollQuality) ...[
          SizedBox(height: 8.h),
          Text(
            '质量分数较低，建议重新拍摄（需达到${_faceAuthService.minEnrollQuality}%以上）',
            style: TextStyle(color: Colors.red, fontSize: 12.sp),
          ),
        ],
      ],
    );
  }
}
