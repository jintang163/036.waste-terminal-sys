import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';
import '../models/ai_capture_event.dart';
import '../services/ai_capture_service.dart';
import '../widgets/status_tag.dart';
import '../utils/toast_util.dart';
import '../utils/date_util.dart';

class CaptureEventDetailPage extends StatefulWidget {
  final int eventId;

  const CaptureEventDetailPage({super.key, required this.eventId});

  @override
  State<CaptureEventDetailPage> createState() => _CaptureEventDetailPageState();
}

class _CaptureEventDetailPageState extends State<CaptureEventDetailPage> {
  final AiCaptureService _aiCaptureService = AiCaptureService();
  final TextEditingController _remarkController = TextEditingController();

  AiCaptureEvent? _event;
  bool _isLoading = true;
  bool _isHandling = false;
  bool _showRemarkInput = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final event = await _aiCaptureService.getCaptureEventDetail(widget.eventId);
      setState(() {
        _event = event;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ToastUtil.showError('加载事件详情失败');
    }
  }

  Future<void> _handleEvent() async {
    if (_isHandling) return;
    final remark = _remarkController.text.trim();
    setState(() {
      _isHandling = true;
    });
    try {
      final success = await _aiCaptureService.handleEvent(
        widget.eventId,
        remark.isEmpty ? '已处理' : remark,
      );
      if (success) {
        ToastUtil.showSuccess('处理成功');
        await _loadDetail();
      } else {
        ToastUtil.showError('处理失败');
      }
    } catch (e) {
      ToastUtil.showError('处理失败');
    } finally {
      setState(() {
        _isHandling = false;
        _showRemarkInput = false;
      });
    }
  }

  Future<void> _ignoreEvent() async {
    if (_isHandling) return;
    setState(() {
      _isHandling = true;
    });
    try {
      final success = await _aiCaptureService.ignoreEvent(widget.eventId);
      if (success) {
        ToastUtil.showSuccess('已忽略');
        await _loadDetail();
      } else {
        ToastUtil.showError('操作失败');
      }
    } catch (e) {
      ToastUtil.showError('操作失败');
    } finally {
      setState(() {
        _isHandling = false;
      });
    }
  }

  IconData _getEventCategoryIcon(String? category) {
    switch (category) {
      case 'safety_violation':
        return Icons.security;
      case 'equipment_warning':
        return Icons.build_outlined;
      case 'behavior_abnormal':
        return Icons.person_off_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getEventCategoryColor(String? category) {
    switch (category) {
      case 'safety_violation':
        return AppTheme.dangerColor;
      case 'equipment_warning':
        return AppTheme.warningColor;
      case 'behavior_abnormal':
        return AppTheme.infoColor;
      default:
        return AppTheme.textSecondary;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('事件详情'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? Center(
                  child: Text('事件不存在', style: AppTextStyle.bodySecondary),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSnapshotArea(),
                      SizedBox(height: 16.h),
                      _buildEventInfo(),
                      SizedBox(height: 16.h),
                      _buildHandleSection(),
                      if (_event?.videoClipPath != null &&
                          _event!.videoClipPath!.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildVideoClipSection(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSnapshotArea() {
    final snapshotPath = _event?.snapshotPath;
    final hasSnapshot = snapshotPath != null && snapshotPath.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 200.h,
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
      child: hasSnapshot
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black12,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48.r,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: _getHandleStatusTag(_event?.handleStatus),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 48.r,
                    color: AppTheme.textHint,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '暂无抓拍图片',
                    style: AppTextStyle.bodySecondary,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEventInfo() {
    final categoryColor = _getEventCategoryColor(_event?.eventCategory);
    final categoryIcon = _getEventCategoryIcon(_event?.eventCategory);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon, size: 20.r, color: categoryColor),
              SizedBox(width: 8.w),
              Text(
                _event?.eventTypeText ?? '未知事件',
                style: AppTextStyle.subtitle,
              ),
              const Spacer(),
              _getHandleStatusTag(_event?.handleStatus),
            ],
          ),
          Divider(height: 24.h),
          _buildInfoRow('事件类型', _event?.eventTypeText ?? '-'),
          SizedBox(height: 8.h),
          _buildInfoRow('事件分类', _event?.eventCategoryText ?? '-'),
          SizedBox(height: 8.h),
          _buildInfoRow('关联摄像头', _event?.cameraName ?? '-'),
          SizedBox(height: 8.h),
          _buildInfoRow(
            '抓拍时间',
            _event?.captureTime != null
                ? DateUtil.formatDateTime(_event!.captureTime)
                : '-',
          ),
          SizedBox(height: 8.h),
          _buildConfidenceRow(_event?.confidence),
          if (_event?.detail != null && _event!.detail!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _buildInfoRow('事件详情', _event!.detail!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: AppTextStyle.bodySecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyle.body,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceRow(int? confidence) {
    final value = (confidence ?? 0) / 100.0;
    final color = value >= 0.8
        ? AppTheme.dangerColor
        : value >= 0.5
            ? AppTheme.warningColor
            : AppTheme.infoColor;

    return Row(
      children: [
        SizedBox(
          width: 80.w,
          child: Text('置信度', style: AppTextStyle.bodySecondary),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${confidence ?? 0}%',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandleSection() {
    final isUnhandled = _event?.isUnhandled ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理状态', style: AppTextStyle.subtitle),
          SizedBox(height: 12.h),
          if (!isUnhandled) ...[
            Row(
              children: [
                _getHandleStatusTag(_event?.handleStatus),
                SizedBox(width: 12.w),
                if (_event?.handleTime != null)
                  Text(
                    DateUtil.formatDateTime(_event!.handleTime),
                    style: AppTextStyle.bodySecondary,
                  ),
              ],
            ),
            if (_event?.handleRemark != null &&
                _event!.handleRemark!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                '处理备注：${_event!.handleRemark}',
                style: AppTextStyle.bodySecondary,
              ),
            ],
          ] else ...[
            if (_showRemarkInput) ...[
              TextField(
                controller: _remarkController,
                maxLines: 3,
                style: AppTextStyle.body,
                decoration: const InputDecoration(
                  hintText: '请输入处理备注',
                ),
              ),
              SizedBox(height: 12.h),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isHandling ? null : _ignoreEvent,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderColor),
                      minimumSize: Size(double.infinity, 40.h),
                    ),
                    child: const Text('忽略'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isHandling
                        ? null
                        : _showRemarkInput
                            ? _handleEvent
                            : () {
                                setState(() {
                                  _showRemarkInput = true;
                                });
                              },
                    child: _isHandling
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_showRemarkInput ? '确认处理' : '处理'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoClipSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('视频片段', style: AppTextStyle.subtitle),
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: () {
              ToastUtil.showInfo('视频播放功能开发中');
            },
            child: Container(
              width: double.infinity,
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 36.r,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '播放视频片段',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
