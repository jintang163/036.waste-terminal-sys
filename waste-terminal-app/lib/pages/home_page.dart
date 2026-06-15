import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/app_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/warning_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_tag.dart';
import '../models/waste_inventory.dart';
import '../models/warning_record.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        context.read<InventoryProvider>().loadStatistics(),
        context.read<WarningProvider>().loadUnhandledList(),
      ]);
    } catch (e) {
      // 静默失败，使用本地缓存数据
    }
  }

  Future<void> _onRefresh() async {
    try {
      if (context.read<AppProvider>().isOnline) {
        await context.read<SyncProvider>().syncAll();
      }
      await _loadData();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        header: WaterDropHeader(
          waterDropColor: AppTheme.primaryColor,
        ),
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildHeader(),
            SizedBox(height: 16.h),
            _buildNetworkStatus(),
            SizedBox(height: 16.h),
            _buildStatCards(),
            SizedBox(height: 20.h),
            _buildQuickActions(),
            SizedBox(height: 20.h),
            _buildWarningSection(),
            SizedBox(height: 20.h),
            _buildRecentInventorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final appProvider = context.watch<AppProvider>();
    return Row(
      children: [
        Container(
          width: 48.r,
          height: 48.r,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.recycling,
            size: 28.r,
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appProvider.enterpriseName ?? '危废智能终端系统',
                style: AppTextStyle.title,
              ),
              SizedBox(height: 2.h),
              Text(
                '欢迎回来，${appProvider.username ?? '操作员'}',
                style: AppTextStyle.bodySecondary,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.warning);
          },
          icon: Stack(
            children: [
              Icon(Icons.notifications_outlined, size: 28.r),
              Positioned(
                right: 0,
                top: 0,
                child: Consumer<WarningProvider>(
                  builder: (context, provider, child) {
                    final count = provider.unhandledCount;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16.w,
                        minHeight: 16.h,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkStatus() {
    final appProvider = context.watch<AppProvider>();
    final isOnline = appProvider.isOnline;
    final syncProvider = context.watch<SyncProvider>();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isOnline
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 20.r,
            color: isOnline ? AppTheme.successColor : AppTheme.warningColor,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? '网络连接正常' : '当前处于离线模式',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isOnline
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
                if (!isOnline)
                  Text(
                    '数据将暂存本地，恢复网络后自动同步',
                    style: AppTextStyle.caption,
                  ),
              ],
            ),
          ),
          if (syncProvider.isSyncing)
            SizedBox(
              width: 16.w,
              height: 16.h,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: '总库存量',
                    value: '${provider.totalWeight?.toStringAsFixed(2) ?? '0.00'}',
                    unit: 'kg',
                    icon: Icons.inventory_2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: StatCard(
                    title: '容器数量',
                    value: '${provider.containerCount ?? 0}',
                    unit: '个',
                    icon: Icons.inventory,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: '即将超期',
                    value: '${provider.nearExpiryCount ?? 0}',
                    unit: '项',
                    icon: Icons.warning_amber,
                    color: AppTheme.warningColor,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.warning);
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: StatCard(
                    title: '已超期',
                    value: '${provider.overdueCount ?? 0}',
                    unit: '项',
                    icon: Icons.error,
                    color: AppTheme.dangerColor,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.warning);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _ActionItem(
        icon: Icons.arrow_circle_down,
        label: '危废入库',
        color: AppTheme.primaryColor,
        route: AppRoutes.wasteIn,
      ),
      _ActionItem(
        icon: Icons.arrow_circle_up,
        label: '危废出库',
        color: AppTheme.secondaryColor,
        route: AppRoutes.wasteOut,
      ),
      _ActionItem(
        icon: Icons.receipt_long,
        label: '转移联单',
        color: Colors.purple,
        route: AppRoutes.transferOrder,
      ),
      _ActionItem(
        icon: Icons.inventory_rounded,
        label: '库存盘点',
        color: Colors.orange,
        route: AppRoutes.inventoryCheck,
      ),
      _ActionItem(
        icon: Icons.videocam,
        label: '视频监控',
        color: Colors.teal,
        route: AppRoutes.cameraList,
      ),
      _ActionItem(
        icon: Icons.smart_toy,
        label: 'AI抓拍',
        color: Colors.deepPurple,
        route: AppRoutes.captureEventList,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷操作',
          style: AppTextStyle.title,
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 16.w,
            runSpacing: 16.h,
            alignment: WrapAlignment.spaceAround,
            children: actions
                .map((action) => _buildActionItem(action))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(_ActionItem action) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, action.route);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              action.icon,
              size: 28.r,
              color: action.color,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            action.label,
            style: AppTextStyle.body,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningSection() {
    return Consumer<WarningProvider>(
      builder: (context, provider, child) {
        final warnings = provider.unhandledList;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '预警提醒',
                  style: AppTextStyle.title,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.warning);
                  },
                  child: Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (warnings.isEmpty)
              _buildEmptyWarning()
            else
              ...warnings.take(3).map((w) => _buildWarningItem(w)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyWarning() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48.r,
              color: AppTheme.successColor,
            ),
            SizedBox(height: 8.h),
            Text(
              '暂无预警',
              style: AppTextStyle.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(WarningRecord warning) {
    Color levelColor;
    String levelText;
    switch (warning.warningLevel) {
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

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: levelColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.warning_amber,
              size: 24.r,
              color: levelColor,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusTag(
                      text: levelText,
                      color: levelColor,
                      size: StatusTagSize.small,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        warning.warningTypeText,
                        style: AppTextStyle.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  warning.warningContent ?? '',
                  style: AppTextStyle.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInventorySection() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final inventories = provider.recentList;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '库存概览',
                  style: AppTextStyle.title,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.inventory);
                  },
                  child: Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (inventories.isEmpty)
              _buildEmptyInventory()
            else
              ...inventories
                  .take(5)
                  .map((inv) => _buildInventoryItem(inv))
                  .toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyInventory() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48.r,
              color: AppTheme.textHint,
            ),
            SizedBox(height: 8.h),
            Text(
              '暂无库存数据',
              style: AppTextStyle.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(WasteInventory inventory) {
    Color warnColor;
    String warnText;
    switch (inventory.warnStatus) {
      case 2:
        warnColor = AppTheme.dangerColor;
        warnText = '已超期';
        break;
      case 1:
        warnColor = AppTheme.warningColor;
        warnText = '即将超期';
        break;
      case 3:
        warnColor = Colors.orange;
        warnText = '超量';
        break;
      default:
        warnColor = AppTheme.successColor;
        warnText = '正常';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.inventory,
              size: 20.r,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        inventory.wasteName ?? '未知危废',
                        style: AppTextStyle.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusTag(
                      text: warnText,
                      color: warnColor,
                      size: StatusTagSize.small,
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      inventory.wasteCode ?? '',
                      style: AppTextStyle.caption,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      '${inventory.weight?.toStringAsFixed(2) ?? '0'} kg',
                      style: AppTextStyle.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
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

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}
