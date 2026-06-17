import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/app_theme.dart';
import '../providers/liquid_level_provider.dart';
import '../services/liquid_level_linkage_service.dart';
import '../services/liquid_level_sensor_service.dart';
import '../utils/toast_util.dart';
import '../widgets/empty_state.dart';

class LiquidLevelSensorPage extends StatefulWidget {
  const LiquidLevelSensorPage({super.key});

  @override
  State<LiquidLevelSensorPage> createState() => _LiquidLevelSensorPageState();
}

class _LiquidLevelSensorPageState extends State<LiquidLevelSensorPage> {
  final TextEditingController _containerCodeController = TextEditingController();
  final TextEditingController _nearFullController = TextEditingController();
  final TextEditingController _fullController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LiquidLevelProvider>();
      provider.init();
      _nearFullController.text = provider.nearFullThreshold.toString();
      _fullController.text = provider.fullThreshold.toString();
    });
  }

  @override
  void dispose() {
    _containerCodeController.dispose();
    _nearFullController.dispose();
    _fullController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('废液桶液位监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showThresholdDialog(context),
          ),
        ],
      ),
      body: Consumer<LiquidLevelProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildLevelGauge(provider),
              SizedBox(height: 16.h),
              _buildStatusCard(provider),
              SizedBox(height: 16.h),
              _buildBindingCard(provider),
              SizedBox(height: 16.h),
              _buildDeviceControl(provider),
              SizedBox(height: 16.h),
              _buildRecentAlerts(provider),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<LiquidLevelProvider>(
        builder: (context, provider, _) {
          if (provider.isConnected && provider.isSimulation) {
            return FloatingActionButton.extended(
              onPressed: () => _showSimulationDialog(context),
              icon: const Icon(Icons.tune),
              label: const Text('模拟液位'),
              backgroundColor: AppTheme.warningColor,
            );
          }
          if (!provider.isConnected) {
            return FloatingActionButton.extended(
              onPressed: () => provider.startScan(),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('扫描传感器'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLevelGauge(LiquidLevelProvider provider) {
    final level = provider.smoothedLevel;
    final state = provider.currentLevelState;

    Color gaugeColor;
    Color backgroundColor;
    String statusText;

    switch (state) {
      case LiquidLevelState.full:
        gaugeColor = AppTheme.dangerColor;
        backgroundColor = AppTheme.dangerColor.withOpacity(0.1);
        statusText = '已满 - 立即转运';
        break;
      case LiquidLevelState.nearFull:
        gaugeColor = AppTheme.warningColor;
        backgroundColor = AppTheme.warningColor.withOpacity(0.1);
        statusText = '接近满 - 准备转运';
        break;
      case LiquidLevelState.normal:
      default:
        gaugeColor = AppTheme.successColor;
        backgroundColor = AppTheme.successColor.withOpacity(0.1);
        statusText = '正常';
    }

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('当前液位', style: AppTextStyle.subtitle),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: gaugeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: gaugeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: 200.r,
            height: 200.r,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(200.r, 200.r),
                  painter: _LiquidGaugePainter(level: level, color: gaugeColor),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${level.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.bold,
                          color: gaugeColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        provider.isStable ? '液位稳定' : '采样中...',
                        style: AppTextStyle.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThresholdInfo('接近满阈值',
                  '${provider.nearFullThreshold.toStringAsFixed(0)}%',
                  AppTheme.warningColor),
              _buildThresholdInfo('满溢阈值',
                  '${provider.fullThreshold.toStringAsFixed(0)}%',
                  AppTheme.dangerColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: AppTextStyle.caption),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(LiquidLevelProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                provider.isSensorConnected
                    ? Icons.bluetooth_connected
                    : provider.isSimulation
                        ? Icons.sensors_off
                        : Icons.bluetooth_disabled,
                size: 24.r,
                color: provider.isConnected
                    ? AppTheme.successColor
                    : AppTheme.textHint,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.isSensorConnected
                          ? '传感器已连接'
                          : provider.isSimulation
                              ? '模拟模式运行中'
                              : '未连接传感器',
                      style: AppTextStyle.body
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      provider.connectedDeviceName ??
                          (provider.isSimulation
                              ? '模拟数据源: 模拟液位传感器'
                              : '请扫描并连接液位传感器'),
                      style: AppTextStyle.small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (provider.boundContainerCode != null) ...[
            SizedBox(height: 12.h),
            Divider(color: AppTheme.dividerColor, height: 1),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 20.r, color: AppTheme.primaryColor),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('绑定容器', style: AppTextStyle.caption),
                      SizedBox(height: 2.h),
                      Text(
                        provider.boundContainerCode!,
                        style: AppTextStyle.body
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  iconSize: 20.r,
                  onPressed: () => _showBindContainerDialog(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBindingCard(LiquidLevelProvider provider) {
    if (provider.boundContainerCode != null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 24.r, color: AppTheme.dangerColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              '未绑定废液桶容器，预警时无法自动创建转运联单。请绑定容器编码。',
              style: AppTextStyle.body.copyWith(color: AppTheme.dangerColor),
            ),
          ),
          TextButton(
            onPressed: () => _showBindContainerDialog(context),
            child: const Text('立即绑定'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceControl(LiquidLevelProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices, size: 20.r, color: AppTheme.primaryColor),
              SizedBox(width: 8.w),
              Text('设备管理', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          if (provider.state == LiquidLevelPageState.scanning)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: const CircularProgressIndicator(),
              ),
            ),
          if (provider.state == LiquidLevelPageState.scanning &&
              provider.scannedDevices.isEmpty)
            EmptyState(
                icon: Icons.bluetooth_disabled, message: '未扫描到设备'),
          if (provider.scannedDevices.isNotEmpty)
            ...provider.scannedDevices.map(
              (d) => ListTile(
                leading: Icon(Icons.sensors, color: AppTheme.primaryColor),
                title: Text(d.name, style: AppTextStyle.body),
                subtitle: Text(d.address, style: AppTextStyle.small),
                trailing: ElevatedButton(
                  onPressed: () => provider.connectDevice(d.address),
                  child: const Text('连接'),
                ),
              ),
            ),
          SizedBox(height: 12.h),
          Row(
            children: [
              if (!provider.isConnected)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.startScan(),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('扫描设备'),
                  ),
                ),
              if (provider.isConnected)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.disconnect(),
                    icon: const Icon(Icons.link_off),
                    label: const Text('断开连接'),
                  ),
                ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBindContainerDialog(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('绑定容器'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts(LiquidLevelProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active,
                  size: 20.r, color: AppTheme.warningColor),
              SizedBox(width: 8.w),
              Text('最近预警', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          if (provider.recentAlerts.isEmpty)
            EmptyState(
                icon: Icons.notifications_none, message: '暂无预警记录')
          else
            ...provider.recentAlerts.map((alert) {
              final isFull = alert.state == LiquidLevelState.full;
              final color = isFull ? AppTheme.dangerColor : AppTheme.warningColor;
              final title = isFull ? '满溢预警' : '接近满预警';
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isFull ? Icons.error : Icons.warning,
                              size: 18.r,
                              color: color,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              title,
                              style: AppTextStyle.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${alert.level.toStringAsFixed(1)}%',
                          style: AppTextStyle.subtitle.copyWith(color: color),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      alert.containerCode != null
                          ? '容器: ${alert.containerCode}，阈值 ${alert.threshold.toStringAsFixed(0)}%'
                          : '阈值 ${alert.threshold.toStringAsFixed(0)}%',
                      style: AppTextStyle.small,
                    ),
                    if (alert.transferOrderNo != null) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.article_outlined,
                              size: 14.r, color: AppTheme.primaryColor),
                          SizedBox(width: 4.w),
                          Text(
                            '转运联单: ${alert.transferOrderNo}',
                            style: AppTextStyle.small
                                .copyWith(color: AppTheme.primaryColor),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.transferOrderDetail,
                                arguments: {'order_no': alert.transferOrderNo},
                              );
                            },
                            child: Text(
                              '查看详情',
                              style: AppTextStyle.small.copyWith(
                                  color: AppTheme.primaryColor,
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  void _showBindContainerDialog(BuildContext context) {
    final provider = context.read<LiquidLevelProvider>();
    _containerCodeController.text = provider.boundContainerCode ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('绑定废液桶容器'),
        content: TextField(
          controller: _containerCodeController,
          decoration: InputDecoration(
            hintText: '请输入容器编码',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
        actions: [
          if (provider.boundContainerCode != null)
            TextButton(
              onPressed: () {
                provider.unbindContainer();
                Navigator.pop(ctx);
                ToastUtil.show('已解除绑定');
              },
              child: const Text('解除绑定'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _containerCodeController.text.trim();
              if (code.isEmpty) {
                ToastUtil.show('请输入容器编码');
                return;
              }
              provider.bindContainer(code);
              Navigator.pop(ctx);
              ToastUtil.show('绑定成功');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showThresholdDialog(BuildContext context) {
    final provider = context.read<LiquidLevelProvider>();
    _nearFullController.text = provider.nearFullThreshold.toString();
    _fullController.text = provider.fullThreshold.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('阈值设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nearFullController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '接近满阈值 (%)',
                hintText: '默认 80%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _fullController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '满溢阈值 (%)',
                hintText: '默认 95%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final nearFull = double.tryParse(_nearFullController.text);
              final full = double.tryParse(_fullController.text);
              if (nearFull == null || nearFull < 0 || nearFull > 100) {
                ToastUtil.show('接近满阈值无效');
                return;
              }
              if (full == null || full <= nearFull || full > 100) {
                ToastUtil.show('满溢阈值必须大于接近满阈值');
                return;
              }
              provider.setThresholds(nearFull: nearFull, full: full);
              Navigator.pop(ctx);
              ToastUtil.show('设置已保存');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showSimulationDialog(BuildContext context) {
    final provider = context.read<LiquidLevelProvider>();
    double simLevel = provider.smoothedLevel;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('模拟液位值'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${simLevel.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 16.h),
              Slider(
                value: simLevel,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (v) {
                  setDialogState(() => simLevel = v);
                  provider.setSimulationLevel(v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGaugePainter extends CustomPainter {
  final double level;
  final Color color;

  _LiquidGaugePainter({required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final sweepAngle = 2 * 3.14159 * (level / 100);

    canvas.drawCircle(center, radius - 8, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius - 8);
    canvas.drawArc(rect, -3.14159 / 2, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGaugePainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.color != color;
  }
}

class LiquidLevelAlertDialog extends StatelessWidget {
  final LiquidLevelAlertEvent event;
  final VoidCallback? onDismiss;
  final VoidCallback? onViewOrder;

  const LiquidLevelAlertDialog({
    super.key,
    required this.event,
    this.onDismiss,
    this.onViewOrder,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = event.state == LiquidLevelState.full;
    final color = isFull ? AppTheme.dangerColor : AppTheme.warningColor;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFull ? Icons.error : Icons.warning_rounded,
              size: 64.r,
              color: color,
            ),
            SizedBox(height: 12.h),
            Text(
              isFull ? '废液桶满溢预警' : '废液桶接近满',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '当前液位: ${event.level.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            if (event.containerCode != null)
              Text(
                '容器: ${event.containerCode}',
                style: AppTextStyle.body,
              ),
            SizedBox(height: 12.h),
            if (event.transferOrderNo != null) ...[
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined,
                        size: 20.r, color: AppTheme.primaryColor),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('已自动生成转运联单', style: AppTextStyle.caption),
                          Text(
                            event.transferOrderNo!,
                            style: AppTextStyle.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],
            Row(
              children: [
                if (event.transferOrderNo != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onViewOrder?.call();
                      },
                      child: const Text('查看联单'),
                    ),
                  ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onDismiss?.call();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: const Text('知道了'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
