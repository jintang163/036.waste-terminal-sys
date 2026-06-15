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

  StreamSubscription<ScaleReading>? _weightSub;
  StreamSubscription<ScaleServiceStatus>? _statusSub;
  StreamSubscription<CalibrationStep>? _calibrationStepSub;
  StreamSubscription<ScaleCalibrationParams>? _paramsSub;
  StreamSubscription<bool>? _stableSub;

  double _rawWeight = 0.0;
  double _calibratedWeight = 0.0;
  double _netWeight = 0.0;
  bool _isStable = false;
  ScaleServiceStatus _status = ScaleServiceStatus.idle;
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
      _params = _scaleService.params;
    });
  }

  void _subscribeStreams() {
    _weightSub = _scaleService.weightStream.listen((w) {
      if (!mounted) return;
      setState(() {
        _netWeight = w.netWeight;
        _rawWeight = w.rawWeight;
        _calibratedWeight = w.calibratedWeight;
      });
    });
    _stableSub = _scaleService.stableStream.listen((s) {
      if (!mounted) return;
      setState(() => _isStable = s);
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
    _stableSub?.cancel();
    _point1WeightCtrl.dispose();
    _point2WeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoConnectScale() async {
    try {
      // 已连蓝牙：复用已有连接，仅让 ScaleService 按地址加载专属参数并订阅真实流
      final addr = _bluetoothService.connectedDeviceAddress;
      if (_bluetoothService.isConnected && addr != null) {
        await _scaleService.loadSavedParams(deviceAddress: addr);
        if (!mounted) return;
        setState(() => _params = _scaleService.params);
      }
      // 未连接：调用统一的 connectAndAttach
      if (!_bluetoothService.isConnected) {
        await _scaleService.connectAndAttach();
      } else {
        // 手动触发一次订阅（因为 connectAndAttach 没被调）
        _scaleService.updateRawWeightFromBluetooth(_rawWeight);
      }
    } catch (_) {
      // 自动连接失败不提示，用户可手动连接
    }
  }

  Future<void> _handleConnect() async {
    setState(() => _isOperating = true);
    try {
      final ok = await _scaleService.connectAndAttach();
      if (ok) {
        ToastUtil.showSuccess('地磅连接成功');
      } else {
        ToastUtil.showInfo('蓝牙不可用，已启用离线演示模式');
      }
    } catch (e) {
      ToastUtil.showError(
          '连接失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  bool _get isScaleSourceReady =>
      _status == ScaleServiceStatus.connected ||
      _status == ScaleServiceStatus.calibrating ||
      _status == ScaleServiceStatus.simulating;

  Future<void> _handleZero() async {
    if (!_isScaleSourceReady) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    setState(() => _isOperating = true);
    try {
      await _scaleService.zero();
      ToastUtil.showSuccess('归零成功(${_params.synergyModeText})');
    } catch (e) {
      ToastUtil.showError(
          '归零失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleTare() async {
    if (!_isScaleSourceReady) {
      ToastUtil.showError('地磅未连接');
      return;
    }
    setState(() => _isOperating = true);
    try {
      await _scaleService.tare();
      ToastUtil.showSuccess('去皮完成(${_params.synergyModeText})');
    } catch (e) {
      ToastUtil.showError(
          '去皮失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleClearTare() async {
    await _scaleService.clearTare();
    ToastUtil.showSuccess('软件皮重已清除');
  }

  void _handleStartCalibration() {
    _point1WeightCtrl.clear();
    _point2WeightCtrl.clear();
    _capturedZeroRaw = null;
    _capturedPoint1Raw = null;
    _capturedPoint2Raw = null;
    _scaleService.startCalibration();
  }

  Future<void> _handleCaptureZero() async {
    setState(() => _isOperating = true);
    try {
      final raw = await _scaleService.captureZeroPoint();
      _capturedZeroRaw = raw;
      ToastUtil.showSuccess('零点已采集: ${raw.toStringAsFixed(3)} kg');
    } catch (e) {
      ToastUtil.showError(
          '采集失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleCapturePoint1() async {
    final w = double.tryParse(_point1WeightCtrl.text.trim());
    if (w == null || w <= 0) {
      ToastUtil.showError('请输入有效的标准重量1 (kg)');
      return;
    }
    setState(() => _isOperating = true);
    try {
      final raw = await _scaleService.captureFirstPoint(w);
      _capturedPoint1Raw = raw;
      ToastUtil.showSuccess('点1已采集: ${w}kg → ${raw.toStringAsFixed(3)}');
    } catch (e) {
      ToastUtil.showError(
          '采集失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleCapturePoint2() async {
    final w = double.tryParse(_point2WeightCtrl.text.trim());
    if (w == null || w <= 0) {
      ToastUtil.showError('请输入有效的标准重量2 (kg)');
      return;
    }
    setState(() => _isOperating = true);
    try {
      final raw = await _scaleService.captureSecondPoint(w);
      _capturedPoint2Raw = raw;
      ToastUtil.showSuccess('点2已采集: ${w}kg → ${raw.toStringAsFixed(3)}');
    } catch (e) {
      ToastUtil.showError(
          '采集失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _handleApplyCalibration() async {
    setState(() => _isOperating = true);
    try {
      final result = await _scaleService.applyCalibration();
      ToastUtil.showSuccess(
          '校准成功！斜率=${result.slope.toStringAsFixed(6)}, 截距=${result.intercept.toStringAsFixed(6)}');
      _capturedZeroRaw = null;
      _capturedPoint1Raw = null;
      _capturedPoint2Raw = null;
    } catch (e) {
      ToastUtil.showError(
          '校准失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  void _handleCancelCalibration() {
    _scaleService.cancelCalibration();
    _capturedZeroRaw = null;
    _capturedPoint1Raw = null;
    _capturedPoint2Raw = null;
    ToastUtil.showInfo('已取消校准');
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('将恢复默认校准参数，确定继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true) return;
    await _scaleService.resetToDefault();
    ToastUtil.showSuccess('已恢复默认参数');
  }

  Future<void> _handleHistory() async {
    final list = _scaleService.historyForDevice(_params.deviceAddress);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('校准历史', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close)),
                ],
              ),
              SizedBox(height: 4.h),
              Text('当前设备: ${_params.deviceName ?? ''} ${_params.deviceAddress ?? ''}',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary)),
              SizedBox(height: 8.h),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('暂无历史记录'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => Divider(height: 1.h),
                        itemBuilder: (_, i) {
                          final r = list[i];
                          final ts =
                              '${r.timestamp.month.toString().padLeft(2, '0')}-${r.timestamp.day.toString().padLeft(2, '0')} '
                              '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(r.actionTypeText,
                                          style: TextStyle(
                                              fontSize: 10.sp,
                                              color: AppTheme.primaryColor)),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(ts,
                                        style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                    '斜率 ${r.oldSlope.toStringAsFixed(4)}→${r.newSlope.toStringAsFixed(4)}  '
                                    '截距 ${r.oldIntercept.toStringAsFixed(4)}→${r.newIntercept.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 11.sp)),
                                SizedBox(height: 2.h),
                                Text(
                                    '零点 ${r.oldZero.toStringAsFixed(3)}→${r.newZero.toStringAsFixed(3)}  '
                                    '皮重 ${r.oldTare.toStringAsFixed(3)}→${r.newTare.toStringAsFixed(3)}',
                                    style: TextStyle(fontSize: 11.sp)),
                                if (r.remark != null && r.remark!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(r.remark!,
                                        style: TextStyle(
                                            fontSize: 10.sp,
                                            color: AppTheme.textSecondary)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSynergyModeDialog() async {
    final mode = await showDialog<CalibrationSynergyMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择协同模式'),
        children: CalibrationSynergyMode.values.map((m) {
          String title;
          String desc;
          switch (m) {
            case CalibrationSynergyMode.hardwareFirst:
              title = '硬件优先 + 软件回退（推荐）';
              desc = '先发送硬件指令；失败时自动使用软件补偿';
              break;
            case CalibrationSynergyMode.softwareOnly:
              title = '仅软件补偿';
              desc = '不发送硬件指令，仅在应用层扣减（离线可用）';
              break;
            case CalibrationSynergyMode.hardwareOnly:
              title = '仅硬件指令';
              desc = '只发送硬件指令，失败直接报错不补偿';
              break;
          }
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, m),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 2.h),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12.sp, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
    if (mode != null) {
      await _scaleService.setSynergyMode(mode);
      ToastUtil.showSuccess('协同模式已切换');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('地磅校准'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              tooltip: '校准历史',
              onPressed: _handleHistory,
              icon: const Icon(Icons.history)),
          IconButton(
              tooltip: '恢复默认',
              onPressed: _handleReset,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWeightDisplay(),
            SizedBox(height: 12.h),
            _buildStatusCard(),
            SizedBox(height: 12.h),
            _buildQuickActions(),
            SizedBox(height: 12.h),
            _buildCalibrationCard(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColorDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeightLabel('净重', primary: true),
              _buildWeightLabel('原始'),
              _buildWeightLabel('校准后'),
              _buildWeightLabel('皮重'),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_netWeight.toStringAsFixed(3),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w800)),
              Text(_rawWeight.toStringAsFixed(3),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600)),
              Text(_calibratedWeight.toStringAsFixed(3),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600)),
              Text(_params.totalTare.toStringAsFixed(3),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12.sp)),
              Text('kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12.sp)),
              Text('kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12.sp)),
              Text('kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12.sp)),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: (_isStable ? Colors.green : Colors.orange).withOpacity(0.25),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _isStable ? Icons.check_circle : Icons.sync,
                    color: _isStable ? Colors.greenAccent : Colors.amber,
                    size: 14.sp),
                SizedBox(width: 6.w),
                Text(_isStable ? '重量稳定' : '重量波动中…',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightLabel(String text, {bool primary = false}) {
    return Text(text,
        style: TextStyle(
            color: primary
                ? Colors.white
                : Colors.white.withOpacity(0.75),
            fontSize: primary ? 14.sp : 12.sp,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w400));
  }

  Widget _buildStatusCard() {
    String statusText;
    Color statusColor;
    switch (_status) {
      case ScaleServiceStatus.idle:
        statusText = '未连接';
        statusColor = AppTheme.textSecondary;
        break;
      case ScaleServiceStatus.connecting:
        statusText = '连接中…';
        statusColor = Colors.orange;
        break;
      case ScaleServiceStatus.connected:
        statusText = '蓝牙已连接（真实数据）';
        statusColor = Colors.green;
        break;
      case ScaleServiceStatus.simulating:
        statusText = '离线演示模式';
        statusColor = Colors.blue;
        break;
      case ScaleServiceStatus.calibrating:
        statusText = '校准进行中';
        statusColor = AppTheme.primaryColor;
        break;
      case ScaleServiceStatus.error:
        statusText = '错误';
        statusColor = Colors.red;
        break;
    }

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [AppConfig.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6.r)),
                child: Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6.r)),
                child: Text(_params.statusText,
                    style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              if (_status == ScaleServiceStatus.idle)
                TextButton(
                    onPressed: _isOperating ? null : _handleConnect,
                    child: Text('连接地磅',
                        style: TextStyle(color: AppTheme.primaryColor))),
            ],
          ),
          SizedBox(height: 10.h),
          if (_params.deviceAddress != null)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(children: [
                Icon(Icons.bluetooth, size: 14.sp, color: AppTheme.textSecondary),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                      '${_params.deviceName ?? '地磅'} · ${_params.deviceAddress}',
                      style: TextStyle(
                          fontSize: 12.sp, color: AppTheme.textSecondary)),
                ),
              ]),
            ),
          SizedBox(height: 4.h),
          InkWell(
            onTap: _showSynergyModeDialog,
            child: Row(
              children: [
                Icon(Icons.settings_ethernet,
                    size: 14.sp, color: AppTheme.textSecondary),
                SizedBox(width: 6.w),
                Text('协同模式: ',
                    style: TextStyle(
                        fontSize: 12.sp, color: AppTheme.textSecondary)),
                Text(_params.synergyModeText,
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 16.sp, color: AppTheme.textSecondary),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          const Divider(),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 10.h,
            children: [
              _buildParamItem('斜率', _params.slope.toStringAsFixed(6)),
              _buildParamItem('截距', _params.intercept.toStringAsFixed(6)),
              _buildParamItem(
                  '硬件零点', '${_params.hardwareZeroOffset.toStringAsFixed(3)} kg'),
              _buildParamItem(
                  '软件零点', '${_params.softwareZeroOffset.toStringAsFixed(3)} kg'),
              _buildParamItem(
                  '硬件皮重', '${_params.hardwareTare.toStringAsFixed(3)} kg'),
              _buildParamItem(
                  '软件皮重', '${_params.softwareTare.toStringAsFixed(3)} kg'),
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
      width: (MediaQuery.of(context).size.width - 64.w) / 2,
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12.sp, color: AppTheme.textSecondary)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: CommonButton(
            text: '一键归零',
            icon: Icons.exposure_zero,
            onPressed: (_isOperating || !_isScaleSourceReady) ? null : _handleZero,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: CommonButton(
            text: '去皮',
            icon: Icons.line_weight,
            onPressed: (_isOperating || !_isScaleSourceReady) ? null : _handleTare,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: CommonButton(
            text: '清皮重',
            icon: Icons.remove_circle_outline,
            type: ButtonType.secondary,
            onPressed: _isOperating ? null : _handleClearTare,
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [AppConfig.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('三点线性校准向导',
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              if (_step != CalibrationStep.idle &&
                  _step != CalibrationStep.completed)
                TextButton(
                  onPressed: _handleCancelCalibration,
                  child: const Text('取消校准'),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '通过「空秤 + 2 个标准砝码」推导斜率与截距，确保称量精度',
            style: TextStyle(
                fontSize: 12.sp, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 12.h),
          if (_step == CalibrationStep.idle ||
              _step == CalibrationStep.completed ||
              _step == CalibrationStep.cancelled)
            SizedBox(
              width: double.infinity,
              child: CommonButton(
                text: '开始校准',
                icon: Icons.tune,
                onPressed: (!_isScaleSourceReady || _isOperating)
                    ? null
                    : _handleStartCalibration,
              ),
            )
          else ..._buildWizardSteps(),
        ],
      ),
    );
  }

  List<Widget> _buildWizardSteps() {
    final step = _step;
    return [
      _buildStepTile(
        1,
        '零点采集（空秤）',
        _capturedZeroRaw != null
            ? '已采集: ${_capturedZeroRaw!.toStringAsFixed(3)} kg'
            : '请确保秤上无任何物品',
        step == CalibrationStep.waitingZero,
        _capturedZeroRaw != null,
        onAction: (step == CalibrationStep.waitingZero)
            ? (_isOperating ? null : _handleCaptureZero)
            : null,
        actionText: '捕获零点',
      ),
      _buildStepTile(
        2,
        '第一点校准（砝码1）',
        _capturedPoint1Raw != null
            ? '${_point1WeightCtrl.text}kg → ${_capturedPoint1Raw!.toStringAsFixed(3)}'
            : '请放置第一个标准砝码并输入重量',
        step == CalibrationStep.waitingFirstWeight,
        _capturedPoint1Raw != null,
        textField: (step == CalibrationStep.waitingFirstWeight)
            ? TextField(
                controller: _point1WeightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '标准重量1 (kg)',
                  hintText: '如 10.000',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            : null,
        onAction: (step == CalibrationStep.waitingFirstWeight)
            ? (_isOperating ? null : _handleCapturePoint1)
            : null,
        actionText: '捕获点1',
      ),
      _buildStepTile(
        3,
        '第二点校准（砝码2）',
        _capturedPoint2Raw != null
            ? '${_point2WeightCtrl.text}kg → ${_capturedPoint2Raw!.toStringAsFixed(3)}'
            : '请放置更大的第二个标准砝码',
        step == CalibrationStep.waitingSecondWeight,
        _capturedPoint2Raw != null,
        textField: (step == CalibrationStep.waitingSecondWeight)
            ? TextField(
                controller: _point2WeightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '标准重量2 (kg)',
                  hintText: '如 50.000（需大于点1）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            : null,
        onAction: (step == CalibrationStep.waitingSecondWeight)
            ? (_isOperating ? null : _handleCapturePoint2)
            : (_capturedPoint1Raw != null && _capturedPoint2Raw != null)
                ? (_isOperating ? null : _handleApplyCalibration)
                : null,
        actionText: (step == CalibrationStep.waitingSecondWeight)
            ? '捕获点2'
            : '应用校准',
        primaryAction: step != CalibrationStep.waitingSecondWeight,
      ),
      SizedBox(height: 8.h),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Text(
            '斜率=${_params.slope.toStringAsFixed(6)}, 截距=${_params.intercept.toStringAsFixed(6)}, 零点=${_params.totalZeroOffset.toStringAsFixed(3)} kg',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12.sp)),
      ),
    ];
  }

  Widget _buildStepTile(
    int index,
    String title,
    String subtitle,
    bool isActive,
    bool isCompleted, {
    Widget? textField,
    VoidCallback? onAction,
    String? actionText,
    bool primaryAction = true,
  }) {
    Color color;
    if (isCompleted) {
      color = Colors.green;
    } else if (isActive) {
      color = AppTheme.primaryColor;
    } else {
      color = Colors.grey;
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? Icon(Icons.check, color: color, size: 16.sp)
                : Text('$index',
                    style: TextStyle(
                        color: color,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isActive ? AppTheme.primaryColor : AppTheme.textPrimary)),
                SizedBox(height: 2.h),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.sp, color: AppTheme.textSecondary)),
                if (textField != null) ...[
                  SizedBox(height: 8.h),
                  SizedBox(width: 200.w, child: textField),
                ],
                if (onAction != null && actionText != null) ...[
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: 140.w,
                    height: 36.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAction
                            ? AppTheme.primaryColor
                            : AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r)),
                      ),
                      onPressed: onAction,
                      child: Text(actionText,
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
