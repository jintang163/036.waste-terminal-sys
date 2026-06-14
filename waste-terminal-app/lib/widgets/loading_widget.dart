import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';

enum LoadingType { spinner, pulse, ripple, line }

class LoadingWidget extends StatelessWidget {
  final LoadingType type;
  final double size;
  final Color? color;
  final String? message;
  final bool showMessage;

  const LoadingWidget({
    super.key,
    this.type = LoadingType.spinner,
    this.size = 40,
    this.color,
    this.message,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIndicator(effectiveColor),
          if (showMessage && (message != null || true)) ...[
            SizedBox(height: 16.h),
            Text(
              message ?? '加载中...',
              style: AppTextStyle.bodySecondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicator(Color color) {
    switch (type) {
      case LoadingType.spinner:
        return SizedBox(
          width: size.r,
          height: size.r,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      case LoadingType.pulse:
        return _PulseLoading(size: size.r, color: color);
      case LoadingType.ripple:
        return _RippleLoading(size: size.r, color: color);
      case LoadingType.line:
        return SizedBox(
          width: size.r * 2,
          height: size.r / 5,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: color.withOpacity(0.2),
          ),
        );
    }
  }
}

class _PulseLoading extends StatefulWidget {
  final double size;
  final Color color;

  const _PulseLoading({required this.size, required this.color});

  @override
  State<_PulseLoading> createState() => _PulseLoadingState();
}

class _PulseLoadingState extends State<_PulseLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + _animation.value * 0.5,
          child: Opacity(
            opacity: 1.0 - _animation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RippleLoading extends StatefulWidget {
  final double size;
  final Color color;

  const _RippleLoading({required this.size, required this.color});

  @override
  State<_RippleLoading> createState() => _RippleLoadingState();
}

class _RippleLoadingState extends State<_RippleLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = ((_controller.value + index * 0.33) % 1.0);
              return Transform.scale(
                scale: 0.3 + progress * 0.7,
                child: Opacity(
                  opacity: 1.0 - progress,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const LoadingPage({
    super.key,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.bgPrimary,
      body: LoadingWidget(message: message),
    );
  }
}
