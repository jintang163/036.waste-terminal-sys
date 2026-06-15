import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../config/app_routes.dart';
import '../services/bluetooth_service.dart';
import '../services/waste_out_service.dart';
import '../services/transfer_order_service.dart';
import '../services/inventory_service.dart';
import '../services/video_player_service.dart';
import '../services/camera_service.dart';
import '../services/face_auth_service.dart';
import '../providers/app_provider.dart';
import '../widgets/common_button.dart';
import '../utils/toast_util.dart';
import '../utils/uuid_util.dart';
import '../utils/date_util.dart';
import '../utils/qr_util.dart';
import '../models/waste_out_record.dart';
import '../models/transfer_order.dart';
import '../models/waste_inventory.dart';
import '../models/enterprise.dart';
import '../models/camera_model.dart';
import 'face_verify_page.dart';

class WasteOutPage extends StatefulWidget {
  const WasteOutPage({super.key});

  @override
  State<WasteOutPage> createState() => _WasteOutPageState();
}

class _WasteOutPageState extends State<WasteOutPage> {
  final _formKey = GlobalKey<FormState>();
  final _containerCodeController = TextEditingController();
  final _weightController = TextEditingController();
  final _vehicleNoController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _remarkController = TextEditingController();
  final _receiverSearchController = TextEditingController();
  final _transporterSearchController = TextEditingController();

  WasteInventory? _currentInventory;
  Enterprise? _selectedReceiver;
  Enterprise? _selectedTransporter;
  List<Enterprise> _receiverList = [];
  List<Enterprise> _transporterList = [];
  List<Enterprise> _filteredReceiverList = [];
  List<Enterprise> _filteredTransporterList = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _generatedOrderNo;
  String? _generatedOutNo;

