import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/warning_provider.dart';
import '../widgets/status_tag.dart';
import '../widgets/empty_state.dart';
import '../utils/toast_util.dart';
import '../utils/date_util.dart';

class WarningPage extends StatefulWidget {
  const WarningPage({super.key});

  @override
  State<WarningPage> createState() => _WarningPageState();
}

class _WarningPageState extends State<WarningPage>
    with SingleTickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController();

  final List<_WarningTab> _tabs = const [
    _WarningTab(label: '全部', type: null),
    _WarningTab(label: '超期预警', type: 'overdue'),
    _WarningTab(label: '超量预警', type: 'overload'),
    _WarningTab(label: '即将超期', type: 'near_expiry'),
  ];

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await context.read<WarningProvider>().loadWarnings(refresh: true);
  }

  Future<void> _onRefresh() async {
    try {
      await context.read<WarningProvider>().refresh(forceRefresh: true);
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _onLoading() async {
    try {
      await context.read<WarningProvider>().loadWarnings();
      _refreshController.loadComplete();
    } catch (e) {
      _refreshController.loadComplete();
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentTabIndex = index;
    });
    final tab = _tabs[index];
    final provider = context.read<WarningProvider>();
    provider.setSearchParams(warningType: tab.type);
    provider.loadWarnings(refresh: true);
  }

  void _showHandleDialog(Map<String, dynamic> warning) {
    final remarkController = TextEditingController();
    final warningId = warning['warning_id']?.toString() ?? warning['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('处理预警'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warning['warning_content']?.toString() ?? '',
                style: AppTextStyle.body,
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: remarkController,
                maxLines: 3,
                style: AppTextStyle.body,
                decoration: const InputDecoration(
                  hintText: '请输入处理备注',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final remark = remarkController.text.trim();
                final success = await context.read<WarningProvider>().handleWarning(
                      warningId,
                      handleRemark: remark.isEmpty ? null : remark,
                    );
                if (success) {
                  ToastUtil.showSuccess('处理成功');
                } else {
                  ToastUtil.showError('处理失败');
                }
              },
              child: const Text('确认处理'),
            ),
          ],
        );
      },
    ).then((_) => remarkController.dispose());
  }

  Color _getLevelColor(int? level) {
    switch (level) {
      case 3:
        return AppTheme.dangerColor;
      case 2:
        return AppTheme.warningColor;
      default:
        return AppTheme.infoColor;
    }
  }

  String _getLevelText(int? level) {
    switch (level) {
      case 3:
        return '严重';
      case 2:
        return '较重';
      default:
        return '一般';
    }
  }

  StatusTag _getLevelTag(int? level) {
    switch (level) {
      case 3:
        return StatusTag.danger('严重');
      case 2:
        return StatusTag.warning('较重');
      default:
        return StatusTag.info('一般');
    }
  }

  StatusTag _getHandleStatusTag(int? status) {
    if (status == 1) {
      return StatusTag.success('已处理');
    }
    return StatusTag.danger('未处理', outlined: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预警列表'),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              enablePullUp: true,
              header: WaterDropHeader(
                waterDropColor: AppTheme.primaryColor,
              ),
              child: _buildWarningList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: AppTheme.bgCard,
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final isSelected = _currentTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabChanged(index),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: isSelected
                      ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
                      : null,
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWarningList() {
    return Consumer<WarningProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.warnings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.warnings.isEmpty) {
          return EmptyState(
            message: '暂无预警记录',
            icon: Icons.check_circle_outline,
            buttonText: '刷新',
            onButtonPressed: () => provider.refresh(),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: provider.warnings.length,
          itemBuilder: (context, index) {
            final warning = provider.warnings[index];
            return _buildWarningCard(warning);
          },
        );
      },
    );
  }

  Widget _buildWarningCard(Map<String, dynamic> warning) {
    final level = warning['warning_level'] as int?;
    final warningType = warning['warning_type'] as String? ?? '';
    final content = warning['warning_content'] as String? ?? '';
    final triggerTime = warning['trigger_time'] as String?;
    final handleStatus = warning['handle_status'] as int?;
    final levelColor = _getLevelColor(level);

    return GestureDetector(
      onTap: () {
        if (handleStatus != 1) {
          _showHandleDialog(warning);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
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
                Container(
                  width: 4.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _getLevelTag(level),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _getWarningTypeText(warningType),
                              style: AppTextStyle.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _getHandleStatusTag(handleStatus),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        content,
                        style: AppTextStyle.bodySecondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14.r, color: AppTheme.textHint),
                    SizedBox(width: 4.w),
                    Text(
                      triggerTime != null
                          ? DateUtil.formatString(triggerTime, DateUtil.formatDateTimeShort) ?? ''
                          : '',
                      style: AppTextStyle.small,
                    ),
                  ],
                ),
                if (handleStatus != 1)
                  Text(
                    '点击处理',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getWarningTypeText(String? type) {
    switch (type) {
      case 'overdue':
        return '超期预警';
      case 'overload':
        return '超量预警';
      case 'near_expiry':
        return '即将超期';
      default:
        return type ?? '预警';
    }
  }
}

class _WarningTab {
  final String label;
  final String? type;

  const _WarningTab({required this.label, this.type});
}
