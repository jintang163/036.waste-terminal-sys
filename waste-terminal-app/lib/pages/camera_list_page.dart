import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../models/camera_model.dart';
import '../services/camera_service.dart';
import '../widgets/status_tag.dart';
import '../widgets/empty_state.dart';
import '../utils/toast_util.dart';

class CameraListPage extends StatefulWidget {
  const CameraListPage({super.key});

  @override
  State<CameraListPage> createState() => _CameraListPageState();
}

class _CameraListPageState extends State<CameraListPage> {
  final RefreshController _refreshController = RefreshController();
  final CameraService _cameraService = CameraService();

  List<CameraModel> _cameras = [];
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
      final result = await _cameraService.getCameraPage(
        pageNum: _currentPage,
        pageSize: _pageSize,
      );
      setState(() {
        if (_currentPage == 1) {
          _cameras = result.records ?? [];
        } else {
          _cameras.addAll(result.records ?? []);
        }
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ToastUtil.showError('加载摄像头列表失败');
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _hasMore = true;
    try {
      final result = await _cameraService.getCameraPage(
        pageNum: _currentPage,
        pageSize: _pageSize,
      );
      setState(() {
        _cameras = result.records ?? [];
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
      final result = await _cameraService.getCameraPage(
        pageNum: _currentPage,
        pageSize: _pageSize,
      );
      setState(() {
        _cameras.addAll(result.records ?? []);
        _hasMore = result.hasMore;
      });
      _refreshController.loadComplete();
    } catch (e) {
      _currentPage--;
      _refreshController.loadComplete();
    }
  }

  StatusTag _getStatusTag(int? status) {
    switch (status) {
      case 1:
        return StatusTag.success('在线');
      case 2:
        return StatusTag.danger('故障');
      default:
        return StatusTag.warning('离线', outlined: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频监控'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cameras.isEmpty
              ? EmptyState(
                  message: '暂无摄像头',
                  icon: Icons.videocam_off_outlined,
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
                    itemCount: _cameras.length,
                    itemBuilder: (context, index) {
                      return _buildCameraCard(_cameras[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildCameraCard(CameraModel camera) {
    return GestureDetector(
      onTap: () {
        if (camera.cameraCode != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.cameraPreview,
            arguments: camera.cameraCode,
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
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Icon(
                    Icons.videocam,
                    size: 22.r,
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
                              camera.cameraName ?? '未命名摄像头',
                              style: AppTextStyle.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _getStatusTag(camera.status),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14.r, color: AppTheme.textHint),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              camera.location ?? '未设置位置',
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
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                  ),
                  child: Text(
                    camera.brandText,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.infoColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                  ),
                  child: Text(
                    camera.cameraTypeText,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                if (camera.aiEnabled == true)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.r4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy, size: 10.r, color: AppTheme.secondaryColor),
                        SizedBox(width: 2.w),
                        Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 18.r, color: AppTheme.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
