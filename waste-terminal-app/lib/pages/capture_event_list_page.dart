import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../models/ai_capture_event.dart';
import '../services/ai_capture_service.dart';
import '../widgets/status_tag.dart';
import '../widgets/empty_state.dart';
import '../utils/toast_util.dart';
import '../utils/date_util.dart';

class CaptureEventListPage extends StatefulWidget {
  const CaptureEventListPage({super.key});

  @override
  State<CaptureEventListPage> createState() => _CaptureEventListPageState();
}

class _CaptureEventListPageState extends State<CaptureEventListPage> {
  final RefreshController _refreshController = RefreshController();
  final AiCaptureService _aiCaptureService = AiCaptureService();

  final List<_CategoryTab> _tabs = const [
    _CategoryTab(label: '全部', category: null),
    _CategoryTab(label: '安全违规', category: 'safety_violation'),
    _CategoryTab(label: '设备预警', category: 'equipment_warning'),
    _CategoryTab(label: '行为异常', category: 'behavior_abnormal'),
  ];

  int _currentTabIndex = 0;
  List<AiCaptureEvent> _events = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _pageSize = 20;
  bool _hasMore = true;

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
    try {
      final tab = _tabs[_currentTabIndex];
      final result = await _aiCaptureService.getCaptureEventPage(
        pageNum: _currentPage,
        pageSize: _pageSize,
        eventCategory: tab.category,
      );
      setState(() {
        if (_currentPage == 1) {
          _events = result.records ?? [];
        } else {
          _events.addAll(result.records ?? []);
        }
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ToastUtil.showError('加载事件列表失败');
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _hasMore = true;
    try {
      final tab = _tabs[_currentTabIndex];
      final result = await _aiCaptureService.getCaptureEventPage(
        pageNum: _currentPage,
        pageSize: _pageSize,
        eventCategory: tab.category,
      );
      setState(() {
        _events = result.records ?? [];
        _hasMore = result.hasMore;
      });
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _onLoading() async {
    if (!_hasMore) {
      _refreshController.loadNoData();
      return;
    }
    _currentPage++;
    try {
      final tab = _tabs[_currentTabIndex];
      final result = await _aiCaptureService.getCaptureEventPage(
        pageNum: _currentPage,
        pageSize: _pageSize,
        eventCategory: tab.category,
      );
      setState(() {
        _events.addAll(result.records ?? []);
        _hasMore = result.hasMore;
      });
      _refreshController.loadComplete();
    } catch (e) {
      _currentPage--;
      _refreshController.loadComplete();
    }
  }

  void _onTabChanged(int index) {
    if (_currentTabIndex == index) return;
    setState(() {
      _currentTabIndex = index;
      _currentPage = 1;
      _hasMore = true;
      _isLoading = true;
    });
    _loadData();
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
        title: const Text('AI抓拍事件'),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? EmptyState(
                        message: '暂无抓拍事件',
                        icon: Icons.event_available_outlined,
                        buttonText: '刷新',
                        onButtonPressed: _onRefresh,
                      )
                    : SmartRefresher(
                        controller: _refreshController,
                        onRefresh: _onRefresh,
                        onLoading: _onLoading,
                        enablePullUp: _hasMore,
                        header: WaterDropHeader(
                          waterDropColor: AppTheme.primaryColor,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            return _buildEventCard(_events[index]);
                          },
                        ),
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

  Widget _buildEventCard(AiCaptureEvent event) {
    final categoryColor = _getEventCategoryColor(event.eventCategory);
    final categoryIcon = _getEventCategoryIcon(event.eventCategory);

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
                    color: categoryColor,
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
                          Icon(categoryIcon, size: 16.r, color: categoryColor),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              event.eventTypeText,
                              style: AppTextStyle.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _getHandleStatusTag(event.handleStatus),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(Icons.videocam, size: 14.r, color: AppTheme.textHint),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              event.cameraName ?? '未知摄像头',
                              style: AppTextStyle.bodySecondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                      DateUtil.friendlyTime(event.captureTime),
                      style: AppTextStyle.small,
                    ),
                  ],
                ),
                _buildConfidenceBar(event.confidence),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(int? confidence) {
    final value = (confidence ?? 0) / 100.0;
    final color = value >= 0.8
        ? AppTheme.dangerColor
        : value >= 0.5
            ? AppTheme.warningColor
            : AppTheme.infoColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '置信度',
          style: TextStyle(fontSize: 10.sp, color: AppTheme.textHint),
        ),
        SizedBox(width: 4.w),
        Container(
          width: 60.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          '${confidence ?? 0}%',
          style: TextStyle(fontSize: 10.sp, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _CategoryTab {
  final String label;
  final String? category;

  const _CategoryTab({required this.label, this.category});
}
