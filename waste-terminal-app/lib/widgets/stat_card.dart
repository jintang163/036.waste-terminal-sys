import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String? subtitle;
  final String? trendValue;
  final bool trendUp;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    this.iconColor = AppTheme.primaryColor,
    this.backgroundColor = AppTheme.bgCard,
    this.subtitle,
    this.trendValue,
    this.trendUp = true,
    this.onTap,
    this.width,
    this.height,
  });

  factory StatCard.primary({
    Key? key,
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    String? subtitle,
    String? trendValue,
    bool trendUp = true,
    VoidCallback? onTap,
  }) {
    return StatCard(
      key: key,
      title: title,
      value: value,
      unit: unit,
      icon: icon,
      iconColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
      subtitle: subtitle,
      trendValue: trendValue,
      trendUp: trendUp,
      onTap: onTap,
    );
  }

  factory StatCard.success({
    Key? key,
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    String? subtitle,
    String? trendValue,
    bool trendUp = true,
    VoidCallback? onTap,
  }) {
    return StatCard(
      key: key,
      title: title,
      value: value,
      unit: unit,
      icon: icon,
      iconColor: AppTheme.successColor,
      backgroundColor: AppTheme.successColor.withOpacity(0.08),
      subtitle: subtitle,
      trendValue: trendValue,
      trendUp: trendUp,
      onTap: onTap,
    );
  }

  factory StatCard.warning({
    Key? key,
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    String? subtitle,
    String? trendValue,
    bool trendUp = true,
    VoidCallback? onTap,
  }) {
    return StatCard(
      key: key,
      title: title,
      value: value,
      unit: unit,
      icon: icon,
      iconColor: AppTheme.warningColor,
      backgroundColor: AppTheme.warningColor.withOpacity(0.08),
      subtitle: subtitle,
      trendValue: trendValue,
      trendUp: trendUp,
      onTap: onTap,
    );
  }

  factory StatCard.danger({
    Key? key,
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    String? subtitle,
    String? trendValue,
    bool trendUp = true,
    VoidCallback? onTap,
  }) {
    return StatCard(
      key: key,
      title: title,
      value: value,
      unit: unit,
      icon: icon,
      iconColor: AppTheme.dangerColor,
      backgroundColor: AppTheme.dangerColor.withOpacity(0.08),
      subtitle: subtitle,
      trendValue: trendValue,
      trendUp: trendUp,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: backgroundColor,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: AppSize.iconLarge,
                  ),
                ),
                if (trendValue != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: (trendUp
                              ? AppTheme.successColor
                              : AppTheme.dangerColor)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.r4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trendUp
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12.r,
                          color: trendUp
                              ? AppTheme.successColor
                              : AppTheme.dangerColor,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          trendValue!,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: trendUp
                                ? AppTheme.successColor
                                : AppTheme.dangerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyle.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit != null) ...[
                      SizedBox(width: 4.w),
                      Text(
                        unit!,
                        style: AppTextStyle.caption,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle!,
                    style: AppTextStyle.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
