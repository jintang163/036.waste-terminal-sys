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

class FaceVerifyPage extends StatefulWidget {
  final String authType;
  final String? businessType;
  final String? businessId;
  final String? businessNo;
  final String? targetUsername;
  final bool autoNavigateOnSuccess;

  const FaceVerifyPage({
    super.key,
    this.authType = 'verify',
    this.businessType,
    this.businessId,
    this.businessNo,
    this.targetUsername,
    this.autoNavigateOnSuccess = true,
  });

  @override
  State<FaceVerifyPage> createState() => _FaceVerifyPageState();
}

class _FaceVerifyPageState extends State<FaceVerifyPage> {
  final FaceAuthService _faceAuthService = FaceAuthService();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _capturedImage;
  bool _isProcessing = false;
  String? _statusText;
  double? _similarity;
  bool _verifySuccess = false;

  String get _pageTitle {
    switch (widget.authType) {
      case 'login':
        return '人脸登录';
      case 'waste_in':
        return '入库操作人脸验证';
      case 'waste_out':
        return '出库操作人脸验证';
      default:
        return '人脸验证';
    }
  }

  Future<bool> _requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      ToastUtil.showError('相机权限被拒绝，请在设置中开启');
      return false;
    }
    ToastUtil.showError('需要相机权限进行人脸验证');
    return false;
  }

  Future<void> _captureAndVerify() async {
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

        setState(() {
          _capturedImage = imageBytes;
          _isProcessing = true;
          _statusText = '正在识别...';
          _similarity = null;
          _verifySuccess = false;
        });

        EasyLoading.show(status: '正在识别...');

        final appProvider = context.read<AppProvider>();
        FaceAuthResult result;

        if (widget.targetUsername != null && widget.targetUsername!.isNotEmpty) {
          result = await _faceAuthService.verifyFaceForUser(
            username: widget.targetUsername!,
            faceImage: imageBytes,
            authType: widget.authType,
            businessType: widget.businessType,
            businessId: widget.businessId,
            businessNo: widget.businessNo,
            deviceId: appProvider.deviceId,
            enterpriseId: appProvider.userInfo?['enterpriseId'],
          );
        } else {
          result = await _faceAuthService.verifyFace(
            faceImage: imageBytes,
            authType: widget.authType,
            businessType: widget.businessType,
            businessId: widget.businessId,
            businessNo: widget.businessNo,
            deviceId: appProvider.deviceId,
            enterpriseId: appProvider.userInfo?['enterpriseId'],
          );
        }

        EasyLoading.dismiss();

        setState(() {
          _isProcessing = false;
          _similarity = result.similarity;
          _verifySuccess = result.success;
          _statusText = result.hasError
              ? '验证失败: ${result.error}'
              : result.success
                  ? '验证通过，欢迎 ${result.userFace?.username ?? ""}'
                  : '验证未通过，请重试';
        });

        if (result.success) {
          ToastUtil.showSuccess('验证通过，相似度: ${result.similarityText}');
          if (widget.autoNavigateOnSuccess) {
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              Navigator.of(context).pop(result);
            }
          }
        } else {
          if (result.hasError) {
            ToastUtil.showError(result.error ?? '验证失败');
          } else {
            ToastUtil.showWarning('相似度不足，请正对摄像头重试');
          }
        }
      }
    } catch (e) {
      EasyLoading.dismiss();
      setState(() {
        _isProcessing = false;
        _statusText = '验证失败: ${e.toString().replaceAll('Exception: ', '')}';
      });
      ToastUtil.showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Color _getStatusColor() {
    if (_similarity == null) return AppTheme.textSecondary;
    if (_similarity! >= 0.9) return Colors.green;
    if (_similarity! >= _faceAuthService.threshold) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: Text(_pageTitle, style: const TextStyle(color: Colors.white)),
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
                  color: widget.targetUsername != null
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: widget.targetUsername != null
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.targetUsername != null ? Icons.verified_user : Icons.security,
                      color: widget.targetUsername != null
                          ? Colors.orange
                          : AppTheme.primaryColor,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        widget.targetUsername != null
                            ? '请验证操作人: ${widget.targetUsername}'
                            : '请将面部正对摄像头，确保光线充足',
                        style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
              _buildFacePreview(),
              SizedBox(height: 24.h),
              if (_statusText != null) _buildStatusDisplay(),
              SizedBox(height: 30.h),
              CommonButton(
                text: _capturedImage == null ? '开始人脸识别' : '重新识别',
                onPressed: _isProcessing ? null : _captureAndVerify,
                icon: Icons.camera_alt,
              ),
              if (_verifySuccess && !widget.autoNavigateOnSuccess) ...[
                SizedBox(height: 16.h),
                CommonButton(
                  text: '确认通过',
                  onPressed: () {
                    Navigator.of(context).pop(
                      FaceAuthResult(
                        success: true,
                        similarity: _similarity ?? 0.0,
                        capturedImage: _capturedImage,
                      ),
                    );
                  },
                  type: ButtonType.success,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacePreview() {
    IconData icon = _verifySuccess ? Icons.check_circle : Icons.face;
    Color borderColor = _verifySuccess
        ? Colors.green
        : _capturedImage != null
            ? _getStatusColor()
            : AppTheme.primaryColor;

    return Container(
      width: 240.w,
      height: 240.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 4.w,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.25),
            blurRadius: 20.r,
          ),
        ],
      ),
      child: ClipOval(
        child: _capturedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_capturedImage!, fit: BoxFit.cover),
                  if (_isProcessing)
                    Container(
                      color: Colors.black45,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3.w,
                        ),
                      ),
                    ),
                  if (_verifySuccess)
                    Positioned(
                      right: 16.w,
                      bottom: 16.w,
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                    ),
                ],
              )
            : Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 80.sp, color: Colors.grey.shade400),
                      SizedBox(height: 8.h),
                      Text(
                        '点击下方按钮开始识别',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusDisplay() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: _verifySuccess ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: _verifySuccess ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Center(
            child: Text(
              _statusText!,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: _verifySuccess ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ),
        if (_similarity != null) ...[
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('相似度:', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary)),
              Text(
                '${(_similarity! * 100).toStringAsFixed(1)}%  (阈值: ${(_faceAuthService.threshold * 100).toInt()}%)',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: _similarity!.clamp(0.0, 1.0),
                  minHeight: 10.h,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                ),
              ),
              Positioned(
                left: _faceAuthService.threshold * 1.sw - 2,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3.w,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
