import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';

enum StatusType {
  success,
  warning,
  danger,
  info,
  primary,
  defaultType,
}

class StatusTag extends StatelessWidget {
  final String text;
  final StatusType type;
  final bool outlined;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  const StatusTag({
    super.key,
    required this.text,
    this.type = StatusType.defaultType,
    this.outlined = false,
    this.fontSize,
    this.padding,
    this.borderRadius = 4,
    this.prefixIcon,
    this.suffixIcon,
  });

  factory StatusTag.success(
    String text, {
    bool outlined = false,
    Key? key,
  }) {
    return StatusTag(
      key: key,
      text: text,
      type: StatusType.success,
      outlined: outlined,
    );
  }

  factory StatusTag.warning(
    String text, {
    bool outlined = false,
    Key? key,
  }) {
    return StatusTag(
      key: key,
      text: text,
      type: StatusType.warning,
      outlined: outlined,
    );
  }

  factory StatusTag.danger(
    String text, {
    bool outlined = false,
    Key? key,
  }) {
    return StatusTag(
      key: key,
      text: text,
      type: StatusType.danger,
      outlined: outlined,
    );
  }

  factory StatusTag.info(
    String text, {
    bool outlined = false,
    Key? key,
  }) {
    return StatusTag(
      key: key,
      text: text,
      type: StatusType.info,
      outlined: outlined,
    );
  }

  factory StatusTag.primary(
    String text, {
    bool outlined = false,
    Key? key,
  }) {
    return StatusTag(
      key: key,
      text: text,
      type: StatusType.primary,
      outlined: outlined,
    );
  }

  Color get _backgroundColor {
    if (outlined) return Colors.transparent;
    switch (type) {
      case StatusType.success:
        return AppTheme.successColor.withOpacity(0.15);
      case StatusType.warning:
        return AppTheme.warningColor.withOpacity(0.15);
      case StatusType.danger:
        return AppTheme.dangerColor.withOpacity(0.15);
      case StatusType.info:
        return AppTheme.infoColor.withOpacity(0.15);
      case StatusType.primary:
        return AppTheme.primaryColor.withOpacity(0.15);
      case StatusType.defaultType:
        return AppTheme.textHint.withOpacity(0.15);
    }
  }

  Color get _textColor {
    switch (type) {
      case StatusType.success:
        return AppTheme.successColor;
      case StatusType.warning:
        return AppTheme.warningColor;
      case StatusType.danger:
        return AppTheme.dangerColor;
      case StatusType.info:
        return AppTheme.infoColor;
      case StatusType.primary:
        return AppTheme.primaryColor;
      case StatusType.defaultType:
        return AppTheme.textSecondary;
    }
  }

  Color get _borderColor {
    switch (type) {
      case StatusType.success:
        return AppTheme.successColor;
      case StatusType.warning:
        return AppTheme.warningColor;
      case StatusType.danger:
        return AppTheme.dangerColor;
      case StatusType.info:
        return AppTheme.infoColor;
      case StatusType.primary:
        return AppTheme.primaryColor;
      case StatusType.defaultType:
        return AppTheme.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize ?? 12.sp;
    final effectivePadding = padding ??
        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h);

    return Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius.r),
        border: outlined
            ? Border.all(color: _borderColor, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefixIcon != null) ...[
            Icon(
              prefixIcon,
              size: effectiveFontSize,
              color: _textColor,
            ),
            SizedBox(width: 4.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: effectiveFontSize,
              color: _textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (suffixIcon != null) ...[
            SizedBox(width: 4.w),
            Icon(
              suffixIcon,
              size: effectiveFontSize,
              color: _textColor,
            ),
          ],
        ],
      ),
    );
  }
}
