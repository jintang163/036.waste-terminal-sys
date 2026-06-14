import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';
import 'common_button.dart';

class EmptyState extends StatelessWidget {
  final String? message;
  final String? subMessage;
  final IconData? icon;
  final Widget? image;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final double iconSize;
  final Color? iconColor;

  const EmptyState({
    super.key,
    this.message,
    this.subMessage,
    this.icon,
    this.image,
    this.buttonText,
    this.onButtonPressed,
    this.iconSize = 80,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIcon(),
            SizedBox(height: 24.h),
            Text(
              message ?? '暂无数据',
              style: AppTextStyle.subtitle,
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              SizedBox(height: 8.h),
              Text(
                subMessage!,
                style: AppTextStyle.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              SizedBox(height: 32.h),
              CommonButton(
                text: buttonText!,
                onPressed: onButtonPressed,
                size: ButtonSize.medium,
                prefixIcon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (image != null) {
      return SizedBox(
        width: iconSize.r,
        height: iconSize.r,
        child: image,
      );
    }

    return Icon(
      icon ?? Icons.inbox_outlined,
      size: iconSize.r,
      color: iconColor ?? AppTheme.textHint,
    );
  }
}