  final VideoPlayerService _videoPlayerService = VideoPlayerService();
  final CameraService _cameraService = CameraService();
  bool _enableOperationRecord = true;
  CameraModel? _selectedCamera;
  List<CameraModel> _cameraList = [];
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadEnterprises();
    _loadCameras();
  }

  @override
  void dispose() {
    _containerCodeController.dispose();
    _weightController.dispose();
    _vehicleNoController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _remarkController.dispose();
    _receiverSearchController.dispose();
    _transporterSearchController.dispose();
    _videoPlayerService.disconnect();
    super.dispose();
  }

  Future<void> _loadEnterprises() async {
    setState(() => _isLoading = true);
    try {
      final inventoryService = InventoryService();
      final allInventory = await inventoryService.getAllInventory();
      final Set<int> enterpriseIds = {};
      for (var item in allInventory) {
        if (item['enterprise_id'] != null) {
          enterpriseIds.add(item['enterprise_id'] as int);
        }
      }

      final appProvider = context.read<AppProvider>();
      final currentEnterpriseId = appProvider.enterpriseInfo?['id'];

      List<Enterprise> receivers = [];
      List<Enterprise> transporters = [];

      if (appProvider.enterpriseInfo != null) {
        final List<dynamic> cachedEnterprises =
            appProvider.enterpriseInfo?['cachedEnterprises'] as List<dynamic>? ?? [];
        for (var e in cachedEnterprises) {
          final enterprise = Enterprise.fromJson(Map<String, dynamic>.from(e));
          if (enterprise.id != currentEnterpriseId) {
            receivers.add(enterprise);
          }
        }
      }

      if (receivers.isEmpty) {
        receivers = _buildDefaultReceivers();
      }
      transporters = _buildDefaultTransporters();

      setState(() {
        _receiverList = receivers;
        _transporterList = transporters;
        _filteredReceiverList = receivers;
        _filteredTransporterList = transporters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ToastUtil.showError('加载企业列表失败');
    }
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await _cameraService.getCameraList();
      setState(() {
        _cameraList = cameras;
        if (_cameraList.isNotEmpty) {
          _selectedCamera = _cameraList.first;
          _startRingBuffer();
        }
      });
    } catch (e) {
      // 摄像头加载失败不影响主流程
    }
  }

  Future<void> _startRingBuffer() async {
    if (_selectedCamera == null || !_enableOperationRecord) return;
    try {
      final previewUrl = await _cameraService.getPreviewUrlByCode(_selectedCamera!.cameraCode ?? '');
      if (previewUrl != null && previewUrl.isNotEmpty) {
        await _videoPlayerService.startRingBuffer(
          previewUrl,
          cameraCode: _selectedCamera!.cameraCode,
        );
      }
    } catch (e) {
      // 环形缓冲启动失败不影响主流程
    }
  }

  Future<bool> _triggerOperationRecord(String recordNo) async {
    if (!_enableOperationRecord || _selectedCamera == null) return false;
    try {
      setState(() {
        _isRecording = true;
      });
      final success = await _videoPlayerService.triggerEventRecord(
        cameraCode: _selectedCamera!.cameraCode ?? '',
        triggerType: 'waste_out',
        triggerId: recordNo,
      );
      return success;
    } catch (e) {
      ToastUtil.showWarning('操作录像触发失败: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  List<Enterprise> _buildDefaultReceivers() {
    return [
      Enterprise(
        id: 1001,
        enterpriseName: '绿源环保处置有限公司',
        enterpriseCode: 'R20240001',
      ),
      Enterprise(
        id: 1002,
        enterpriseName: '中节能危废处置中心',
        enterpriseCode: 'R20240002',
      ),
      Enterprise(
        id: 1003,
        enterpriseName: '东江环保股份有限公司',
        enterpriseCode: 'R20240003',
      ),
    ];
  }

  List<Enterprise> _buildDefaultTransporters() {
    return [
      Enterprise(
        id: 2001,
        enterpriseName: '安达危废运输有限公司',
        enterpriseCode: 'T20240001',
      ),
      Enterprise(
        id: 2002,
        enterpriseName: '顺丰危运物流公司',
        enterpriseCode: 'T20240002',
      ),
    ];
  }

  Future<void> _scanContainerCode() async {
    try {
      final result = await Navigator.pushNamed(context, AppRoutes.scan);
      if (result != null && result is String && result.isNotEmpty) {
        _containerCodeController.text = result;
        await _loadInventoryByContainerCode(result);
      }
    } catch (e) {
      ToastUtil.showError('扫码失败');
    }
  }

  Future<void> _loadInventoryByContainerCode(String code) async {
    setState(() => _isLoading = true);
    try {
      final containerCode = QrUtil.parseWasteContainerQr(code) ?? code;
      final inventoryService = InventoryService();
      final List<Map<String, dynamic>> results =
          await inventoryService.getInventoryByContainerId(containerCode);

      if (results.isEmpty) {
        final allInventory = await inventoryService.getAllInventory();
        final matched = allInventory.where((item) =>
            item['container_code'] != null &&
            item['container_code'].toString().contains(containerCode));

        if (matched.isEmpty) {
          ToastUtil.showError('未找到该容器的库存信息');
          setState(() {
            _currentInventory = null;
            _weightController.clear();
            _isLoading = false;
          });
          return;
        }

        final data = matched.first;
        final inventory = WasteInventory.fromJson(data);
        setState(() {
          _currentInventory = inventory;
          _weightController.text =
              (inventory.weight ?? 0).toStringAsFixed(AppConfig.weightDecimalPlaces);
          _isLoading = false;
        });
      } else {
        final inventory = WasteInventory.fromJson(results.first);
        setState(() {
          _currentInventory = inventory;
          _weightController.text =
              (inventory.weight ?? 0).toStringAsFixed(AppConfig.weightDecimalPlaces);
          _isLoading = false;
        });
      }
      ToastUtil.showSuccess('容器信息加载成功');
    } catch (e) {
      setState(() => _isLoading = false);
      ToastUtil.showError('加载库存信息失败');
    }
  }

  void _filterReceivers(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredReceiverList = _receiverList;
      } else {
        _filteredReceiverList = _receiverList
            .where((e) =>
                (e.enterpriseName ?? '').contains(keyword) ||
                (e.enterpriseCode ?? '').contains(keyword))
            .toList();
      }
    });
  }

  void _filterTransporters(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredTransporterList = _transporterList;
      } else {
        _filteredTransporterList = _transporterList
            .where((e) =>
                (e.enterpriseName ?? '').contains(keyword) ||
                (e.enterpriseCode ?? '').contains(keyword))
            .toList();
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentInventory == null) {
      ToastUtil.showError('请先扫描容器二维码');
      return;
    }

    if (_selectedReceiver == null) {
      ToastUtil.showError('请选择接收单位');
      return;
    }

    if (_selectedTransporter == null) {
      ToastUtil.showError('请选择运输单位');
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ToastUtil.showError('请输入有效的出库重量');
      return;
    }

    if (weight > (_currentInventory?.weight ?? 0)) {
      ToastUtil.showError('出库重量不能超过当前库存重量');
      return;
    }

    final appProvider = context.read<AppProvider>();
    final currentUsername = appProvider.username ?? '';
    final faceAuthService = FaceAuthService();
    final hasEnrolledFace = await faceAuthService.hasEnrolledFace(currentUsername);
    FaceAuthResult? authResult;
    final outNo = UuidUtil.generateWasteOutNo();

    if (hasEnrolledFace) {
      authResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => FaceVerifyPage(
            authType: 'waste_out',
            businessType: 'waste_out',
            businessNo: outNo,
            targetUsername: currentUsername,
            autoNavigateOnSuccess: true,
          ),
        ),
      );

      if (authResult == null || !authResult.success) {
        ToastUtil.showWarning('人脸验证未通过，无法保存');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final appProvider = context.read<AppProvider>();
      final orderNo = UuidUtil.generateTransferOrderNo();
      final offlineId = UuidUtil.generateOfflineId('WO');
      final orderOfflineId = UuidUtil.generateOfflineId('TO');
      final now = DateTime.now();

      final wasteOutRecord = WasteOutRecord(
        outNo: outNo,
        containerId: _currentInventory!.containerId,
        containerCode: _currentInventory!.containerCode,
        wasteId: _currentInventory!.wasteId,
        wasteCode: _currentInventory!.wasteCode,
        wasteName: _currentInventory!.wasteName,
        weight: weight,
        receiverUnitId: _selectedReceiver!.id,
        receiverUnitName: _selectedReceiver!.enterpriseName,
        transporterId: _selectedTransporter!.id,
        transporterName: _selectedTransporter!.enterpriseName,
        vehicleNo: _vehicleNoController.text.trim(),
        driverName: _driverNameController.text.trim(),
        driverPhone: _driverPhoneController.text.trim(),
        outTime: now,
        operatorId: appProvider.userInfo?['id'] as int?,
        operatorName: appProvider.username,
        remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
        status: 0,
        syncStatus: 0,
        offlineId: offlineId,
        enterpriseId: appProvider.enterpriseInfo?['id'] as int?,
        faceAuthId: authResult?.authId,
        faceId: authResult?.userFace?.faceId,
        operatorFaceImage: authResult?.capturedImage != null
            ? base64Encode(authResult!.capturedImage!)
            : null,
      );

      final transferOrderItem = TransferOrderItem(
        wasteId: _currentInventory!.wasteId,
        wasteCode: _currentInventory!.wasteCode,
        wasteName: _currentInventory!.wasteName,
        wasteCategory: _currentInventory!.wasteCategory,
        hazardCode: _currentInventory!.hazardCode,
        containerCode: _currentInventory!.containerCode,
        weight: weight,
      );

      final transferOrder = TransferOrder(
        orderNo: orderNo,
        orderType: 'OUT',
        generatorUnitId: appProvider.enterpriseInfo?['id'] as int?,
        generatorUnitName: appProvider.enterpriseInfo?['name'] as String?,
        generatorUnitCode: appProvider.enterpriseInfo?['code'] as String?,
        receiverUnitId: _selectedReceiver!.id,
        receiverUnitName: _selectedReceiver!.enterpriseName,
        receiverUnitCode: _selectedReceiver!.enterpriseCode,
        transporterId: _selectedTransporter!.id,
        transporterName: _selectedTransporter!.enterpriseName,
        vehicleNo: _vehicleNoController.text.trim(),
        driverName: _driverNameController.text.trim(),
        totalWeight: weight,
        totalContainers: 1,
        items: [transferOrderItem],
        startTime: now,
        status: 0,
        syncStatus: 0,
        qrCode: QrUtil.generateTransferOrderQr(orderNo),
        offlineId: orderOfflineId,
        operatorId: appProvider.userInfo?['id'] as int?,
        operatorName: appProvider.username,
        enterpriseId: appProvider.enterpriseInfo?['id'] as int?,
      );

      final wasteOutService = WasteOutService();
      await wasteOutService.addWasteOutRecord(wasteOutRecord.toDbMap());

      final transferOrderService = TransferOrderService();
      await transferOrderService.createTransferOrder(transferOrder.toJson());

      setState(() {
        _generatedOutNo = outNo;
        _generatedOrderNo = orderNo;
        _isSaving = false;
      });

      ToastUtil.showSuccess('出库保存成功');

      if (_enableOperationRecord && _selectedCamera != null) {
        _triggerOperationRecord(outNo);
      }

      _showResultDialog(transferOrder);
    } catch (e) {
      setState(() => _isSaving = false);
      ToastUtil.showError('保存失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _showResultDialog(TransferOrder order) {
    final qrData = order.qrCode ?? QrUtil.generateTransferOrderQr(order.orderNo ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '出库成功',
          style: AppTextStyle.title,
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '转移联单号: ${order.orderNo}',
                style: AppTextStyle.body,
              ),
              SizedBox(height: 8.h),
              Text(
                '出库单号: $_generatedOutNo',
                style: AppTextStyle.bodySecondary,
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppTheme.bgPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 180.r,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '扫描二维码查看转移联单',
                style: AppTextStyle.caption,
              ),
            ],
          ),
        ),
        actions: [
          CommonButton(
            text: '打印出库单',
            type: ButtonType.outline,
            size: ButtonSize.small,
            onPressed: () => _printReceipt(order),
          ),
          CommonButton(
            text: '完成',
            type: ButtonType.primary,
            size: ButtonSize.small,
            onPressed: () {
              Navigator.pop(dialogContext);
              _resetForm();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(TransferOrder order) async {
    try {
      final bluetoothService = BluetoothService();
      final ready = await bluetoothService.checkPrinterReady();
      if (!ready) {
        ToastUtil.showError('打印机未连接，请先连接蓝牙打印机');
        return;
      }

      await bluetoothService.printWasteOutReceipt(
        outNo: _generatedOutNo ?? '',
        containerCode: _currentInventory?.containerCode ?? '',
        wasteCode: _currentInventory?.wasteCode ?? '',
        wasteName: _currentInventory?.wasteName ?? '',
        weight: order.totalWeight ?? 0,
        receiverUnit: order.receiverUnitName ?? '',
        operatorName: order.operatorName ?? '',
        printTime: DateUtil.formatDateTime(DateTime.now()),
      );

      ToastUtil.showSuccess('打印成功');
    } catch (e) {
      ToastUtil.showError('打印失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _resetForm() {
    _containerCodeController.clear();
    _weightController.clear();
    _vehicleNoController.clear();
    _driverNameController.clear();
    _driverPhoneController.clear();
    _remarkController.clear();
    _receiverSearchController.clear();
    _transporterSearchController.clear();
    setState(() {
      _currentInventory = null;
      _selectedReceiver = null;
      _selectedTransporter = null;
      _generatedOrderNo = null;
      _generatedOutNo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('危废出库'),
        actions: [
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              if (!provider.isOnline) {
                return Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 16.r, color: AppTheme.warningColor),
                      SizedBox(width: 4.w),
                      Text(
                        '离线',
                        style: TextStyle(fontSize: 12.sp, color: AppTheme.warningColor),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppPadding.page,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContainerScanSection(),
                    SizedBox(height: 16.h),
                    if (_currentInventory != null) ...[
                      _buildContainerInfoSection(),
                      SizedBox(height: 16.h),
                    ],
                    _buildReceiverSection(),
                    SizedBox(height: 16.h),
                    _buildTransporterSection(),
                    SizedBox(height: 16.h),
                    _buildWeightSection(),
                    SizedBox(height: 16.h),
                    _buildRemarkSection(),
                    SizedBox(height: 16.h),
                    if (_cameraList.isNotEmpty) _buildRecordSettingSection(),
                    SizedBox(height: 80.h),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildContainerScanSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner, size: AppSize.iconMedium, color: AppTheme.primaryColor),
                SizedBox(width: 8.w),
                Text('容器扫描', style: AppTextStyle.subtitle),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _containerCodeController,
                    decoration: InputDecoration(
                      labelText: '容器编码',
                      hintText: '请扫描或输入容器编码',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, size: AppSize.iconSmall),
                        onPressed: () {
                          _containerCodeController.clear();
                          setState(() {
                            _currentInventory = null;
                            _weightController.clear();
                          });
                        },
                      ),
                    ),
                    onFieldSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _loadInventoryByContainerCode(value);
                      }
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                SizedBox(
                  width: 44.w,
                  height: 44.h,
                  child: IconButton.filled(
                    icon: Icon(Icons.qr_code_scanner, size: 24.r),
                    onPressed: _scanContainerCode,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.textInverse,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerInfoSection() {
    final inventory = _currentInventory!;
    return Card(
      color: AppTheme.infoColor.withOpacity(0.05),
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, size: AppSize.iconMedium, color: AppTheme.infoColor),
                SizedBox(width: 8.w),
                Text('库存信息', style: AppTextStyle.subtitle),
              ],
            ),
            SizedBox(height: 12.h),
            _buildInfoRow('容器编码', inventory.containerCode ?? '-'),
            SizedBox(height: 8.h),
            _buildInfoRow('危废代码', inventory.wasteCode ?? '-'),
            SizedBox(height: 8.h),
            _buildInfoRow('危废名称', inventory.wasteName ?? '-'),
            SizedBox(height: 8.h),
            _buildInfoRow(
              '当前重量',
              '${(inventory.weight ?? 0).toStringAsFixed(AppConfig.weightDecimalPlaces)} kg',
              valueColor: AppTheme.primaryColor,
            ),
            if (inventory.wasteCategory != null) ...[
              SizedBox(height: 8.h),
              _buildInfoRow('废物类别', inventory.wasteCategory!),
            ],
            if (inventory.hazardCode != null) ...[
              SizedBox(height: 8.h),
              _buildInfoRow('危险特性', inventory.hazardCode!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(label, style: AppTextStyle.bodySecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyle.body.copyWith(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiverSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, size: AppSize.iconMedium, color: AppTheme.secondaryColor),
                SizedBox(width: 8.w),
                Text('接收单位', style: AppTextStyle.subtitle),
              ],
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _receiverSearchController,
              decoration: InputDecoration(
                labelText: '搜索接收单位',
                hintText: '输入名称或编码搜索',
                prefixIcon: Icon(Icons.search, size: AppSize.iconSmall),
                suffixIcon: _selectedReceiver != null
                    ? IconButton(
                        icon: Icon(Icons.check_circle, color: AppTheme.successColor, size: AppSize.iconSmall),
                        onPressed: null,
                      )
                    : null,
              ),
              onChanged: _filterReceivers,
            ),
            SizedBox(height: 8.h),
            ..._filteredReceiverList.map((enterprise) => _buildEnterpriseOption(
                  enterprise: enterprise,
                  isSelected: _selectedReceiver?.id == enterprise.id,
                  onTap: () {
                    setState(() {
                      _selectedReceiver = enterprise;
                      _receiverSearchController.text = enterprise.enterpriseName ?? '';
                    });
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTransporterSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, size: AppSize.iconMedium, color: AppTheme.accentColor),
                SizedBox(width: 8.w),
                Text('运输信息', style: AppTextStyle.subtitle),
              ],
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _transporterSearchController,
              decoration: InputDecoration(
                labelText: '搜索运输单位',
                hintText: '输入名称或编码搜索',
                prefixIcon: Icon(Icons.search, size: AppSize.iconSmall),
                suffixIcon: _selectedTransporter != null
                    ? IconButton(
                        icon: Icon(Icons.check_circle, color: AppTheme.successColor, size: AppSize.iconSmall),
                        onPressed: null,
                      )
                    : null,
              ),
              onChanged: _filterTransporters,
            ),
            SizedBox(height: 8.h),
            ..._filteredTransporterList.map((enterprise) => _buildEnterpriseOption(
                  enterprise: enterprise,
                  isSelected: _selectedTransporter?.id == enterprise.id,
                  onTap: () {
                    setState(() {
                      _selectedTransporter = enterprise;
                      _transporterSearchController.text = enterprise.enterpriseName ?? '';
                    });
                  },
                )),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _vehicleNoController,
              decoration: InputDecoration(
                labelText: '车牌号',
                hintText: '请输入车牌号',
                prefixIcon: Icon(Icons.directions_car, size: AppSize.iconSmall),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(20),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入车牌号';
                }
                return null;
              },
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _driverNameController,
                    decoration: InputDecoration(
                      labelText: '司机姓名',
                      hintText: '请输入司机姓名',
                      prefixIcon: Icon(Icons.person, size: AppSize.iconSmall),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入司机姓名';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextFormField(
                    controller: _driverPhoneController,
                    decoration: InputDecoration(
                      labelText: '司机电话',
                      hintText: '请输入司机电话',
                      prefixIcon: Icon(Icons.phone, size: AppSize.iconSmall),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(15),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入司机电话';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseOption({
    required Enterprise enterprise,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(AppRadius.r8),
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: AppSize.iconMedium,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enterprise.enterpriseName ?? '',
                    style: AppTextStyle.body.copyWith(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  if (enterprise.enterpriseCode != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      enterprise.enterpriseCode!,
                      style: AppTextStyle.small,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale, size: AppSize.iconMedium, color: AppTheme.warningColor),
                SizedBox(width: 8.w),
                Text('出库重量', style: AppTextStyle.subtitle),
              ],
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '出库重量 (kg)',
                hintText: '请输入出库重量',
                prefixIcon: Icon(Icons.monitor_weight_outlined, size: AppSize.iconSmall),
                suffixText: 'kg',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入出库重量';
                }
                final weight = double.tryParse(value);
                if (weight == null || weight <= 0) {
                  return '请输入有效的出库重量';
                }
                if (_currentInventory != null && weight > (_currentInventory!.weight ?? 0)) {
                  return '出库重量不能超过当前库存重量';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarkSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, size: AppSize.iconMedium, color: AppTheme.textSecondary),
                SizedBox(width: 8.w),
                Text('备注', style: AppTextStyle.subtitle),
              ],
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _remarkController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '请输入备注信息（选填）',
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(200),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordSettingSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.videocam, size: AppSize.iconMedium, color: AppTheme.primaryColor),
                    SizedBox(width: 8.w),
                    Text('操作录像', style: AppTextStyle.subtitle),
                  ],
                ),
                Switch(
                  value: _enableOperationRecord,
                  onChanged: (value) {
                    setState(() {
                      _enableOperationRecord = value;
                      if (value) {
                        _startRingBuffer();
                      } else {
                        _videoPlayerService.disconnect();
                      }
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
            if (_enableOperationRecord) ...[
              SizedBox(height: 12.h),
              DropdownButtonFormField<CameraModel>(
                value: _selectedCamera,
                decoration: InputDecoration(
                  labelText: '选择摄像头',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                ),
                items: _cameraList.map((camera) {
                  return DropdownMenuItem<CameraModel>(
                    value: camera,
                    child: Text(camera.cameraName ?? camera.cameraCode ?? ''),
                  );
                }).toList(),
                onChanged: (CameraModel? value) {
                  if (value != null) {
                    setState(() {
                      _selectedCamera = value;
                    });
                    _videoPlayerService.disconnect();
                    _startRingBuffer();
                  }
                },
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    _isRecording ? Icons.videocam : Icons.videocam_off,
                    size: 16.sp,
                    color: _isRecording ? AppTheme.dangerColor : AppTheme.textHint,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _isRecording ? '正在录制操作视频...' : '保存时自动录制前后10秒',
                    style: AppTextStyle.caption.copyWith(
                      color: _isRecording ? AppTheme.dangerColor : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: CommonButton(
          text: '确认出库',
          type: ButtonType.primary,
          size: ButtonSize.large,
          block: true,
          loading: _isSaving,
          onPressed: _isSaving ? null : _handleSubmit,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _containerCodeController.dispose();
    _weightController.dispose();
    _vehicleNoController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _remarkController.dispose();
    _receiverSearchController.dispose();
    _transporterSearchController.dispose();
    super.dispose();
  }
}
