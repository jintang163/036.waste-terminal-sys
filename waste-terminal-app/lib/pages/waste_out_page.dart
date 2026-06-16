import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:logger/logger.dart';

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
import '../services/gps_service.dart';
import '../services/api_service.dart';
import '../db/transport_vehicle_db.dart';
import '../db/transport_driver_db.dart';
import '../db/transport_track_db.dart';
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
import '../models/transport_vehicle.dart';
import '../models/transport_driver.dart';
import '../models/transport_track.dart';
import 'face_verify_page.dart';
import 'track_playback_page.dart';

class WasteOutPage extends StatefulWidget {
  const WasteOutPage({super.key});

  @override
  State<WasteOutPage> createState() => _WasteOutPageState();
}

class _WasteOutPageState extends State<WasteOutPage> {
  final _formKey = GlobalKey<FormState>();
  final _containerCodeController = TextEditingController();
  final _weightController = TextEditingController();
  final _remarkController = TextEditingController();
  final _receiverSearchController = TextEditingController();
  final _transporterSearchController = TextEditingController();
  final _vehicleSearchController = TextEditingController();
  final _driverSearchController = TextEditingController();
  final _expectedDurationController =
      TextEditingController(text: '24');
  double _expectedDurationHours = 24.0;

  final Logger _logger = Logger();
  final TransportVehicleDb _vehicleDb = TransportVehicleDb();
  final TransportDriverDb _driverDb = TransportDriverDb();
  final TransportTrackDb _trackDb = TransportTrackDb();
  final GpsService _gpsService = GpsService();
  final ApiService _apiService = ApiService();

