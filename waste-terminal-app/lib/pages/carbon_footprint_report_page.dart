import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../models/carbon_footprint_record.dart';
import '../providers/carbon_footprint_provider.dart';
import '../services/carbon_footprint_service.dart';
import '../utils/date_util.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_card.dart';

class CarbonFootprintReportPage extends StatefulWidget {
  const CarbonFootprintReportPage({super.key});

  @override
  State<CarbonFootprintReportPage> createState() =>
      _CarbonFootprintReportPageState();
}

class _CarbonFootprintReportPageState extends State<CarbonFootprintReportPage>
    with SingleTickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController();
  late TabController _tabController;

  int _selectedTimeRange = 0;
  final List<String> _timeRanges = ['今日', '本周', '本月', '全部'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<CarbonFootprintProvider>();
    await Future.wait([
      provider.loadStatistics(
        startTime: _getStartTime(),
        endTime: _getEndTime(),
      ),
      provider.loadRecords(refresh: true),
    ]);
  }

  DateTime? _getStartTime() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case 0:
        return DateTime(now.year, now.month, now.day);
      case 1:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case 2:
        return DateTime(now.year, now.month, 1);
      case 3:
      default:
        return null;
    }
  }

  DateTime? _getEndTime() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case 0:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case 1:
      case 2:
      case 3:
      default:
        return null;
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadData();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _onLoading() async {
    try {
      await context.read<CarbonFootprintProvider>().loadRecords();
      _refreshController.loadComplete();
    } catch (e) {
      _refreshController.loadFailed();
    }
  }

  void _onTimeRangeChanged(int index) {
    setState(() {
      _selectedTimeRange = index;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('碳足迹报告'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '统计概览'),
            Tab(text: '记录明细'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatisticsTab(),
          _buildRecordsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.carbonFootprintCalc);
        },
        icon: const Icon(Icons.add),
        label: const Text('新建计算'),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return Consumer<CarbonFootprintProvider>(
      builder: (context, provider, child) {
        return SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildTimeRangeSelector(),
              SizedBox(height: 16.h),
              _buildSummaryCard(provider),
              SizedBox(height: 16.h),
              _buildEmissionBreakdownCard(provider),
              SizedBox(height: 16.h),
              _buildCategoryStatsCard(provider),
              SizedBox(height: 80.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: List.generate(_timeRanges.length, (index) {
          final isSelected = _selectedTimeRange == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTimeRangeChanged(index),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Text(
                  _timeRanges[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSummaryCard(CarbonFootprintProvider provider) {
    final totalEmission = provider.totalEmission ?? 0;
    final recordCount = provider.recordCount;
    final totalWeight = provider.totalWeight ?? 0;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 28.r, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                '总碳排放量',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            totalEmission.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'kg CO₂e',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '记录数',
                  '$recordCount 笔',
                  Icons.description,
                ),
              ),
              Container(
                width: 1,
                height: 36.h,
                color: Colors.white24,
              ),
              Expanded(
                child: _buildSummaryItem(
                  '危废重量',
                  '${totalWeight.toStringAsFixed(1)} kg',
                  Icons.line_weight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20.r, color: Colors.white70),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildEmissionBreakdownCard(CarbonFootprintProvider provider) {
    final transportEmission = provider.transportEmission ?? 0;
    final disposalEmission = provider.disposalEmission ?? 0;
    final totalEmission = provider.totalEmission ?? 0;

    final transportPercent = totalEmission > 0
        ? (transportEmission / totalEmission * 100)
        : 0.0;
    final disposalPercent = totalEmission > 0
        ? (disposalEmission / totalEmission * 100)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('排放构成', style: AppTextStyle.subtitle),
          SizedBox(height: 16.h),
          _buildBreakdownItem(
            icon: Icons.local_shipping,
            label: '运输排放',
            value: transportEmission,
            percent: transportPercent,
            color: AppTheme.infoColor,
          ),
          SizedBox(height: 12.h),
          _buildBreakdownItem(
            icon: Icons.local_fire_department,
            label: '处置排放',
            value: disposalEmission,
            percent: disposalPercent,
            color: AppTheme.dangerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem({
    required IconData icon,
    required String label,
    required double value,
    required double percent,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Icon(icon, size: 18.r, color: color),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: AppTextStyle.body,
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} kg',
              style: AppTextStyle.subtitle.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: AppTheme.bgPrimary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.h,
          ),
        ),
        SizedBox(height: 4.h),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${percent.toStringAsFixed(1)}%',
            style: AppTextStyle.caption,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStatsCard(CarbonFootprintProvider provider) {
    final categoryStats = provider.categoryStats;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('分类排放统计', style: AppTextStyle.subtitle),
              Text(
                '共 ${categoryStats.length} 类',
                style: AppTextStyle.caption,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (categoryStats.isEmpty)
            const EmptyState(
              icon: Icons.bar_chart,
              message: '暂无分类统计数据',
            )
          else
            ...categoryStats.take(5).map((stat) {
              final category = stat['waste_category'] as String? ?? '未知';
              final emission = (stat['total_emission'] as num?)?.toDouble() ?? 0;
              final categoryName =
                  CarbonFootprintService.getWasteCategoryName(category);
              final totalEmission = provider.totalEmission ?? 1;
              final percent = totalEmission > 0
                  ? (emission / totalEmission * 100)
                  : 0.0;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _buildCategoryItem(
                  category: category,
                  categoryName: categoryName,
                  emission: emission,
                  percent: percent,
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required String category,
    required String categoryName,
    required double emission,
    required double percent,
  }) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: _getCategoryColor(category),
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$category - $categoryName',
                style: AppTextStyle.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(3.r),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: AppTheme.bgPrimary,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCategoryColor(category),
                  ),
                  minHeight: 4.h,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${emission.toStringAsFixed(1)} kg',
              style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: AppTextStyle.caption,
            ),
          ],
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.dangerColor,
      AppTheme.infoColor,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];
    final index = category.hashCode % colors.length;
    return colors[index];
  }

  Widget _buildRecordsTab() {
    return Consumer<CarbonFootprintProvider>(
      builder: (context, provider, child) {
        final records = provider.records;

        return SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          onLoading: _onLoading,
          enablePullUp: provider.hasMore,
          child: records.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.history,
                    message: '暂无计算记录',
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _buildRecordItem(record);
                  },
                ),
        );
      },
    );
  }

  Widget _buildRecordItem(CarbonFootprintRecord record) {
    final provider = context.read<CarbonFootprintProvider>();
    final isSynced = record.syncStatus == 1;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.r6),
                ),
                child: Text(
                  record.wasteCategory ?? '未知',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  record.wasteName ??
                      provider.getWasteCategoryName(
                          record.wasteCategory ?? '未知'),
                  style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSynced
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Text(
                  isSynced ? '已同步' : '未同步',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isSynced
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _buildRecordInfoItem(
                icon: Icons.line_weight,
                label: '重量',
                value: '${record.weight?.toStringAsFixed(1) ?? '0'} kg',
              ),
              SizedBox(width: 16.w),
              _buildRecordInfoItem(
                icon: Icons.route,
                label: '距离',
                value: '${record.transportDistance?.toStringAsFixed(1) ?? '0'} km',
              ),
              SizedBox(width: 16.w),
              _buildRecordInfoItem(
                icon: Icons.local_shipping,
                label: '运输',
                value: provider
                    .getTransportModeName(record.transportMode ?? 'truck'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildRecordInfoItem(
                icon: Icons.local_fire_department,
                label: '处置',
                value: provider.getDisposalMethodName(
                    record.disposalMethod ?? 'incineration'),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: AppTheme.dividerColor, height: 1),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '总排放量',
                    style: AppTextStyle.caption,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${record.totalEmission?.toStringAsFixed(2) ?? '0'} kg CO₂e',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                record.recordTime != null
                    ? _formatDateTime(record.recordTime!)
                    : '',
                style: AppTextStyle.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: AppTheme.textSecondary),
        SizedBox(width: 4.w),
        Text(
          '$label: $value',
          style: AppTextStyle.small,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
