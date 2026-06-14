import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  @override
  void initState() {
    super.initState();
    _loadSyncInfo();
  }

  Future<void> _loadSyncInfo() async {
    try {
      final syncProvider = context.read<SyncProvider>();
      await syncProvider.loadUnsyncedCount();
      await syncProvider.loadLastSyncTime();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildUserCard(),
          SizedBox(height: 12.h),
          _buildMenuSection(),
          SizedBox(height: 12.h),
          _buildSyncSection(),
          SizedBox(height: 24.h),
          _buildLogoutButton(),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    final appProvider = context.watch<AppProvider>();
    final userInfo = appProvider.userInfo;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 64.r,
              height: 64.r,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 36.r,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userInfo?['realName']?.toString() ?? userInfo?['username']?.toString() ?? '未知用户',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '@${userInfo?['username']?.toString() ?? '-'}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          userInfo?['roleName']?.toString() ?? '操作员',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          appProvider.enterpriseName ?? '',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7), size: 24.r),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
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
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.bluetooth,
            iconColor: Colors.blue,
            title: '设备管理',
            onTap: () {
              ToastUtil.showShort('功能开发中');
            },
          ),
          Divider(height: 1.h, indent: 56.w, endIndent: 16.w),
          _buildMenuItem(
            icon: Icons.sync,
            iconColor: AppTheme.secondaryColor,
            title: '数据同步',
            onTap: () => Navigator.pushNamed(context, AppRoutes.sync),
          ),
          Divider(height: 1.h, indent: 56.w, endIndent: 16.w),
          _buildMenuItem(
            icon: Icons.cloud_upload,
            iconColor: AppTheme.infoColor,
            title: '国家平台上报',
            onTap: () => Navigator.pushNamed(context, AppRoutes.platformReport),
          ),
          Divider(height: 1.h, indent: 56.w, endIndent: 16.w),
          _buildMenuItem(
            icon: Icons.settings,
            iconColor: Colors.grey,
            title: '系统设置',
            onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
          Divider(height: 1.h, indent: 56.w, endIndent: 16.w),
          _buildMenuItem(
            icon: Icons.info_outline,
            iconColor: AppTheme.infoColor,
            title: '关于',
            onTap: () => Navigator.pushNamed(context, AppRoutes.about),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, size: 20.r, color: iconColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(title, style: AppTextStyle.body),
            ),
            Icon(Icons.chevron_right, size: 20.r, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(16.w),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('同步状态', style: AppTextStyle.subtitle),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('上次同步', style: AppTextStyle.caption),
                        SizedBox(height: 4.h),
                        Text(
                          syncProvider.lastSyncTimeText ?? '从未同步',
                          style: AppTextStyle.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('待同步记录', style: AppTextStyle.caption),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Text(
                              '${syncProvider.unsyncedCount}',
                              style: AppTextStyle.body.copyWith(
                                fontWeight: FontWeight.w500,
                                color: syncProvider.unsyncedCount > 0
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text('条', style: AppTextStyle.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 40.h,
                child: ElevatedButton.icon(
                  onPressed: syncProvider.isSyncing ? null : _handleManualSync,
                  icon: syncProvider.isSyncing
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.sync, size: 18.r),
                  label: Text(syncProvider.isSyncing ? '同步中...' : '立即同步'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleManualSync() async {
    try {
      final syncProvider = context.read<SyncProvider>();
      await syncProvider.incrementalSync();
      if (mounted) {
        ToastUtil.showSuccess('同步完成');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showError('同步失败');
      }
    }
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        width: double.infinity,
        height: 44.h,
        child: OutlinedButton(
          onPressed: _handleLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.dangerColor,
            side: const BorderSide(color: AppTheme.dangerColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text('退出登录', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认退出', style: AppTextStyle.title),
          content: Text('确定要退出登录吗？', style: AppTextStyle.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确定', style: TextStyle(color: AppTheme.dangerColor)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final appProvider = context.read<AppProvider>();
        await appProvider.logout();
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      } catch (e) {
        if (mounted) {
          ToastUtil.showError('退出失败');
        }
      }
    }
  }
}
