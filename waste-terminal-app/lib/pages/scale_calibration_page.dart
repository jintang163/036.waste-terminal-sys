import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../models/scale_calibration.dart';
import '../services/bluetooth_service.dart';
import '../services/scale_service.dart';
import '../utils/toast_util.dart';
import '../widgets/common_button.dart';

class ScaleCalibrationPage extends StatefulWidget {
  const ScaleCalibrationPage({super.key});

  @override
  State<ScaleCalibrationPage> createState() => _ScaleCalibrationPageState();
}

class _ScaleCalibrationPageState extends State<ScaleCalibrationPage> {
  final ScaleService _scaleService = ScaleService();
  final BluetoothService _bluetoothService = BluetoothService();

  StreamSubscription<double>? _weightSub;
  StreamSubscription<ScaleStatus>? _statusSub;
  StreamSubscription<CalibrationStep>? _calibrationStepSub;
  StreamSubscription<ScaleCalibrationParams>? _paramsSub;

  double _rawWeight = 0.0;
  double _calibratedWeight = 0.0;
  double _netWeight = 0.0;
  ScaleStatus _status = ScaleStatus.disconnected;
  CalibrationStep _step = CalibrationStep.idle;
  ScaleCalibrationParams _params =
      ScaleCalibrationParams(lastCalibrationTime: DateTime.now());

  final TextEditingController _point1WeightCtrl = TextEditingController();
  final TextEditingController _point2WeightCtrl = TextEditingController();
  double? _capturedZeroRaw;
  double? _capturedPoint1Raw;
  double? _capturedPoint2Raw;

  bool _isOperating = false;

  @override
  void initState() {
    super.initState();
    _initParams();
    _subscribeStreams();
    _autoConnectScale();
  }

  Future<void> _initParams() async {
    await _scaleService.loadSavedParams();
    if (!mounted) return;
    setState(() {
      _params = _scaleService.calibrationParams;
    });
  }

  void _subscribeStreams() {
    _weightSub = _scaleService.weightStream.listen((w) {
      if (!mounted) return;
      setState(() {
        _netWeight = w;
        _rawWeight = _scaleService.rawWeight;
        _calibratedWeight = _scaleService.calibratedWeight;
      });
    });
    _statusSub = _scaleService.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
    _calibrationStepSub = _scaleService.calibrationStepStream.listen((s) {
      if (!mounted) return;
      setState(() => _step = s);
    });
    _paramsSub = _scaleService.paramsStream.listen((p) {
      if (!mounted) return;
      setState(() => _params = p);
    });
  }

