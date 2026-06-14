import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../utils/toast_util.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_tag.dart';

class PlatformReportRecord {
  final int? id;
  final String? reportNo;
  final String? bizType;
  final String? bizNo;
  final String? apiPath;
  final int? reportStatus;
  final int? retryCount;
  final int? maxRetryCount;
  final String? lastReportTime;
  final String? nextRetryTime;
  final String? failReason;
  final String? nationalBizNo;
  final String? requestPayload;
  final String? enterpriseId;

  PlatformReportRecord({
    this.id,
    this.reportNo,
    this.bizType,
    this.bizNo,
    this.apiPath,
    this.reportStatus,
    this.retryCount,
    this.maxRetryCount,
    this.lastReportTime,
    this.nextRetryTime,
    this.failReason,
    this.nationalBizNo,
    this.requestPayload,
    this.enterpriseId,
  });

  factory PlatformReportRecord.fromJson(Map<String, dynamic> json) {
    return PlatformReportRecord(
      id: json['id'] as int?,
      reportNo: json['reportNo'] as String?,
      bizType: json['bizType'] as String?,
      bizNo: json['bizNo'] as String?,
      apiPath: json['apiPath'] as String?,
      reportStatus: json['reportStatus'] as int?,
      retryCount: json['retryCount'] as int?,
      maxRetryCount: json['maxRetryCount'] as int?,
      lastReportTime: json['lastReportTime'] as String?,
      nextRetryTime: json['nextRetryTime'] as String?,
      failReason: json['failReason'] as String?,
      nationalBizNo: json['nationalBizNo'] as String?,
      requestPayload: json['requestPayload'] as String?,
      enterpriseId: json['enterpriseId']?.toString(),
    );
  }
}

class ReportStatistics {
  final int totalReports;
  final int successCount;
  final int failCount;
  final int pendingCount;
  final int retryingCount;
  final double successRate;
  final String? lastSuccessTime;
  final String? lastReportTime;

  ReportStatistics({
    this.totalReports = 0,
    this.successCount = 0,
    this.failCount = 0,
    this.pendingCount = 0,
    this.retryingCount = 0,
    this.successRate = 0,
    this.lastSuccessTime,
    this.lastReportTime,
  });

