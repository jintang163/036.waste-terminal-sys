import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class ToastUtil {
  ToastUtil._();

  static void show(String msg, {Duration? duration}) {
    if (msg.isEmpty) return;
    EasyLoading.showToast(
      msg,
      duration: duration ?? const Duration(seconds: 2),
      toastPosition: EasyLoadingToastPosition.bottom,
    );
  }

  static void showShort(String msg) {
    show(msg, duration: const Duration(seconds: 1));
  }

  static void showLong(String msg) {
    show(msg, duration: const Duration(seconds: 3));
  }

  static void showSuccess(String msg) {
    if (msg.isEmpty) return;
    EasyLoading.showSuccess(
      msg,
      duration: const Duration(seconds: 2),
    );
  }

  static void showError(String msg) {
    if (msg.isEmpty) return;
    EasyLoading.showError(
      msg,
      duration: const Duration(seconds: 2),
    );
  }

  static void showInfo(String msg) {
    if (msg.isEmpty) return;
    EasyLoading.showInfo(
      msg,
      duration: const Duration(seconds: 2),
    );
  }

  static void showLoading({String? status}) {
    EasyLoading.show(
      status: status ?? '加载中...',
      maskType: EasyLoadingMaskType.black,
    );
  }

  static void showProgress(double progress, {String? status}) {
    EasyLoading.showProgress(
      progress,
      status: status ?? '${(progress * 100).toStringAsFixed(0)}%',
    );
  }

  static void dismiss() {
    EasyLoading.dismiss();
  }

  static void showToastInContext(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showSnackBar(
    BuildContext context,
    String msg, {
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: duration ?? const Duration(seconds: 2),
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
  }

  static void hideSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
