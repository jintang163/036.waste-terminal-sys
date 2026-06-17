import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../providers/dashboard_cockpit_provider.dart';
import '../services/dashboard_cockpit_service.dart';
import '../widgets/empty_state.dart';

class DashboardCockpitPage extends StatefulWidget {
  const DashboardCockpitPage({super.key});

  @override
  State<DashboardCockpitPage> createState() => _DashboardCockpitPageState();
}

class _DashboardCockpitPageState extends State<DashboardCockpitPage> {
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCockpitProvider>().init();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      await context.read<DashboardCockpitProvider>().refresh();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据分析驾驶舱'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Consumer<DashboardCockpitProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.overview == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            header: WaterDropHeader(
              waterDropColor: AppTheme.primaryColor,
            ),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _buildProductionPointSelector(provider),
                SizedBox(height: 16.h),
                _buildOverviewCards(provider),
                SizedBox(height: 16.h),
                _buildInboundTrendChart(provider),
                SizedBox(height: 16.h),
                _buildCategoryPieChart(provider),
                SizedBox(height: 16.h),
                _buildWarningSection(provider),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductionPointSelector(DashboardCockpitProvider provider) {
    final points = provider.productionPoints;
    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20.r, color: AppTheme.primaryColor),
          SizedBox(width: 8.w),
          Text('产废点:', style: AppTextStyle.body),
          SizedBox(width: 8.w),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.selectedPointIndex,
                isDense: true,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, size: 24.r),
                style: AppTextStyle.body.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                items: points.asMap().entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(
                      entry.value.name,
                      style: AppTextStyle.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (index) {
                  if (index != null) {
                    provider.switchProductionPoint(index);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(DashboardCockpitProvider provider) {
    final overview = provider.overview;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                title: '本月入库',
                value: '${overview?.totalInboundCount ?? 0}',
                unit: '次',
                icon: Icons.arrow_circle_down,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _OverviewCard(
                title: '入库总量',
                value: (overview?.totalInboundWeight ?? 0).toStringAsFixed(1),
                unit: 'kg',
                icon: Icons.scale,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                title: '预警数量',
                value: '${overview?.totalWarningCount ?? 0}',
                unit: '条',
                icon: Icons.warning_amber,
                color: AppTheme.warningColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _OverviewCard(
                title: '危废类别',
                value: '${overview?.totalCategoryCount ?? 0}',
                unit: '种',
                icon: Icons.category,
                color: const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInboundTrendChart(DashboardCockpitProvider provider) {
    final trend = provider.dailyTrend;
    if (trend.isEmpty) {
      return _buildChartCard(
        '本月入库趋势',
        EmptyState(icon: Icons.show_chart, message: '暂无入库趋势数据'),
      );
    }

    final spots = <FlSpot>[];
    double maxWeight = 0;
    for (int i = 0; i < trend.length; i++) {
      final weight = trend[i].weight;
      if (weight > maxWeight) maxWeight = weight;
      spots.add(FlSpot(i.toDouble(), weight));
    }
    if (maxWeight == 0) maxWeight = 10;

    return _buildChartCard(
      '本月入库趋势',
      SizedBox(
        height: 200.h,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxWeight / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.dividerColor,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28.h,
                  interval: 5,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= trend.length) {
                      return const SizedBox.shrink();
                    }
                    final date = trend[idx].date;
                    final label = date.length >= 10
                        ? date.substring(5)
                        : date;
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 10.sp, color: AppTheme.textSecondary),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40.w,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value >= 1000
                          ? '${(value / 1000).toStringAsFixed(1)}k'
                          : value.toStringAsFixed(0),
                      style: TextStyle(fontSize: 10.sp, color: AppTheme.textSecondary),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (trend.length - 1).toDouble(),
            minY: 0,
            maxY: maxWeight * 1.2,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                color: AppTheme.primaryColor,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: trend.length <= 10,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3.r,
                      color: AppTheme.primaryColor,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.25),
                      AppTheme.primaryColor.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 8.r,
                tooltipBgColor: AppTheme.primaryColor.withOpacity(0.9),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.spotIndex;
                    final date = idx < trend.length ? trend[idx].date : '';
                    final count = idx < trend.length ? trend[idx].count : 0;
                    return LineTooltipItem(
                      '$date\n重量: ${spot.y.toStringAsFixed(1)} kg\n次数: $count',
                      TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList();
                },
              ),
              handleBuiltInTouches: true,
            ),
          ),
        ),
      ),
      onTap: () => _showTrendDetail(provider),
    );
  }

  Widget _buildCategoryPieChart(DashboardCockpitProvider provider) {
    final categories = provider.categoryProportion;
    if (categories.isEmpty) {
      return _buildChartCard(
        '危废类别占比',
        EmptyState(icon: Icons.pie_chart, message: '暂无类别占比数据'),
      );
    }

    final totalWeight =
        categories.fold<double>(0, (sum, c) => sum + c.weight);
    if (totalWeight == 0) {
      return _buildChartCard(
        '危废类别占比',
        EmptyState(icon: Icons.pie_chart, message: '暂无类别占比数据'),
      );
    }

    final chartColors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.warningColor,
      AppTheme.dangerColor,
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
      const Color(0xFFE91E63),
      const Color(0xFF607D8B),
    ];

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < categories.length && i < 10; i++) {
      final cat = categories[i];
      final percent = (cat.weight / totalWeight) * 100;
      final color = chartColors[i % chartColors.length];

      sections.add(PieChartSectionData(
        value: cat.weight,
        title: percent >= 5 ? '${percent.toStringAsFixed(1)}%' : '',
        color: color,
        radius: percent >= 5 ? 50.r : 35.r,
        titleStyle: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return _buildChartCard(
      '危废类别占比',
      Column(
        children: [
          SizedBox(
            height: 180.h,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40.r,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                    if (event is FlTapUpEvent && response != null && response.touchedSection != null) {
                      final idx = response.touchedSection!.touchedSectionIndex;
                      if (idx < categories.length) {
                        _showCategoryDetail(provider, categories[idx]);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 8.h,
            children: categories.take(10).toList().asMap().entries.map((entry) {
              final color = chartColors[entry.key % chartColors.length];
              final cat = entry.value;
              return GestureDetector(
                onTap: () => _showCategoryDetail(provider, cat),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10.r,
                      height: 10.r,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        '${cat.category}(${cat.weight.toStringAsFixed(1)}kg)',
                        style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningSection(DashboardCockpitProvider provider) {
    final stat = provider.warningStat;
    if (stat == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.r),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('本月预警', style: AppTextStyle.subtitle),
              if (stat.unhandled > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                  ),
                  child: Text(
                    '${stat.unhandled}条未处理',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildWarningLevelItem(
                  '一般',
                  stat.level1Count,
                  AppTheme.infoColor,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildWarningLevelItem(
                  '较重',
                  stat.level2Count,
                  AppTheme.warningColor,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildWarningLevelItem(
                  '严重',
                  stat.level3Count,
                  AppTheme.dangerColor,
                ),
              ),
            ],
          ),
          if (stat.recentWarnings.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Divider(color: AppTheme.dividerColor, height: 1),
            SizedBox(height: 12.h),
            Text('最近预警', style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500)),
            SizedBox(height: 8.h),
            ...stat.recentWarnings.take(3).map((w) => _buildWarningItem(w)),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningLevelItem(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(Map<String, dynamic> warning) {
    final level = warning['warning_level'] as int? ?? 1;
    Color levelColor;
    String levelText;
    switch (level) {
      case 3:
        levelColor = AppTheme.dangerColor;
        levelText = '严重';
        break;
      case 2:
        levelColor = AppTheme.warningColor;
        levelText = '较重';
        break;
      default:
        levelColor = AppTheme.infoColor;
        levelText = '一般';
    }

    final status = warning['status'] as int? ?? 0;
    final handled = status >= 2;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(
          color: levelColor.withOpacity(handled ? 0.1 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8.r,
            height: 8.r,
            decoration: BoxDecoration(
              color: handled ? AppTheme.successColor : levelColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning['warning_title'] ?? warning['warning_content'] ?? '',
                  style: AppTextStyle.body.copyWith(
                    decoration: handled ? TextDecoration.lineThrough : null,
                    color: handled ? AppTheme.textHint : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  warning['warning_time'] ?? '',
                  style: AppTextStyle.small,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.r4),
            ),
            child: Text(
              levelText,
              style: TextStyle(fontSize: 10.sp, color: levelColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget child, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTextStyle.subtitle),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 20.r, color: AppTheme.textHint),
              ],
            ),
            SizedBox(height: 12.h),
            child,
          ],
        ),
      ),
    );
  }

  void _showTrendDetail(DashboardCockpitProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _TrendDetailSheet(
          provider: provider,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showCategoryDetail(
      DashboardCockpitProvider provider, CategoryProportion category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _CategoryDetailSheet(
          provider: provider,
          category: category,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: Icon(icon, size: 22.r, color: color),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary)),
                SizedBox(height: 4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(unit, style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendDetailSheet extends StatelessWidget {
  final DashboardCockpitProvider provider;
  final ScrollController scrollController;

  const _TrendDetailSheet({
    required this.provider,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final trend = provider.dailyTrend;
    final activeDays = trend.where((d) => d.count > 0).toList();

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('入库趋势明细', style: AppTextStyle.subtitle),
              Text('共${activeDays.length}天有入库记录', style: AppTextStyle.caption),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: activeDays.isEmpty
              ? EmptyState(icon: Icons.inbox_outlined, message: '暂无入库记录')
              : ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: activeDays.length,
                  itemBuilder: (context, index) {
                    final day = activeDays[index];
                    return _TrendDayItem(
                      day: day,
                      onTap: () async {
                        final details = await provider.getInboundDetailsByDate(day.date);
                        if (context.mounted && details.isNotEmpty) {
                          _showDayRecords(context, day.date, details);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showDayRecords(
      BuildContext context, String date, List<Map<String, dynamic>> records) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$date 入库明细', style: AppTextStyle.subtitle),
                  Text('${records.length}条记录', style: AppTextStyle.caption),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final r = records[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r['waste_name'] ?? '未知危废',
                                style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(r['weight'] as num?)?.toDouble().toStringAsFixed(2) ?? '0'} kg',
                              style: AppTextStyle.body.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Text(
                              r['waste_code'] ?? '',
                              style: AppTextStyle.caption,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              r['waste_category'] ?? '',
                              style: AppTextStyle.caption,
                            ),
                          ],
                        ),
                        if (r['container_code'] != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            '容器: ${r['container_code']}',
                            style: AppTextStyle.small,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendDayItem extends StatelessWidget {
  final DailyInboundStat day;
  final VoidCallback onTap;

  const _TrendDayItem({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.date, style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500)),
                  SizedBox(height: 4.h),
                  Text('${day.count}次入库', style: AppTextStyle.caption),
                ],
              ),
            ),
            Text(
              '${day.weight.toStringAsFixed(2)} kg',
              style: AppTextStyle.subtitle.copyWith(color: AppTheme.primaryColor),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right, size: 20.r, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}

class _CategoryDetailSheet extends StatelessWidget {
  final DashboardCockpitProvider provider;
  final CategoryProportion category;
  final ScrollController scrollController;

  const _CategoryDetailSheet({
    required this.provider,
    required this.category,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${category.category} 入库明细', style: AppTextStyle.subtitle),
              SizedBox(height: 4.h),
              Text(
                '共${category.count}次，总量${category.weight.toStringAsFixed(2)}kg',
                style: AppTextStyle.caption,
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: provider.getInboundDetailsByCategory(category.category),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return EmptyState(icon: Icons.inbox_outlined, message: '暂无记录');
              }
              return ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final r = records[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r['waste_name'] ?? '未知危废',
                                style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(r['weight'] as num?)?.toDouble().toStringAsFixed(2) ?? '0'} kg',
                              style: AppTextStyle.body.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Text(r['waste_code'] ?? '', style: AppTextStyle.caption),
                            SizedBox(width: 12.w),
                            if (r['in_time'] != null)
                              Text(r['in_time'], style: AppTextStyle.small),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
