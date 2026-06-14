import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';

enum ButtonType { primary, secondary, outline, text }

enum ButtonSize { large, medium, small }

class CommonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool loading;
  final bool disabled;
  final bool block;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;

  const CommonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.loading = false,
    this.disabled = false,
    this.block = false,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 8,
  });

  double get _height {
    if (height != null) return height!.h;
    switch (size) {
      case ButtonSize.large:
        return 52.h;
      case ButtonSize.medium:
        return 44.h;
      case ButtonSize.small:
        return 36.h;
    }
  }

  double get _fontSize {
    switch (size) {
      case ButtonSize.large:
        return 18.sp;
      case ButtonSize.medium:
        return 16.sp;
      case ButtonSize.small:
        return 14.sp;
    }
  }

  double get _iconSize {
    switch (size) {
      case ButtonSize.large:
        return 22.r;
      case ButtonSize.medium:
        return 18.r;
      case ButtonSize.small:
        return 16.r;
    }
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case ButtonSize.large:
        return EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h);
      case ButtonSize.medium:
        return EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h);
      case ButtonSize.small:
        return EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h);
    }
  }

  bool get _isDisabled => disabled || loading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = block ? double.infinity : width;

    return SizedBox(
      width: effectiveWidth,
      height: _height,
      child: _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppTheme.primaryColor,
            foregroundColor: foregroundColor ?? AppTheme.textInverse,
            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
            disabledForegroundColor: AppTheme.textInverse.withOpacity(0.8),
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonType.secondary:
        return ElevatedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppTheme.secondaryColor,
            foregroundColor: foregroundColor ?? AppTheme.textInverse,
            disabledBackgroundColor: AppTheme.secondaryColor.withOpacity(0.5),
            disabledForegroundColor: AppTheme.textInverse.withOpacity(0.8),
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonType.outline:
        return OutlinedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? AppTheme.primaryColor,
            disabledForegroundColor: AppTheme.primaryColor.withOpacity(0.5),
            padding: _padding,
            side: BorderSide(
              color: backgroundColor ?? AppTheme.primaryColor,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonType.text:
        return TextButton(
          onPressed: _isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor ?? AppTheme.primaryColor,
            disabledForegroundColor: AppTheme.primaryColor.withOpacity(0.5),
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
            ),
          ),
          child: _buildChild(),
        );
    }
  }

  Widget _buildChild() {
    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? AppTheme.textInverse,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '加载中...',
            style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefixIcon != null) ...[
          Icon(prefixIcon, size: _iconSize),
          SizedBox(width: 6.w),
        ],
        Text(
          text,
          style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w500),
        ),
        if (suffixIcon != null) ...[
          SizedBox(width: 6.w),
          Icon(suffixIcon, size: _iconSize),
        ],
      ],
    );
  }
}