  factory ReportStatistics.fromJson(Map<String, dynamic> json) {
    return ReportStatistics(
      totalReports: (json['totalReports'] as num?)?.toInt() ?? 0,
      successCount: (json['successCount'] as num?)?.toInt() ?? 0,
      failCount: (json['failCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      retryingCount: (json['retryingCount'] as num?)?.toInt() ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0,
      lastSuccessTime: json['lastSuccessTime'] as String?,
      lastReportTime: json['lastReportTime'] as String?,
    );
  }
}

class PlatformReportDashboard {
  final ReportStatistics? statistics;
  final List<PlatformReportRecord> recentReports;
  final List<PlatformReportRecord> failedReports;
  final List<PlatformReportRecord> retryQueue;

  PlatformReportDashboard({
    this.statistics,
    this.recentReports = const [],
    this.failedReports = const [],
    this.retryQueue = const [],
  });

  factory PlatformReportDashboard.fromJson(Map<String, dynamic> json) {
    return PlatformReportDashboard(
      statistics: json['statistics'] != null
          ? ReportStatistics.fromJson(json['statistics'] as Map<String, dynamic>)
          : null,
      recentReports: (json['recentReports'] as List?)
              ?.map((e) => PlatformReportRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      failedReports: (json['failedReports'] as List?)
              ?.map((e) => PlatformReportRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      retryQueue: (json['retryQueue'] as List?)
              ?.map((e) => PlatformReportRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ManualRetryResult {
  final int? id;
  final bool? success;
  final String? message;
  final String? nationalBizNo;

  ManualRetryResult({this.id, this.success, this.message, this.nationalBizNo});

  factory ManualRetryResult.fromJson(Map<String, dynamic> json) {
    return ManualRetryResult(
      id: json['id'] as int?,
      success: json['success'] as bool?,
      message: json['message'] as String?,
      nationalBizNo: json['nationalBizNo'] as String?,
    );
  }
}

class PlatformReportDashboardPage extends StatefulWidget {
  const PlatformReportDashboardPage({super.key});

  @override
  State<PlatformReportDashboardPage> createState() =>
      _PlatformReportDashboardPageState();
}

class _PlatformReportDashboardPageState
    extends State<PlatformReportDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PlatformReportDashboard? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ApiService();
      final response = await api.get(ApiConstants.platformReportDashboard);
      final data = response.data['data'] as Map<String, dynamic>;
      setState(() {
        _dashboard = PlatformReportDashboard.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleManualRetry(int recordId) async {
    try {
      final api = ApiService();
      final response = await api.post(
        '${ApiConstants.platformReportManualRetry}/$recordId',
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final result = ManualRetryResult.fromJson(data ?? {});
      if (result.success == true) {
        if (mounted) {
          ToastUtil.showSuccess('补报成功${result.nationalBizNo != null ? "，平台编号: ${result.nationalBizNo}" : ""}');
        }
        _loadDashboard();
      } else {
        if (mounted) {
          ToastUtil.showError(result.message ?? '补报失败');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showError('补报请求失败');
      }
    }
  }

  Future<void> _handleBatchRetry(List<int> ids) async {
    try {
      final api = ApiService();
      final response = await api.post(
        ApiConstants.platformReportBatchRetry,
        data: ids,
      );
      final results = response.data['data'] as List? ?? [];
      int successCount = 0;
      for (var r in results) {
        if (r is Map<String, dynamic> && r['success'] == true) {
          successCount++;
        }
      }
      if (mounted) {
        ToastUtil.showSuccess('批量补报完成: $successCount/${ids.length} 成功');
      }
      _loadDashboard();
    } catch (e) {
      if (mounted) {
        ToastUtil.showError('批量补报失败');
      }
    }
  }

  void _showRetryConfirmDialog(int recordId, String bizNo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认补报', style: AppTextStyle.title),
        content: Text('确定要手工补报记录 $bizNo 吗？', style: AppTextStyle.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleManualRetry(recordId);
            },
            child: Text('确认补报'),
          ),
        ],
      ),
    );
  }

  void _showBatchRetryConfirmDialog() {
    final failedRecords = _dashboard?.failedReports ?? [];
    final retryableIds = failedRecords
        .where((r) => (r.retryCount ?? 0) < (r.maxRetryCount ?? 3))
        .map((r) => r.id!)
        .toList();
    if (retryableIds.isEmpty) {
      ToastUtil.showShort('没有可补报的记录');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('批量补报', style: AppTextStyle.title),
        content: Text('确定要批量补报 ${retryableIds.length} 条失败记录吗？', style: AppTextStyle.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleBatchRetry(retryableIds);
            },
            child: Text('确认补报'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('国家平台上报'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '失败记录'),
            Tab(text: '重试队列'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildFailedTab(),
                    _buildRetryQueueTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48.r, color: AppTheme.dangerColor),
          SizedBox(height: 16.h),
          Text('加载失败', style: AppTextStyle.subtitle),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              _errorMessage ?? '',
              style: AppTextStyle.caption,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadDashboard,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _dashboard?.statistics;
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildSuccessRateCard(stats),
          SizedBox(height: 12.h),
          _buildStatsGrid(stats),
          SizedBox(height: 12.h),
          _buildRecentReportsSection(),
        ],
      ),
    );
  }

  Widget _buildSuccessRateCard(ReportStatistics? stats) {
    final rate = stats?.successRate ?? 0;
    final color = rate >= 95
        ? AppTheme.successColor
        : rate >= 80
            ? AppTheme.warningColor
            : AppTheme.dangerColor;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.9), color],
        ),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '上报成功率',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rate.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 20.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('总上报', '${stats?.totalReports ?? 0}'),
              _buildMiniStat('成功', '${stats?.successCount ?? 0}'),
              _buildMiniStat('失败', '${stats?.failCount ?? 0}'),
              _buildMiniStat('重试中', '${stats?.retryingCount ?? 0}'),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, size: 14.r, color: Colors.white.withOpacity(0.7)),
              SizedBox(width: 4.w),
              Text(
                '最近上报: ${stats?.lastReportTime ?? "暂无"}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ReportStatistics? stats) {
    return Row(
      children: [
        Expanded(
          child: StatCard.success(
            title: '上报成功',
            value: '${stats?.successCount ?? 0}',
            icon: Icons.check_circle_outline,
            subtitle: stats?.lastSuccessTime != null
                ? '最近: ${stats!.lastSuccessTime}'
                : null,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: StatCard.danger(
            title: '上报失败',
            value: '${stats?.failCount ?? 0}',
            icon: Icons.error_outline,
            subtitle: stats!.failCount > 0 ? '点击查看详情' : null,
            onTap: stats!.failCount > 0
                ? () => _tabController.animateTo(1)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentReportsSection() {
    final reports = _dashboard?.recentReports ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最近上报记录', style: AppTextStyle.subtitle),
            Text(
              '共 ${reports.length} 条',
              style: AppTextStyle.caption,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        if (reports.isEmpty)
          EmptyState(icon: Icons.inbox_outlined, message: '暂无上报记录')
        else
          ...reports.map((r) => _buildReportItem(r)),
      ],
    );
  }

  Widget _buildReportItem(PlatformReportRecord record) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(
          color: record.reportStatus == 1
              ? AppTheme.successColor.withOpacity(0.3)
              : record.reportStatus == 2
                  ? AppTheme.dangerColor.withOpacity(0.3)
                  : AppTheme.warningColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(record.reportStatus ?? 0),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _bizTypeLabel(record.bizType),
                      style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        record.bizNo ?? '-',
                        style: AppTextStyle.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    if (record.nationalBizNo != null) ...[
                      Text(
                        '平台编号: ${record.nationalBizNo}',
                        style: TextStyle(fontSize: 11.sp, color: AppTheme.successColor),
                      ),
                      SizedBox(width: 12.w),
                    ],
                    Expanded(
                      child: Text(
                        record.lastReportTime ?? '-',
                        style: AppTextStyle.small,
                      ),
                    ),
                    if (record.retryCount != null && record.retryCount! > 0)
                      Text(
                        '重试${record.retryCount}次',
                        style: TextStyle(fontSize: 11.sp, color: AppTheme.warningColor),
                      ),
                  ],
                ),
                if (record.failReason != null && record.failReason!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '原因: ${record.failReason}',
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.dangerColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(int status) {
    IconData icon;
    Color color;
    switch (status) {
      case 1:
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case 2:
        icon = Icons.cancel;
        color = AppTheme.dangerColor;
        break;
      case 3:
        icon = Icons.autorenew;
        color = AppTheme.warningColor;
        break;
      default:
        icon = Icons.schedule;
        color = AppTheme.infoColor;
    }
    return Icon(icon, size: 24.r, color: color);
  }

  Widget _buildFailedTab() {
    final failedRecords = _dashboard?.failedReports ?? [];
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: Column(
        children: [
          if (failedRecords.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12.w),
              color: AppTheme.dangerColor.withOpacity(0.05),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 20.r, color: AppTheme.dangerColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '${failedRecords.length} 条上报失败记录',
                      style: AppTextStyle.body.copyWith(color: AppTheme.dangerColor),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showBatchRetryConfirmDialog(),
                    child: Text('批量补报'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: failedRecords.isEmpty
                ? EmptyState(icon: Icons.check_circle_outline, message: '没有失败记录')
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: failedRecords.length,
                    itemBuilder: (context, index) {
                      final record = failedRecords[index];
                      return _buildFailedItem(record);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedItem(PlatformReportRecord record) {
    final canRetry = (record.retryCount ?? 0) < (record.maxRetryCount ?? 3);
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(record.reportStatus ?? 0),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${_bizTypeLabel(record.bizType)} - ${record.bizNo ?? "-"}',
                  style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              StatusTag.danger(
                '第${record.retryCount}/${record.maxRetryCount}次',
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppRadius.r4),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14.r, color: AppTheme.dangerColor),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    record.failReason ?? '未知错误',
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.dangerColor),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  '上报时间: ${record.lastReportTime ?? "-"}',
                  style: AppTextStyle.small,
                ),
              ),
              if (canRetry)
                SizedBox(
                  height: 32.h,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRetryConfirmDialog(record.id!, record.bizNo ?? ''),
                    icon: Icon(Icons.refresh, size: 16.r),
                    label: Text('手工补报', style: TextStyle(fontSize: 12.sp)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetryQueueTab() {
    final retryRecords = _dashboard?.retryQueue ?? [];
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: retryRecords.isEmpty
          ? EmptyState(icon: Icons.done_all, message: '重试队列为空')
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: retryRecords.length,
              itemBuilder: (context, index) {
                final record = retryRecords[index];
                return _buildRetryQueueItem(record);
              },
            ),
    );
  }

  Widget _buildRetryQueueItem(PlatformReportRecord record) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.autorenew, size: 20.r, color: AppTheme.warningColor),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${_bizTypeLabel(record.bizType)} - ${record.bizNo ?? "-"}',
                  style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              StatusTag.warning(
                '重试${record.retryCount}/${record.maxRetryCount}',
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.schedule, size: 14.r, color: AppTheme.textSecondary),
              SizedBox(width: 4.w),
              Text(
                '下次重试: ${record.nextRetryTime ?? "待定"}',
                style: AppTextStyle.caption,
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  '上次失败: ${record.lastReportTime ?? "-"}',
                  style: AppTextStyle.small,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (record.failReason != null && record.failReason!.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              '失败原因: ${record.failReason}',
              style: TextStyle(fontSize: 11.sp, color: AppTheme.dangerColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _bizTypeLabel(String? bizType) {
    switch (bizType) {
      case 'WASTE_IN':
        return '入库上报';
      case 'WASTE_OUT':
        return '出库上报';
      case 'TRANSFER_ORDER':
        return '电子联单';
      case 'TRANSFER_COMPLETE':
        return '联单完成';
      default:
        return bizType ?? '未知';
    }
  }
}
