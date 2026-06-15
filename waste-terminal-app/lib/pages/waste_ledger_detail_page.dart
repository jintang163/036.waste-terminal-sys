import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../providers/waste_ledger_provider.dart';
import '../models/waste_ledger.dart';
import '../widgets/status_tag.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import '../utils/date_util.dart';
import '../utils/toast_util.dart';

class WasteLedgerDetailPage extends StatefulWidget {
  final int ledgerId;

  const WasteLedgerDetailPage({super.key, required this.ledgerId});

  @override
  State<WasteLedgerDetailPage> createState() => _WasteLedgerDetailPageState();
}

class _WasteLedgerDetailPageState extends State<WasteLedgerDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RefreshController _detailRefreshController = RefreshController();
  final RefreshController _logRefreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _detailRefreshController.dispose();
    _logRefreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<WasteLedgerProvider>();
    await Future.wait([
      provider.loadDetail(widget.ledgerId),
      provider.loadDetails(widget.ledgerId),
      provider.loadReportLogs(widget.ledgerId),
    ]);
  }

  Future<void> _onDetailRefresh() async {
    try {
      await context.read<WasteLedgerProvider>().loadDetails(widget.ledgerId);
      _detailRefreshController.refreshCompleted();
    } catch (e) {
      _detailRefreshController.refreshFailed();
    }
  }

  Future<void> _onLogRefresh() async {
    try {
      await context.read<WasteLedgerProvider>().loadReportLogs(widget.ledgerId, refresh: true);
      _logRefreshController.refreshCompleted();
    } catch (e) {
      _logRefreshController.refreshFailed();
    }
  }

  Future<void> _previewLedger() async {
    final provider = context.read<WasteLedgerProvider>();
    final url = await provider.previewLedger(widget.ledgerId);
    if (url != null && mounted) {
      _launchURL(url);
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ToastUtil.showError('无法打开文件');
    }
  }

  Future<void> _regenerateLedger() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重新生成'),
        content: const Text('重新生成将覆盖现有台账数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = context.read<WasteLedgerProvider>();
      final success = await provider.regenerateLedger(widget.ledgerId);
      if (success) {
        _loadData();
      }
    }
  }

  Future<void> _reportLedger() async {
    final provider = context.read<WasteLedgerProvider>();
    final success = await provider.reportLedger(widget.ledgerId);
    if (success) {
      _loadData();
    }
  }

  Future<void> _retryReport() async {
    final provider = context.read<WasteLedgerProvider>();
    final success = await provider.retryReport(widget.ledgerId);
    if (success) {
      _loadData();
    }
  }

  Future<void> _deleteLedger() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将无法恢复，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = context.read<WasteLedgerProvider>();
      final success = await provider.deleteLedger(widget.ledgerId);
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  StatusTag _buildGenerateStatusTag(int? status) {
    switch (status) {
      case 0:
        return StatusTag.info('待生成');
      case 1:
        return StatusTag.warning('生成中');
      case 2:
        return StatusTag.success('已生成');
      case 3:
        return StatusTag.danger('生成失败');
      default:
        return StatusTag.info('未知');
    }
  }

  StatusTag _buildReportStatusTag(int? status) {
    switch (status) {
      case 0:
        return StatusTag.info('待上报');
      case 1:
        return StatusTag.warning('上报中');
      case 2:
        return StatusTag.success('已上报');
      case 3:
        return StatusTag.danger('上报失败');
      case 4:
        return StatusTag.info('无需上报');
      default:
        return StatusTag.info('未知');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('台账详情'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'preview':
                  _previewLedger();
                  break;
                case 'regenerate':
                  _regenerateLedger();
                  break;
                case 'report':
                  _reportLedger();
                  break;
                case 'retry':
                  _retryReport();
                  break;
                case 'delete':
                  _deleteLedger();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.visibility),
                    SizedBox(width: 8),
                    Text('预览台账'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('重新生成'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text('上报台账'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'retry',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt),
                    SizedBox(width: 8),
                    Text('重试上报'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '基本信息'),
            Tab(text: '台账明细'),
            Tab(text: '上报日志'),
          ],
        ),
      ),
      body: Consumer<WasteLedgerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentLedger == null) {
            return const LoadingWidget();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBasicInfoTab(provider),
              _buildDetailsTab(provider),
              _buildReportLogsTab(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBasicInfoTab(WasteLedgerProvider provider) {
    final ledger = provider.currentLedger;
    if (ledger == null) {
      return const EmptyState(message: '暂无数据');
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(ledger),
          SizedBox(height: 16.h),
          _buildStatsCard(ledger),
          SizedBox(height: 16.h),
          _buildStatusCard(ledger),
        ],
      ),
    );
  }

  Widget _buildInfoCard(WasteLedger ledger) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ledger.periodText,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  ledger.ledgerTypeText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInfoRow('台账编号', ledger.ledgerNo ?? '-'),
          _buildInfoRow('企业名称', ledger.enterpriseName ?? '-'),
          _buildInfoRow('统一社会信用代码', ledger.enterpriseCode ?? '-'),
          _buildInfoRow('统计周期', '${ledger.startDate} 至 ${ledger.endDate}'),
          _buildInfoRow('生成时间', DateUtil.formatDateTime(ledger.generateTime)),
          _buildInfoRow('备注', ledger.remark ?? '-'),
        ],
      ),
    );
  }

  Widget _buildStatsCard(WasteLedger ledger) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '统计数据',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '期初库存',
                  '${(ledger.beginInventoryWeight ?? 0).toStringAsFixed(2)}kg',
                  AppTheme.infoColor,
                ),
              ),
              Container(width: 1, height: 60.h, color: Colors.grey.shade200),
              Expanded(
                child: _buildStatItem(
                  '期末库存',
                  '${(ledger.endInventoryWeight ?? 0).toStringAsFixed(2)}kg',
                  AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '本期入库',
                  '${ledger.totalInCount ?? 0}笔\n${(ledger.totalInWeight ?? 0).toStringAsFixed(2)}kg',
                  AppTheme.successColor,
                ),
              ),
              Container(width: 1, height: 60.h, color: Colors.grey.shade200),
              Expanded(
                child: _buildStatItem(
                  '本期出库',
                  '${ledger.totalOutCount ?? 0}笔\n${(ledger.totalOutWeight ?? 0).toStringAsFixed(2)}kg',
                  AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(WasteLedger ledger) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '状态信息',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '生成状态',
                      style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: 8.h),
                    _buildGenerateStatusTag(ledger.generateStatus),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '上报状态',
                      style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: 8.h),
                    _buildReportStatusTag(ledger.reportStatus),
                  ],
                ),
              ),
            ],
          ),
          if (ledger.generateFailReason != null) ...[
            SizedBox(height: 12.h),
            _buildInfoRow('生成失败原因', ledger.generateFailReason!),
          ],
          if (ledger.reportFailReason != null) ...[
            SizedBox(height: 12.h),
            _buildInfoRow('上报失败原因', ledger.reportFailReason!),
          ],
          if (ledger.platformLedgerNo != null) ...[
            SizedBox(height: 12.h),
            _buildInfoRow('平台台账编号', ledger.platformLedgerNo!),
          ],
          if (ledger.retryCount != null) ...[
            SizedBox(height: 12.h),
            _buildInfoRow('重试次数', '${ledger.retryCount}次'),
          ],
          SizedBox(height: 16.h),
          if (ledger.fileUrl != null)
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: OutlinedButton.icon(
                onPressed: _previewLedger,
                icon: const Icon(Icons.description),
                label: Text('查看Excel文件 (${ledger.fileName ?? ''})'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTab(WasteLedgerProvider provider) {
    final details = provider.details;

    if (details.isEmpty) {
      return const EmptyState(message: '暂无明细数据');
    }

    return SmartRefresher(
      controller: _detailRefreshController,
      enablePullDown: true,
      onRefresh: _onDetailRefresh,
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: details.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final detail = details[index];
          return _buildDetailItem(detail, index + 1);
        },
      ),
    );
  }

  Widget _buildDetailItem(WasteLedgerDetail detail, int seq) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Text(
                        '$seq',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    detail.recordNo ?? '-',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: detail.detailType == 'IN'
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  detail.detailTypeText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: detail.detailType == 'IN' ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildDetailInfo('危废代码', detail.wasteCode ?? '-'),
              ),
              Expanded(
                child: _buildDetailInfo('危废名称', detail.wasteName ?? '-'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildDetailInfo('废物类别', detail.wasteCategory ?? '-'),
              ),
              Expanded(
                child: _buildDetailInfo('危险特性', detail.hazardCode ?? '-'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildDetailInfo('容器编号', detail.containerCode ?? '-'),
              ),
              Expanded(
                child: _buildDetailInfo(
                  '重量',
                  '${(detail.weight ?? 0).toStringAsFixed(2)}kg',
                  valueColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildDetailInfo('变动类型', detail.changeTypeText),
              ),
              Expanded(
                child: _buildDetailInfo('操作员', detail.operatorName ?? '-'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildDetailInfo('操作时间', DateUtil.formatDateTime(detail.operateTime)),
          if (detail.remark != null && detail.remark!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _buildDetailInfo('备注', detail.remark!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailInfo(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: valueColor != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportLogsTab(WasteLedgerProvider provider) {
    final logs = provider.reportLogs;

    if (logs.isEmpty) {
      return const EmptyState(message: '暂无上报日志');
    }

    return SmartRefresher(
      controller: _logRefreshController,
      enablePullDown: true,
      onRefresh: _onLogRefresh,
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: logs.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final log = logs[index];
          return _buildLogItem(log);
        },
      ),
    );
  }

  Widget _buildLogItem(WasteLedgerReportLog log) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    log.reportStatus == 1 ? Icons.check_circle : Icons.error,
                    color: log.reportStatus == 1 ? AppTheme.successColor : AppTheme.dangerColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    log.reportTypeText,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: log.reportStatus == 1
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  log.reportStatusText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: log.reportStatus == 1 ? AppTheme.successColor : AppTheme.dangerColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildLogInfo('日志编号', log.logNo ?? '-'),
          _buildLogInfo('上报时间', DateUtil.formatDateTime(log.reportTime)),
          if (log.durationMs != null)
            _buildLogInfo('耗时', '${log.durationMs}ms'),
          if (log.platformLedgerNo != null)
            _buildLogInfo('平台编号', log.platformLedgerNo!),
          if (log.operatorName != null)
            _buildLogInfo('操作人', log.operatorName!),
          if (log.failReason != null && log.failReason!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '失败原因',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    log.failReason!,
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.dangerColor),
                  ),
                ],
              ),
            ),
          ],
          if (log.requestPayload != null && log.requestPayload!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ExpansionTile(
              title: Text(
                '请求报文',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  color: Colors.grey.shade50,
                  child: Text(
                    log.requestPayload!,
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          if (log.responsePayload != null && log.responsePayload!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ExpansionTile(
              title: Text(
                '响应报文',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  color: Colors.grey.shade50,
                  child: Text(
                    log.responsePayload!,
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogInfo(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