  WasteInventory? _currentInventory;
  Enterprise? _selectedReceiver;
  Enterprise? _selectedTransporter;
  TransportVehicle? _selectedVehicle;
  TransportDriver? _selectedDriver;
  List<Enterprise> _receiverList = [];
  List<Enterprise> _transporterList = [];
  List<Enterprise> _filteredReceiverList = [];
  List<Enterprise> _filteredTransporterList = [];
  List<TransportVehicle> _vehicleList = [];
  List<TransportVehicle> _filteredVehicleList = [];
  List<TransportDriver> _driverList = [];
  List<TransportDriver> _filteredDriverList = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _generatedOrderNo;
  String? _generatedOutNo;
  String? _generatedTrackNo;

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
    _loadVehiclesAndDrivers();
  }

  @override
  void dispose() {
    _containerCodeController.dispose();
    _weightController.dispose();
    _remarkController.dispose();
    _receiverSearchController.dispose();
    _transporterSearchController.dispose();
    _vehicleSearchController.dispose();
    _driverSearchController.dispose();
    _expectedDurationController.dispose();
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

  Future<void> _loadVehiclesAndDrivers() async {
    try {
      final vehicles = await _vehicleDb.queryByStatus(1);
      final drivers = await _driverDb.queryByStatus(1);
      setState(() {
        _vehicleList = vehicles.map((e) => TransportVehicle.fromDbMap(e)).toList();
        _filteredVehicleList = _vehicleList;
        _driverList = drivers.map((e) => TransportDriver.fromDbMap(e)).toList();
        _filteredDriverList = _driverList;
      });
      _logger.i('加载车辆${_vehicleList.length}辆，驾驶员${_driverList.length}名');
    } catch (e) {
      _logger.w('加载车辆驾驶员数据失败: $e');
      ToastUtil.showWarning('车辆数据加载失败，将使用手动输入');
    }
  }

  void _filterVehicles(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredVehicleList = _vehicleList;
      } else {
        _filteredVehicleList = _vehicleList
            .where((v) =>
                (v.vehicleNo ?? '').contains(keyword) ||
                (v.vehicleModel ?? '').contains(keyword))
            .toList();
      }
    });
  }

  void _filterDrivers(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredDriverList = _driverList;
      } else {
        _filteredDriverList = _driverList
            .where((d) =>
                (d.driverName ?? '').contains(keyword) ||
                (d.phone ?? '').contains(keyword))
            .toList();
      }
    });
  }

  void _onVehicleSelected(TransportVehicle vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
      _vehicleSearchController.text = '${vehicle.vehicleNo} - ${vehicle.vehicleModel ?? ''}';
      if (vehicle.driverId != null) {
        final matchedDriver = _driverList.firstWhere(
          (d) => d.id == vehicle.driverId || d.driverId == vehicle.driverId.toString(),
          orElse: () => _driverList.firstWhere(
            (d) => d.vehicleId == vehicle.id || d.vehicleNo == vehicle.vehicleNo,
            orElse: () => TransportDriver(),
          ),
        );
        if (matchedDriver.driverName != null) {
          _selectedDriver = matchedDriver;
          _driverSearchController.text = '${matchedDriver.driverName} - ${matchedDriver.phone ?? ''}';
        }
      }
    });
  }

  void _onDriverSelected(TransportDriver driver) {
    setState(() {
      _selectedDriver = driver;
      _driverSearchController.text = '${driver.driverName} - ${driver.phone ?? ''}';
    });
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

    if (_vehicleList.isNotEmpty && _selectedVehicle == null) {
      ToastUtil.showError('请选择运输车辆');
      return;
    }

    if (_driverList.isNotEmpty && _selectedDriver == null) {
      ToastUtil.showError('请选择驾驶员');
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

    if (!hasEnrolledFace) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('需要人脸验证', style: AppTextStyle.title),
          content: Text('为满足追溯要求，出库操作前必须先完成人脸录入。是否立即前往录入人脸？',
              style: AppTextStyle.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('去录入', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const FaceEnrollPage()),
        );
        if (result != true) {
          ToastUtil.showWarning('请先完成人脸录入');
          return;
        }
      } else {
        ToastUtil.showWarning('请先完成人脸录入，才能进行出库操作');
        return;
      }
    }

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

    setState(() => _isSaving = true);

    try {
      final appProvider = context.read<AppProvider>();
      final orderNo = UuidUtil.generateTransferOrderNo();
      final offlineId = UuidUtil.generateOfflineId('WO');
      final orderOfflineId = UuidUtil.generateOfflineId('TO');
      final now = DateTime.now();

      final vehicleNo = _selectedVehicle?.vehicleNo ?? '';
      final driverName = _selectedDriver?.driverName ?? '';
      final driverPhone = _selectedDriver?.phone ?? '';

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
        vehicleNo: vehicleNo,
        driverName: driverName,
        driverPhone: driverPhone,
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

      String? trackNo;
      if (_selectedVehicle != null && _selectedDriver != null) {
        try {
          trackNo = await _createTransportTrack(
            transferOrderId: orderOfflineId,
            transferOrderNo: orderNo,
            vehicle: _selectedVehicle!,
            driver: _selectedDriver!,
          );
          _generatedTrackNo = trackNo;

          final startPosition = await _gpsService.getCurrentPosition();
          await _gpsService.startTracking(
            trackId: trackNo,
            transferOrderId: orderOfflineId,
            transferOrderNo: orderNo,
            vehicleId: _selectedVehicle!.id?.toString() ?? _selectedVehicle!.vehicleId ?? '',
            vehicleNo: _selectedVehicle!.vehicleNo ?? '',
            driverId: _selectedDriver!.id?.toString() ?? _selectedDriver!.driverId ?? '',
            driverName: _selectedDriver!.driverName ?? '',
            startLocation: startPosition?.location,
            startLng: startPosition?.lng,
            startLat: startPosition?.lat,
          );
          _logger.i('运输轨迹已创建，GPS追踪已启动: $trackNo');
        } catch (e) {
          _logger.w('创建运输轨迹失败: $e');
          ToastUtil.showWarning('运输轨迹创建失败，不影响出库流程');
        }
      }

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

  Future<String> _createTransportTrack({
    required String transferOrderId,
    required String transferOrderNo,
    required TransportVehicle vehicle,
    required TransportDriver driver,
  }) async {
    final now = DateTime.now();
    final trackNo = 'TRK${now.millisecondsSinceEpoch}';

    final track = TransportTrack(
      trackNo: trackNo,
      transferOrderId: transferOrderId,
      transferOrderNo: transferOrderNo,
      vehicleId: vehicle.id?.toString() ?? vehicle.vehicleId ?? '',
      vehicleNo: vehicle.vehicleNo ?? '',
      driverId: driver.id?.toString() ?? driver.driverId ?? '',
      driverName: driver.driverName ?? '',
      startTime: now,
      expectedDurationHours: _expectedDurationHours > 0
          ? _expectedDurationHours
          : 24.0,
      expectedArrivalTime: _expectedDurationHours > 0
          ? now.add(Duration(
              milliseconds:
                  (_expectedDurationHours * 3600 * 1000).round()))
          : now.add(const Duration(hours: 24)),
      status: 1,
      sourceType: 'app',
      syncStatus: 0,
      createTime: now,
    );

    await _trackDb.insert(track.toDbMap());

    try {
      final hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        await _apiService.createTransportTrack(track.toJson());
        await _trackDb.updateSyncStatus(trackNo, 1, syncTime: now.toIso8601String());
      }
    } catch (e) {
      _logger.w('同步轨迹到服务端失败，将在网络恢复后自动同步: $e');
    }

    return trackNo;
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
          if (_generatedTrackNo != null)
            CommonButton(
              text: '查看轨迹',
              type: ButtonType.outline,
              size: ButtonSize.small,
              onPressed: () {
                Navigator.pop(dialogContext);
                TrackPlaybackPage.show(
                  context,
                  trackId: _generatedTrackNo!,
                  transferOrderNo: order.orderNo,
                );
              },
            ),
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
    _remarkController.clear();
    _receiverSearchController.clear();
    _transporterSearchController.clear();
    _vehicleSearchController.clear();
    _driverSearchController.clear();
    setState(() {
      _currentInventory = null;
      _selectedReceiver = null;
      _selectedTransporter = null;
      _selectedVehicle = null;
      _selectedDriver = null;
      _generatedOrderNo = null;
      _generatedOutNo = null;
      _generatedTrackNo = null;
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
                    _buildVehicleSection(),
                    SizedBox(height: 16.h),
                    _buildDriverSection(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, size: AppSize.iconMedium, color: AppTheme.accentColor),
                SizedBox(width: 8.w),
                Text('运输车辆', style: AppTextStyle.subtitle),
                if (_vehicleList.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Text('(暂无缓存，请先同步数据)', style: AppTextStyle.caption.copyWith(color: AppTheme.warningColor)),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            if (_vehicleList.isNotEmpty) ...[
              TextFormField(
                controller: _vehicleSearchController,
                decoration: InputDecoration(
                  labelText: '搜索车辆',
                  hintText: '输入车牌号或车型搜索',
                  prefixIcon: Icon(Icons.search, size: AppSize.iconSmall),
                  suffixIcon: _selectedVehicle != null
                      ? IconButton(
                          icon: Icon(Icons.check_circle, color: AppTheme.successColor, size: AppSize.iconSmall),
                          onPressed: null,
                        )
                      : null,
                ),
                onChanged: _filterVehicles,
                validator: (value) {
                  if (_selectedVehicle == null) {
                    return '请选择运输车辆';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              ..._filteredVehicleList.map((vehicle) => _buildVehicleOption(
                    vehicle: vehicle,
                    isSelected: _selectedVehicle?.id == vehicle.id || _selectedVehicle?.vehicleId == vehicle.vehicleId,
                    onTap: () => _onVehicleSelected(vehicle),
                  )),
            ] else ...[
              TextFormField(
                decoration: InputDecoration(
                  labelText: '车牌号',
                  hintText: '请输入车牌号',
                  prefixIcon: Icon(Icons.directions_car, size: AppSize.iconSmall),
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入车牌号';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverSection() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: AppSize.iconMedium, color: AppTheme.secondaryColor),
                SizedBox(width: 8.w),
                Text('驾驶员', style: AppTextStyle.subtitle),
                if (_driverList.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Text('(暂无缓存，请先同步数据)', style: AppTextStyle.caption.copyWith(color: AppTheme.warningColor)),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            if (_driverList.isNotEmpty) ...[
              TextFormField(
                controller: _driverSearchController,
                decoration: InputDecoration(
                  labelText: '搜索驾驶员',
                  hintText: '输入姓名或电话搜索',
                  prefixIcon: Icon(Icons.search, size: AppSize.iconSmall),
                  suffixIcon: _selectedDriver != null
                      ? IconButton(
                          icon: Icon(Icons.check_circle, color: AppTheme.successColor, size: AppSize.iconSmall),
                          onPressed: null,
                        )
                      : null,
                ),
                onChanged: _filterDrivers,
                validator: (value) {
                  if (_selectedDriver == null) {
                    return '请选择驾驶员';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              ..._filteredDriverList.map((driver) => _buildDriverOption(
                    driver: driver,
                    isSelected: _selectedDriver?.id == driver.id || _selectedDriver?.driverId == driver.driverId,
                    onTap: () => _onDriverSelected(driver),
                  )),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: '司机姓名',
                        hintText: '请输入司机姓名',
                        prefixIcon: Icon(Icons.person, size: AppSize.iconSmall),
                      ),
                      inputFormatters: [LengthLimitingTextInputFormatter(20)],
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
            SizedBox(height: 20.h),
            Text('预计到达时长', style: AppTextStyle.subtitle),
            SizedBox(height: 10.h),
            TextFormField(
              controller: _expectedDurationController,
              decoration: InputDecoration(
                labelText: '预计到达时长（小时）',
                hintText: '请输入预计到达时长',
                prefixIcon: Icon(Icons.timer, size: AppSize.iconSmall),
                suffixText: '小时',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}$'),
                ),
              ],
              onChanged: (value) {
                final parsed = double.tryParse(value.trim());
                if (parsed != null && parsed > 0) {
                  _expectedDurationHours = parsed;
                }
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入预计到达时长';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return '请输入有效的时长';
                }
                if (parsed > 720) {
                  return '预计时长不能超过720小时(30天)';
                }
                return null;
              },
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [2.0, 6.0, 12.0, 24.0, 48.0, 72.0]
                  .map((hours) => ChoiceChip(
                        label: Text(
                          '${hours.truncate()}小时',
                          style: AppTextStyle.caption.copyWith(
                            color: _expectedDurationHours == hours
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        selected: _expectedDurationHours == hours,
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.bgSecondary,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _expectedDurationHours = hours;
                              _expectedDurationController.text =
                                  hours.truncate().toString();
                            });
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOption({
    required TransportVehicle vehicle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        margin: EdgeInsets.only(bottom: 8.h),
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
                  Row(
                    children: [
                      Text(
                        vehicle.vehicleNo ?? '',
                        style: AppTextStyle.body.copyWith(
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: _getVehicleTypeColor(vehicle.vehicleType),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          _getVehicleTypeName(vehicle.vehicleType),
                          style: TextStyle(fontSize: 10.sp, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${vehicle.vehicleModel ?? ''} ${vehicle.loadWeight != null ? '载重${vehicle.loadWeight}吨' : ''}',
                    style: AppTextStyle.small,
                  ),
                  if (vehicle.driverName != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      '驾驶员: ${vehicle.driverName}',
                      style: AppTextStyle.caption,
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

  Widget _buildDriverOption({
    required TransportDriver driver,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        margin: EdgeInsets.only(bottom: 8.h),
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
                    driver.driverName ?? '',
                    style: AppTextStyle.body.copyWith(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '电话: ${driver.phone ?? '-'}',
                    style: AppTextStyle.small,
                  ),
                  if (driver.vehicleNo != null || driver.workYears != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      '${driver.vehicleNo != null ? '车辆: ${driver.vehicleNo}' : ''}${driver.workYears != null ? '  驾龄: ${driver.workYears}年' : ''}',
                      style: AppTextStyle.caption,
                    ),
                  ],
                  if (driver.hazardousCert != null) ...[
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(Icons.verified, size: 12.sp, color: AppTheme.successColor),
                        SizedBox(width: 4.w),
                        Text(
                          '危运资格证',
                          style: AppTextStyle.caption.copyWith(color: AppTheme.successColor),
                        ),
                      ],
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

  Color _getVehicleTypeColor(String? type) {
    switch (type) {
      case 'tank':
        return AppTheme.dangerColor;
      case 'box':
        return AppTheme.infoColor;
      case 'flat':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getVehicleTypeName(String? type) {
    switch (type) {
      case 'tank':
        return '罐车';
      case 'box':
        return '厢式';
      case 'flat':
        return '平板';
      default:
        return '其他';
    }
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
}
