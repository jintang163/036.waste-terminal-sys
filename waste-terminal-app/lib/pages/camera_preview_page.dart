import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../models/camera_model.dart';
import '../models/ai_capture_event.dart';
import '../services/camera_service.dart';
import '../services/video_player_service.dart';
import '../services/ai_capture_service.dart';
import '../widgets/status_tag.dart';
import '../utils/toast_util.dart';
import '../utils/date_util.dart';

class CameraPreviewPage extends StatefulWidget {
  final String cameraCode;

  const CameraPreviewPage({super.key, required this.cameraCode});

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  final CameraService _cameraService = CameraService();
  final VideoPlayerService _videoPlayerService = VideoPlayerService();
  final AiCaptureService _aiCaptureService = AiCaptureService();

  CameraModel? _camera;
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _aiEnabled = false;
  List<AiCaptureEvent> _recentEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCameraDetail();
  }

  @override
  void dispose() {
    _videoPlayerService.disconnectStream();
    super.dispose();
  }

  Future<void> _loadCameraDetail() async {
    try {
      final cameras = await _cameraService.getCameraList();
      final camera = cameras.where((c) => c.cameraCode == widget.cameraCode).firstOrNull;
      if (camera != null) {
        setState(() {
          _camera = camera;
          _aiEnabled = camera.aiEnabled ?? false;
        });
      }
      await _loadRecentEvents();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ToastUtil.showError('加载摄像头信息失败');
    }
  }

  Future<void> _loadRecentEvents() async {
    try {
      final result = await _aiCaptureService.getCaptureEventPage(
        pageNum: 1,
        pageSize: 3,
        cameraCode: widget.cameraCode,
      );
      setState(() {
        _recentEvents = result.records ?? [];
      });
    } catch (e) {
      // silently fail for recent events
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _videoPlayerService.disconnectStream();
      setState(() {
        _isPlaying = false;
        _isRecording = false;
      });
    } else {
      final rtspUrl = _camera?.rtspUrl;
      if (rtspUrl == null || rtspUrl.isEmpty) {
        ToastUtil.showError('无可用的视频流地址');
        return;
      }
      final success = await _videoPlayerService.connectStream(rtspUrl);
      setState(() {
        _isPlaying = success;
      });
      if (!success) {
        ToastUtil.showError('连接视频流失败');
      }
    }
  }

  Future<void> _takeSnapshot() async {
    if (!_isPlaying) {
      ToastUtil.showInfo('请先开始预览');
      return;
    }
    final filePath = await _videoPlayerService.takeSnapshot();
    if (filePath != null) {
      ToastUtil.showSuccess('截图已保存');
    } else {
      ToastUtil.showError('截图失败');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isPlaying) {
      ToastUtil.showInfo('请先开始预览');
      return;
    }
    if (_isRecording) {
      final filePath = await _videoPlayerService.stopRecording();
      setState(() {
        _isRecording = false;
      });
      if (filePath != null) {
        ToastUtil.showSuccess('录像已保存');
      } else {
        ToastUtil.showError('停止录像失败');
      }
    } else {
      final taskId = await _videoPlayerService.startRecording(
        widget.cameraCode,
        'manual',
      );
      setState(() {
        _isRecording = taskId != null;
      });
      if (taskId == null) {
        ToastUtil.showError('开始录像失败');
      } else {
        ToastUtil.showSuccess('开始录像');
      }
    }
  }

  Future<void> _toggleAi() async {
    if (_camera?.id == null) return;
    final newEnabled = !_aiEnabled;
    final success = await _cameraService.toggleAi(_camera!.id!, newEnabled);
    if (success) {
      setState(() {
        _aiEnabled = newEnabled;
      });
      ToastUtil.showSuccess(newEnabled ? 'AI检测已开启' : 'AI检测已关闭');
    } else {
      ToastUtil.showError('切换AI检测状态失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_camera?.cameraName ?? '视频预览'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideoArea(),
                  SizedBox(height: 12.h),
                  _buildControlBar(),
                  SizedBox(height: 24.h),
                  _buildRecentEventsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoArea() {
    return Container(
      width: double.infinity,
      height: 220.h,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isPlaying)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.connected_tv,
                    size: 40.r,
                    color: AppTheme.successColor,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'RTSP预览中',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 48.r,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'RTSP预览',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          if (_isRecording)
            Positioned(
              top: 12.h,
              right: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor,
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.r,
                      height: 6.r,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'REC',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 12.h,
            left: 12.w,
            child: _camera?.isOnline == true
                ? StatusTag.success('在线')
                : StatusTag.warning('离线', outlined: true),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildControlButton(
            icon: _isPlaying ? Icons.stop : Icons.play_arrow,
            label: _isPlaying ? '停止' : '预览',
            color: _isPlaying ? AppTheme.dangerColor : AppTheme.primaryColor,
            onTap: _togglePlay,
          ),
          _buildControlButton(
            icon: Icons.camera_alt_outlined,
            label: '截图',
            color: AppTheme.primaryColor,
            onTap: _takeSnapshot,
          ),
          _buildControlButton(
            icon: _isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
            label: _isRecording ? '停止录像' : '录像',
            color: _isRecording ? AppTheme.dangerColor : AppTheme.warningColor,
            onTap: _toggleRecording,
          ),
          _buildControlButton(
            icon: Icons.smart_toy_outlined,
            label: 'AI检测',
            color: _aiEnabled ? AppTheme.secondaryColor : AppTheme.textHint,
            onTap: _toggleAi,
            isActive: _aiEnabled,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withOpacity(0.15)
                  : color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22.r, color: color),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最近AI抓拍', style: AppTextStyle.subtitle),
            if (_recentEvents.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.captureEventList);
                },
                child: Text(
                  '查看全部',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        if (_recentEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: Center(
              child: Text(
                '暂无AI抓拍事件',
                style: AppTextStyle.bodySecondary,
              ),
            ),
          )
        else
          ...List.generate(_recentEvents.length, (index) {
            return _buildRecentEventCard(_recentEvents[index]);
          }),
      ],
    );
  }

  Widget _buildRecentEventCard(AiCaptureEvent event) {
    return GestureDetector(
      onTap: () {
        if (event.id != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.captureEventDetail,
            arguments: event.id,
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 22.r,
                color: AppTheme.warningColor,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.eventTypeText,
                    style: AppTextStyle.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    DateUtil.friendlyTime(event.captureTime),
                    style: AppTextStyle.small,
                  ),
                ],
              ),
            ),
            _getHandleStatusTag(event.handleStatus),
          ],
        ),
      ),
    );
  }

  StatusTag _getHandleStatusTag(int? status) {
    switch (status) {
      case 1:
        return StatusTag.success('已处理');
      case 2:
        return StatusTag.info('已忽略');
      default:
        return StatusTag.danger('未处理', outlined: true);
    }
  }
}
