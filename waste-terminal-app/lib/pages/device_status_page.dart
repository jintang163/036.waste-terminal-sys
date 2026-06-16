import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../services/device_self_check_service.dart';
import '../services/heartbeat_service.dart';
import '../services/operation_log_service.dart';
import '../utils/date_util.dart';
import '../utils/toast_util.dart';

class DeviceStatusPage extends StatefulWidget {
  const DeviceStatusPage({super.key});

  @override
  State<DeviceStatusPage> createState() => _DeviceStatusPageState();
}

class _DeviceStatusPageState extends State<DeviceStatusPage> {
  final DeviceSelfCheckService _selfCheckService = DeviceSelfCheckService();
  final HeartbeatService _heartbeatService = HeartbeatService();
  final OperationLogService _logService = OperationLogService();

  SelfCheckReport? _report;
  Map<String, int>? _logStats;
  bool _isLoading = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final lastReport = _selfCheckService.lastReport;
      if (lastReport != null) {
        _report = lastReport;
      } else {
        final cached = await _selfCheckService.getCachedReport();
        if (cached != null) {
          _report = cached;
        }
      }
      _logStats = await _logService.getLogStats();
    } catch (e) {
      // ignore
    }

    setState(() => _isLoading = false);

    if (_report == null) {
      unawaited(_performSelfCheck());
    }
  }

  Future<void> _performSelfCheck() async {
    setState(() => _isChecking = true);

    try {
      final report = await _selfCheckService.performSelfCheck();
      setState(() {
        _report = report;
      });
      await _logService.logInfo(
        '设备自检完成',
        category: BusinessConstants.logCategoryDevice,
        extra: {
          'overallStatus': report.overallStatus.name,
          'successCount': report.results.where((r) => r.status == CheckStatus.success).length,
          'warningCount': report.results.where((r) => r.status == CheckStatus.warning).length,
          'errorCount': report.results.where((r) => r.status == CheckStatus.error).length,
        },
      );
    } catch (e) {
      if (mounted) {
        ToastUtil.showError('自检失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _forceUploadLogs() async {
    try {
      ToastUtil.showLoading('正在上传日志...');
      await _logService.forceUpload();
      _logStats = await _logService.getLogStats();
      setState(() {});
      ToastUtil.showSuccess('日志上传完成');
    } catch (e) {
      ToastUtil.showError('上传失败: $e');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      ToastUtil.showLoading('正在上报心跳...');
      await _heartbeatService.sendHeartbeat();
      ToastUtil.showSuccess('心跳上报完成');
    } catch (e) {
      ToastUtil.showError('心跳上报失败: $e');
    }
  }

  Color _getStatusColor(CheckStatus status) {
    switch (status) {
      case CheckStatus.success:
        return AppTheme.successColor;
      case CheckStatus.warning:
        return AppTheme.warningColor;
      case CheckStatus.error:
        return AppTheme.dangerColor;
      case CheckStatus.unknown:
        return AppTheme.textHint;
    }
  }

  IconData _getStatusIcon(CheckStatus status) {
    switch (status) {
      case CheckStatus.success:
        return Icons.check_circle;
      case CheckStatus.warning:
        return Icons.warning_amber_rounded;
      case CheckStatus.error:
        return Icons.error_rounded;
      case CheckStatus.unknown:
        return Icons.help_outline;
    }
  }

  String _getStatusText(CheckStatus status) {
    switch (status) {
      case CheckStatus.success:
        return '正常';
      case CheckStatus.warning:
        return '警告';
      case CheckStatus.error:
        return '异常';
      case CheckStatus.unknown:
        return '未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('设备状态'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isChecking ? null : _performSelfCheck,
            tooltip: '重新自检',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _performSelfCheck,
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  _buildOverallStatusCard(),
                  SizedBox(height: 16.h),
                  _buildDeviceInfoCard(),
                  SizedBox(height: 16.h),
                  _buildCheckItemsCard(),
                  SizedBox(height: 16.h),
                  _buildHeartbeatCard(),
                  SizedBox(height: 16.h),
                  _buildLogStatsCard(),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
    );
  }

  Widget _buildOverallStatusCard() {
    if (_report == null) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: AppTheme.shadowColor, blurRadius: 8)],
        ),
        child: Center(child: Text('暂无自检结果，请点击右上角刷新')),
      );
    }

    final status = _report!.overallStatus;
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final successCount = _report!.results.where((r) => r.status == CheckStatus.success).length;
    final warningCount = _report!.results.where((r) => r.status == CheckStatus.warning).length;
    final errorCount = _report!.results.where((r) => r.status == CheckStatus.error).length;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.9),
            statusColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getStatusIcon(status), color: Colors.white, size: 48.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('设备整体状态', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14.sp)),
                    SizedBox(height: 4.h),
                    Text(statusText, style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _isChecking
                  ? SizedBox(width: 24.r, height: 24.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white, size: 24.r),
                      onPressed: _performSelfCheck,
                    ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Text('$successCount', style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2.h),
                      Text('正常', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.sp)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Text('$warningCount', style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2.h),
                      Text('警告', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.sp)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Text('$errorCount', style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2.h),
                      Text('异常', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.sp)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '检测时间: ${DateUtil.formatDateTime(_report!.checkTime)}',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    if (_report == null) return const SizedBox.shrink();
    final info = _report!.deviceInfo;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: AppTheme.shadowColor, blurRadius: 8)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_rounded, color: AppTheme.primaryColor, size: 20.r),
              SizedBox(width: 8.w),
              Text('设备信息', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInfoRow('设备ID', info.deviceId ?? '-'),
          _buildInfoRow('设备名称', info.deviceName ?? '-'),
          _buildInfoRow('设备型号', info.deviceModel ?? '-'),
          _buildInfoRow('制造商', info.manufacturer ?? '-'),
          _buildInfoRow('品牌', info.brand ?? '-'),
          _buildInfoRow('系统版本', '${info.platform ?? '-'} ${info.osVersion ?? ''}'),
          if (info.sdkVersion != null) _buildInfoRow('SDK版本', info.sdkVersion!),
          if (info.totalStorage != null)
            _buildInfoRow(
              '存储空间',
              '已用 ${DeviceSelfCheckService.formatBytes((info.totalStorage! - (info.freeStorage ?? 0)))} / '
                  '总计 ${DeviceSelfCheckService.formatBytes(info.totalStorage!)}',
            ),
          if (info.freeStorage != null)
            Row(
              children: [
                SizedBox(width: 100.w, child: Text('剩余空间', style: AppTextStyle.caption)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: info.storageUsagePercent / 100,
                      minHeight: 8.h,
                      backgroundColor: AppTheme.bgPrimary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        info.storageUsagePercent > 85 ? AppTheme.dangerColor : AppTheme.successColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text('${info.storageUsagePercent.toStringAsFixed(1)}%', style: AppTextStyle.caption),
              ],
            ),
          if (info.totalMemory != null)
            _buildInfoRow('内存', DeviceSelfCheckService.formatBytes(info.totalMemory!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100.w, child: Text(label, style: AppTextStyle.caption)),
          Expanded(
            child: Text(value, style: AppTextStyle.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItemsCard() {
    if (_report == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: AppTheme.shadowColor, blurRadius: 8)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment_rounded, color: AppTheme.secondaryColor, size: 20.r),
              SizedBox(width: 8.w),
              Text('检测项详情', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          ..._report!.results.map((result) => _buildCheckItem(result)),
        ],
      ),
    );
  }

  Widget _buildCheckItem(CheckResult result) {
    final color = _getStatusColor(result.status);
    final icon = _getStatusIcon(result.status);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(result.title, style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500)),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        _getStatusText(result.status),
                        style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                if (result.message != null)
                  Text(result.message!, style: AppTextStyle.caption),
              ],
            ),
          ),
          _buildActionForCheckItem(result),
        ],
      ),
    );
  }

  Widget _buildActionForCheckItem(CheckResult result) {
    switch (result.type) {
      case CheckItemType.bluetoothOn:
        if (result.status == CheckStatus.warning || result.status == CheckStatus.error) {
          return TextButton(
            onPressed: () async {
              await _selfCheckService.turnOnBluetooth();
              await _performSelfCheck();
            },
            child: Text('开启'),
          );
        }
        return const SizedBox.shrink();
      case CheckItemType.bluetoothPermission:
      case CheckItemType.cameraPermission:
      case CheckItemType.storagePermission:
        if (result.status != CheckStatus.success) {
          return TextButton(
            onPressed: () async {
              if (result.type == CheckItemType.bluetoothPermission) {
                await _selfCheckService.requestBluetoothPermissions();
              } else if (result.type == CheckItemType.cameraPermission) {
                await _selfCheckService.requestCameraPermission();
              } else {
                await _selfCheckService.requestStoragePermission();
              }
              await _performSelfCheck();
            },
            child: Text('授权'),
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeartbeatCard() {
    final lastTime = _heartbeatService.getLastHeartbeatTime();
    final statusText = _heartbeatService.getHeartbeatStatusText();
    final isAbnormal = _heartbeatService.isDeviceAbnormal();
    final statusColor = isAbnormal
        ? AppTheme.dangerColor
        : _heartbeatService.consecutiveFailures > 0
            ? AppTheme.warningColor
            : AppTheme.successColor;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: AppTheme.shadowColor, blurRadius: 8)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, color: AppTheme.infoColor, size: 20.r),
              SizedBox(width: 8.w),
              Text('心跳状态', style: AppTextStyle.subtitle),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('最后心跳', style: AppTextStyle.caption),
                    SizedBox(height: 4.h),
                    Text(
                      lastTime != null ? DateUtil.formatDateTime(lastTime) : '从未上报',
                      style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('连续失败', style: AppTextStyle.caption),
                    SizedBox(height: 4.h),
                    Text(
                      '${_heartbeatService.consecutiveFailures}次',
                      style: AppTextStyle.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _heartbeatService.consecutiveFailures > 0
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sendHeartbeat,
                  icon: Icon(Icons.favorite_border, size: 18.r),
                  label: Text('立即上报'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogStatsCard() {
    final stats = _logStats ?? {'total': 0, 'unsynced': 0, 'info': 0, 'warning': 0, 'error': 0};
    final total = stats['total'] ?? 0;
    final unsynced = stats['unsynced'] ?? 0;
    final infoCount = stats['info'] ?? 0;
    final warningCount = stats['warning'] ?? 0;
    final errorCount = stats['error'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: AppTheme.shadowColor, blurRadius: 8)],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article_rounded, color: AppTheme.accentColor, size: 20.r),
              SizedBox(width: 8.w),
              Text('运维日志', style: AppTextStyle.subtitle),
              Spacer(),
              TextButton.icon(
                onPressed: _forceUploadLogs,
                icon: Icon(Icons.cloud_upload, size: 16.r),
                label: Text('上传', style: TextStyle(fontSize: 13.sp)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(Icons.format_list_bulleted, '总日志', total.toString(), AppTheme.infoColor),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.cloud_off,
                  '待同步',
                  unsynced.toString(),
                  unsynced > 0 ? AppTheme.warningColor : AppTheme.successColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildStatItem(Icons.info_outline, 'Info', infoCount.toString(), AppTheme.infoColor)),
              Expanded(child: _buildStatItem(Icons.warning_outlined, 'Warn', warningCount.toString(), AppTheme.warningColor)),
              Expanded(child: _buildStatItem(Icons.error_outline, 'Error', errorCount.toString(), AppTheme.dangerColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22.r),
          SizedBox(height: 6.h),
          Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 2.h),
          Text(label, style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