  @override
  void dispose() {
    _weightSub?.cancel();
    _statusSub?.cancel();
    _calibrationStepSub?.cancel();
    _paramsSub?.cancel();
    _point1WeightCtrl.dispose();
    _point2WeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoConnectScale() async {
    try {
      final connected = await _bluetoothService.autoConnectScale();
      if (connected) {
        final addr = _bluetoothService.connectedDeviceAddress;
        if (addr != null) {
          _scaleService.setDeviceConfig(deviceAddress: addr);
          await _scaleService.connect();
        }
      }
    } catch (e) {
      // 自动连接失败不提示，用户可手动连接
    }
  }

  Future<void> _handleZero() async {
    if (_status != ScaleStatus.connected) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    setState(() => _isOperating = true);
    try {
      await _scaleService.zero();
      ToastUtil.showSuccess('一键归零成功');
    } catch (e) {
      ToastUtil.showError('归零失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleTare() async {
    if (_status != ScaleStatus.connected) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    setState(() => _isOperating = true);
    try {
      await _scaleService.tare();
      ToastUtil.showSuccess('去皮完成');
    } catch (e) {
      ToastUtil.showError('去皮失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleClearTare() async {
    await _scaleService.clearTare();
    ToastUtil.showSuccess('皮重已清除');
  }

  void _handleStartCalibration() {
    _point1WeightCtrl.clear();
    _point2WeightCtrl.clear();
    _capturedZeroRaw = null;
    _capturedPoint1Raw = null;
    _capturedPoint2Raw = null;
    _scaleService.startCalibration();
    ToastUtil.showInfo('请保持地磅空载稳定');
  }

  Future<void> _handleCaptureZero() async {
    if (_status != ScaleStatus.connected) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    setState(() => _isOperating = true);
    try {
      final p = await _scaleService.captureZeroPoint();
      if (!mounted) return;
      setState(() => _capturedZeroRaw = p.rawReading);
      ToastUtil.showSuccess('零点捕获成功');
    } catch (e) {
      ToastUtil.showError('零点捕获失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleCapturePoint1() async {
    if (_status != ScaleStatus.connected) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    final w = double.tryParse(_point1WeightCtrl.text.trim());
    if (w == null || w <= 0) {
      ToastUtil.showError('请输入第一点标准重量(kg)');
      return;
    }
    setState(() => _isOperating = true);
    try {
      final p = await _scaleService.captureFirstPoint(w);
      if (!mounted) return;
      setState(() => _capturedPoint1Raw = p.rawReading);
      ToastUtil.showSuccess('第一点捕获成功');
    } catch (e) {
      ToastUtil.showError('第一点捕获失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleCapturePoint2() async {
    if (_status != ScaleStatus.connected) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    final w = double.tryParse(_point2WeightCtrl.text.trim());
    if (w == null || w <= 0) {
      ToastUtil.showError('请输入第二点标准重量(kg)');
      return;
    }
    final w1 = double.tryParse(_point1WeightCtrl.text.trim());
    if (w1 != null && w <= w1) {
      ToastUtil.showError('第二点必须大于第一点');
      return;
    }
    setState(() => _isOperating = true);
    try {
      final p = await _scaleService.captureSecondPoint(w);
      if (!mounted) return;
      setState(() => _capturedPoint2Raw = p.rawReading);
      ToastUtil.showSuccess('第二点捕获成功');
    } catch (e) {
      ToastUtil.showError('第二点捕获失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleApplyCalibration() async {
    setState(() => _isOperating = true);
    try {
      await _scaleService.applyCalibration(remark: '三点线性校准');
      ToastUtil.showSuccess('校准参数已保存');
    } catch (e) {
      ToastUtil.showError('校准失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  void _handleCancel() {
    _scaleService.cancelCalibration();
    _point1WeightCtrl.clear();
    _point2WeightCtrl.clear();
    _capturedZeroRaw = null;
    _capturedPoint1Raw = null;
    _capturedPoint2Raw = null;
  }

  Future<void> _handleReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('确定要将校准参数恢复默认值吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定',
                  style: TextStyle(color: AppTheme.dangerColor))),
        ],
      ),
    );
    if (ok != true) return;
    await _scaleService.resetCalibration();
    ToastUtil.showSuccess('校准参数已重置');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地磅校准'),
        actions: [
          if (_step != CalibrationStep.idle)
            TextButton(
              onPressed: _handleCancel,
              child: Text(_step == CalibrationStep.completed ? '完成' : '取消',
                  style: const TextStyle(color: Colors.white)),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _handleReset();
              if (v == 'history') _showHistory();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'history', child: Text('校准历史')),
              const PopupMenuItem(value: 'reset', child: Text('恢复默认')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWeightDisplay(),
            SizedBox(height: 16.h),
            _buildStatusCard(),
            SizedBox(height: 16.h),
            if (_step == CalibrationStep.idle) ...[
              _buildQuickActions(),
              SizedBox(height: 16.h),
              _buildCalibrationCard(),
            ] else
              _buildCalibrationWizard(),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text('净重',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 14.sp)),
          SizedBox(height: 8.h),
          Text(
            _netWeight.toStringAsFixed(AppConfig.weightDecimalPlaces),
            style: TextStyle(
              color: Colors.white,
              fontSize: 56.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'RobotoMono',
            ),
          ),
          Text('kg',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 18.sp)),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.center,
            children: [
              Text('原始: ${_rawWeight.toStringAsFixed(3)} kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12.sp)),
              Text('校准: ${_calibratedWeight.toStringAsFixed(3)} kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12.sp)),
              Text('皮重: ${_params.currentTare.toStringAsFixed(3)} kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12.sp)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _status == ScaleStatus.connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: _status == ScaleStatus.connected
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text('地磅状态: ${_statusText()}',
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _params.isCalibrated
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(_params.statusText,
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: _params.isCalibrated
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 24.w,
            runSpacing: 8.h,
            children: [
              _buildParamItem('斜率', _params.slope.toStringAsFixed(6)),
              _buildParamItem('截距', _params.intercept.toStringAsFixed(6)),
              _buildParamItem('零点',
                  '${_params.zeroOffset.toStringAsFixed(3)} kg'),
              _buildParamItem('皮重',
                  '${_params.currentTare.toStringAsFixed(3)} kg'),
              _buildParamItem('校准次数', '${_params.calibrationCount}'),
              _buildParamItem('上次校准', _params.lastCalibrationTimeText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamItem(String label, String value) {
    return SizedBox(
      width: 120.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.sp)),
          SizedBox(height: 2.h),
          Text(value,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('快捷操作',
              style: TextStyle(
                  fontSize: 16.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  text: '一键归零',
                  onPressed: _isOperating ? null : _handleZero,
                  type: ButtonType.primary,
                  prefixIcon: Icons.exposure_zero,
                  loading: _isOperating,
                  block: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CommonButton(
                  text: '去皮',
                  onPressed: _isOperating ? null : _handleTare,
                  type: ButtonType.secondary,
                  prefixIcon: Icons.remove_circle_outline,
                  block: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CommonButton(
                  text: '清皮重',
                  onPressed: _isOperating ? null : _handleClearTare,
                  type: ButtonType.outline,
                  prefixIcon: Icons.restore,
                  block: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('精度校准',
              style: TextStyle(
                  fontSize: 16.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Text('通过三点线性校准（零点 + 两个标准砝码点），确保称重精度。',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13.sp)),
          SizedBox(height: 16.h),
          CommonButton(
            text: '开始三点校准',
            onPressed: _status == ScaleStatus.connected
                ? _handleStartCalibration
                : null,
            type: ButtonType.primary,
            prefixIcon: Icons.tune,
            block: true,
            size: ButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationWizard() {
    final steps = [
      _buildStep(
        step: 1,
        title: '捕获零点',
        subtitle: '请保持地磅空载，等待读数稳定后点击捕获',
        active: _step.index >= CalibrationStep.zeroPoint.index,
        done: _capturedZeroRaw != null,
        content: _capturedZeroRaw != null
            ? Text('捕获值: ${_capturedZeroRaw!.toStringAsFixed(3)}',
                style: TextStyle(color: AppTheme.successColor))
            : CommonButton(
                text: '捕获零点',
                onPressed: _step == CalibrationStep.zeroPoint && !_isOperating
                    ? _handleCaptureZero
                    : null,
                loading: _isOperating && _step == CalibrationStep.zeroPoint,
                prefixIcon: Icons.radio_button_unchecked,
              ),
      ),
      if (_step.index >= CalibrationStep.firstPoint.index)
        _buildStep(
          step: 2,
          title: '捕获第一点',
          subtitle: '放置已知标准砝码，输入重量并点击捕获',
          active: _step.index >= CalibrationStep.firstPoint.index,
          done: _capturedPoint1Raw != null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _point1WeightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '标准重量 (kg)',
                  hintText: '例如: 10.000',
                  suffixText: 'kg',
                ),
                enabled: _capturedPoint1Raw == null,
              ),
              SizedBox(height: 12.h),
              if (_capturedPoint1Raw != null)
                Text('捕获值: ${_capturedPoint1Raw!.toStringAsFixed(3)}',
                    style: TextStyle(color: AppTheme.successColor))
              else
                CommonButton(
                  text: '捕获第一点',
                  onPressed:
                      _step == CalibrationStep.firstPoint && !_isOperating
                          ? _handleCapturePoint1
                          : null,
                  loading:
                      _isOperating && _step == CalibrationStep.firstPoint,
                  prefixIcon: Icons.looks_one,
                ),
            ],
          ),
        ),
      if (_step.index >= CalibrationStep.secondPoint.index)
        _buildStep(
          step: 3,
          title: '捕获第二点',
          subtitle: '更换更大的标准砝码，输入重量并点击捕获',
          active: _step.index >= CalibrationStep.secondPoint.index,
          done: _capturedPoint2Raw != null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _point2WeightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '标准重量 (kg，大于第一点)',
                  hintText: '例如: 50.000',
                  suffixText: 'kg',
                ),
                enabled: _capturedPoint2Raw == null,
              ),
              SizedBox(height: 12.h),
              if (_capturedPoint2Raw != null)
                Text('捕获值: ${_capturedPoint2Raw!.toStringAsFixed(3)}',
                    style: TextStyle(color: AppTheme.successColor))
              else
                CommonButton(
                  text: '捕获第二点',
                  onPressed:
                      _step == CalibrationStep.secondPoint && !_isOperating
                          ? _handleCapturePoint2
                          : null,
                  loading:
                      _isOperating && _step == CalibrationStep.secondPoint,
                  prefixIcon: Icons.looks_two,
                ),
            ],
          ),
        ),
      if (_step == CalibrationStep.completed)
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle,
                  size: 48.sp, color: AppTheme.successColor),
              SizedBox(height: 8.h),
              Text('校准完成',
                  style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 4.h),
              Text(
                  '斜率=${_params.slope.toStringAsFixed(6)}, 截距=${_params.intercept.toStringAsFixed(6)}, 零点=${_params.zeroOffset.toStringAsFixed(3)} kg',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12.sp)),
              SizedBox(height: 12.h),
              CommonButton(
                text: '完成',
                onPressed: _handleCancel,
                type: ButtonType.primary,
                prefixIcon: Icons.done,
                block: true,
              ),
            ],
          ),
        )
      else if (_capturedPoint2Raw != null && _step != CalibrationStep.completed)
        CommonButton(
          text: '应用校准参数',
          onPressed: !_isOperating ? _handleApplyCalibration : null,
          loading: _isOperating,
          type: ButtonType.primary,
          prefixIcon: Icons.save,
          block: true,
          size: ButtonSize.large,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('三点校准向导',
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: _handleCancel,
                child: const Text('取消校准'),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...steps,
        ],
      ),
    );
  }

  Widget _buildStep({
    required int step,
    required String title,
    required String subtitle,
    required bool active,
    required bool done,
    required Widget content,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: done
                  ? AppTheme.successColor
                  : active
                      ? AppTheme.primaryColor
                      : AppTheme.dividerColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: done
                ? Icon(Icons.check, size: 18.sp, color: Colors.white)
                : Text('$step',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppTheme.textPrimary
                            : AppTheme.textHint)),
                SizedBox(height: 2.h),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.sp, color: AppTheme.textSecondary)),
                SizedBox(height: 10.h),
                if (active) content,
                SizedBox(height: 12.h),
                const Divider(height: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (ctx) {
        final history = _scaleService.history;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx2, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text('校准历史',
                      style: TextStyle(
                          fontSize: 18.sp, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: history.isEmpty
                      ? Center(
                          child: Text('暂无校准记录',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: history.length,
                          itemBuilder: (_, i) {
                            final r = history[i];
                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: AppTheme.dividerColor)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history,
                                          size: 16.sp,
                                          color: AppTheme.textSecondary),
                                      SizedBox(width: 6.w),
                                      Text(_formatTime(r.timestamp),
                                          style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w500)),
                                      const Spacer(),
                                      if (r.remark != null)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                          ),
                                          child: Text(r.remark!,
                                              style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: AppTheme.primaryColor)),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Wrap(
                                    spacing: 12.w,
                                    runSpacing: 4.h,
                                    children: [
                                      Text(
                                          '斜率: ${r.oldSlope.toStringAsFixed(4)} → ${r.newSlope.toStringAsFixed(4)}',
                                          style: TextStyle(
                                              fontSize: 12.sp,
                                              color: AppTheme.textSecondary)),
                                      Text(
                                          '零点: ${r.oldZero.toStringAsFixed(3)} → ${r.newZero.toStringAsFixed(3)} kg',
                                          style: TextStyle(
                                              fontSize: 12.sp,
                                              color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _statusText() {
    switch (_status) {
      case ScaleStatus.connected:
        return '已连接';
      case ScaleStatus.connecting:
        return '连接中...';
      case ScaleStatus.disconnected:
        return '未连接';
      case ScaleStatus.error:
        return '连接异常';
    }
  }

  String _formatTime(DateTime t) {
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }
}
