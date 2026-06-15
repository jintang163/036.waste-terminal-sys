import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../services/rfid_service.dart';
import '../services/bluetooth_service.dart';
import '../services/waste_in_service.dart';
import '../services/waste_catalog_service.dart';
import '../services/face_auth_service.dart';
import '../providers/app_provider.dart';
import '../widgets/common_button.dart';
import '../widgets/status_tag.dart';
import '../utils/toast_util.dart';
import '../utils/uuid_util.dart';
import '../utils/logger_util.dart';
import '../models/waste_catalog.dart';
import 'face_verify_page.dart';
import 'face_enroll_page.dart';

class RfidBatchInPage extends StatefulWidget {
  const RfidBatchInPage({super.key});

  @override
  State<RfidBatchInPage> createState() => _RfidBatchInPageState();
}

class _RfidBatchInPageState extends State<RfidBatchInPage> with SingleTickerProviderStateMixin {
  final RfidService _rfidService = RfidService();
  final BluetoothService _bluetoothService = BluetoothService();
  final WasteInService _wasteInService = WasteInService();
  final WasteCatalogService _catalogService = WasteCatalogService();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _storageLocationController = TextEditingController();
  final TextEditingController _produceDepartmentController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  late TabController _tabController;

  WasteCatalog? _selectedCatalog;
  List<WasteCatalog> _catalogList = [];
  DateTime _produceDate = DateTime.now();
  bool _isSaving = false;
  int _savedCount = 0;
  int _failedCount = 0;

  List<RfidTagInfo> _scannedTags = [];
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedDeviceName;

  StreamSubscription<List<RfidTagInfo>>? _tagsSubscription;
  StreamSubscription<RfidTagInfo>? _newTagSubscription;
  StreamSubscription<bool>? _scanningStateSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCatalogs();
    _initRfidService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weightController.dispose();
    _storageLocationController.dispose();
    _produceDepartmentController.dispose();
    _remarkController.dispose();
    _tagsSubscription?.cancel();
    _newTagSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    if (_isScanning) {
      _rfidService.stopScan();
    }
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final list = await _catalogService.getAllCatalogs();
      final catalogs = list.map((e) => WasteCatalog.fromJson(e)).toList();
      setState(() {
        _catalogList = catalogs;
      });
    } catch (e) {
      ToastUtil.showError('加载危废名录失败');
    }
  }

  Future<void> _initRfidService() async {
    await _rfidService.init();

    _tagsSubscription = _rfidService.tagsStream.listen((tags) {
      if (mounted) {
        setState(() {
          _scannedTags = tags;
        });
      }
    });

    _newTagSubscription = _rfidService.newTagStream.listen((tag) {
      if (mounted) {
        _showTagDetectedFeedback(tag);
      }
    });

    _scanningStateSubscription = _rfidService.scanningStateStream.listen((scanning) {
      if (mounted) {
        setState(() {
          _isScanning = scanning;
        });
      }
    });

    _connectionStateSubscription = _rfidService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          _connectedDeviceName = connected ? _bluetoothService.connectedDeviceName : null;
        });
      }
    });

    setState(() {
      _isConnected = _rfidService.isConnected;
      _connectedDeviceName = _bluetoothService.connectedDeviceName;
    });
  }

  void _showTagDetectedFeedback(RfidTagInfo tag) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.nfc, color: Colors.white, size: 20.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                tag.matched
                    ? '识别: ${tag.containerCode ?? tag.epc}'
                    : '新标签: ${tag.epc.substring(0, tag.epc.length > 12 ? 12 : tag.epc.length)}...',
                style: TextStyle(fontSize: 13.sp),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 800),
        backgroundColor: tag.matched ? AppTheme.successColor : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8.w),
      ),
    );
  }

  Future<void> _connectRfid() async {
    try {
      ToastUtil.showLoading(status: '连接RFID读卡器...');
      final connected = await _rfidService.connect();
      ToastUtil.dismiss();
      if (connected) {
        ToastUtil.showSuccess('RFID读卡器已连接');
        setState(() {
          _isConnected = true;
          _connectedDeviceName = _bluetoothService.connectedDeviceName;
        });
      } else {
        _showBluetoothDevicePicker();
      }
    } catch (e) {
      ToastUtil.dismiss();
      ToastUtil.showError('连接失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _showBluetoothDevicePicker() async {
    try {
      ToastUtil.showLoading(status: '扫描蓝牙设备...');
      await _bluetoothService.startScan(timeout: const Duration(seconds: 8));
      ToastUtil.dismiss();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
        ),
        builder: (context) {
          return StreamBuilder<List<BluetoothDeviceInfo>>(
            stream: _bluetoothService.scanResultsStream,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? [];
              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('选择RFID读卡器', style: AppTextStyle.title),
                        IconButton(
                          icon: Icon(Icons.close, size: 24.r),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: devices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bluetooth_searching, size: 48.r, color: AppTheme.textHint),
                                  SizedBox(height: 8.h),
                                  Text('正在搜索附近蓝牙设备...', style: AppTextStyle.bodySecondary),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: devices.length,
                              separatorBuilder: (_, __) => Divider(height: 1.h),
                              itemBuilder: (context, index) {
                                final device = devices[index];
                                return ListTile(
                                  leading: Icon(
                                    device.type == BluetoothDeviceType.rfid
                                        ? Icons.nfc
                                        : Icons.bluetooth,
                                    color: device.type == BluetoothDeviceType.rfid
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                    size: 28.r,
                                  ),
                                  title: Text(
                                    device.name,
                                    style: AppTextStyle.body,
                                  ),
                                  subtitle: Text(
                                    device.address,
                                    style: AppTextStyle.caption,
                                  ),
                                  trailing: device.type == BluetoothDeviceType.rfid
                                      ? StatusTag(
                                          text: 'RFID',
                                          type: StatusType.success,
                                          size: StatusTagSize.small,
                                        )
                                      : null,
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _connectToDevice(device.address);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ToastUtil.dismiss();
      ToastUtil.showError('扫描蓝牙设备失败');
    }
  }

  Future<void> _connectToDevice(String address) async {
    try {
      ToastUtil.showLoading(status: '正在连接...');
      await _bluetoothService.connectByAddress(address);
      ToastUtil.dismiss();

      if (_bluetoothService.isRfidConnected) {
        ToastUtil.showSuccess('RFID读卡器连接成功');
        setState(() {
          _isConnected = true;
          _connectedDeviceName = _bluetoothService.connectedDeviceName;
        });
        await _rfidService.init();
      } else {
        ToastUtil.showWarning('设备已连接，但未被识别为RFID读卡器，仍可尝试使用');
        setState(() {
          _isConnected = _bluetoothService.isConnected;
          _connectedDeviceName = _bluetoothService.connectedDeviceName;
        });
        await _rfidService.init();
      }
    } catch (e) {
      ToastUtil.dismiss();
      ToastUtil.showError('连接失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await _rfidService.stopScan();
      ToastUtil.showInfo('扫描已停止，共读取 ${_scannedTags.length} 个标签');
    } else {
      try {
        await _rfidService.startScan(mode: RfidScanMode.inventory);
        ToastUtil.showSuccess('开始批量扫描，请将RFID读卡器靠近容器标签');
      } catch (e) {
        ToastUtil.showError('启动扫描失败: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _singleRead() async {
    try {
      _rfidService.clearTags();
      await _rfidService.startScan(mode: RfidScanMode.single);
      await Future.delayed(const Duration(seconds: 2));
      await _rfidService.stopScan();
    } catch (e) {
      ToastUtil.showError('单次读取失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _selectProduceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _produceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _produceDate = picked;
      });
    }
  }

  Future<void> _showCatalogPicker() async {
    final searchController = TextEditingController();
    var filteredList = _catalogList;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('选择危废代码', style: AppTextStyle.title),
                      IconButton(
                        icon: Icon(Icons.close, size: 24.r),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '搜索危废代码或名称',
                      prefixIcon: Icon(Icons.search, size: 20.r),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          filteredList = _catalogList;
                        } else {
                          filteredList = _catalogList.where((c) {
                            final code = c.wasteCode?.toLowerCase() ?? '';
                            final name = c.wasteName?.toLowerCase() ?? '';
                            final lower = value.toLowerCase();
                            return code.contains(lower) || name.contains(lower);
                          }).toList();
                        }
                      });
                    },
                  ),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(child: Text('无匹配结果', style: AppTextStyle.bodySecondary))
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => Divider(height: 1.h),
                            itemBuilder: (context, index) {
                              final catalog = filteredList[index];
                              final isSelected = _selectedCatalog?.wasteCode == catalog.wasteCode;
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: AppTheme.primaryColor.withOpacity(0.05),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        catalog.wasteCode ?? '',
                                        style: AppTextStyle.caption.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        catalog.wasteName ?? '',
                                        style: AppTextStyle.body,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20.r)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCatalog = catalog;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _handleBatchSave() async {
    if (_scannedTags.isEmpty) {
      ToastUtil.showError('请先扫描RFID标签');
      return;
    }

    if (_selectedCatalog == null) {
      ToastUtil.showError('请选择危废代码');
      return;
    }

    final weightText = _weightController.text.trim();
    if (weightText.isEmpty) {
      ToastUtil.showError('请输入单容器重量');
      return;
    }

    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) {
      ToastUtil.showError('重量必须大于0');
      return;
    }

    final appProvider = context.read<AppProvider>();
    final currentUsername = appProvider.username ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认批量入库', style: AppTextStyle.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即将为以下容器批量创建入库记录:', style: AppTextStyle.body),
            SizedBox(height: 8.h),
            Container(
              constraints: BoxConstraints(maxHeight: 120.h),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _scannedTags.map((tag) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Row(
                        children: [
                          Icon(Icons.nfc, size: 14.r, color: AppTheme.primaryColor),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              tag.matched
                                  ? '${tag.containerCode} (${tag.epc.substring(0, 8)}...)'
                                  : tag.epc,
                              style: AppTextStyle.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow('容器数量', '${_scannedTags.length} 个'),
                  _buildSummaryRow('单容器重量', '${weight.toStringAsFixed(AppConfig.weightDecimalPlaces)} kg'),
                  _buildSummaryRow('总重量', '${(weight * _scannedTags.length).toStringAsFixed(AppConfig.weightDecimalPlaces)} kg'),
                  _buildSummaryRow('危废代码', _selectedCatalog!.wasteCode ?? ''),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认入库', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final faceAuthService = FaceAuthService();
    final hasEnrolledFace = await faceAuthService.hasEnrolledFace(currentUsername);

    if (!hasEnrolledFace) {
      final enrollConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('需要人脸验证', style: AppTextStyle.title),
          content: Text('为满足追溯要求，入库操作前必须先完成人脸录入。是否立即前往录入人脸？', style: AppTextStyle.body),
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

      if (enrollConfirm == true) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const FaceEnrollPage()),
        );
        if (result != true) {
          ToastUtil.showWarning('请先完成人脸录入');
          return;
        }
      } else {
        ToastUtil.showWarning('请先完成人脸录入，才能进行入库操作');
        return;
      }
    }

    FaceAuthResult? authResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FaceVerifyPage(
          authType: 'rfid_batch_in',
          businessType: 'waste_in',
          businessNo: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
          targetUsername: currentUsername,
          autoNavigateOnSuccess: true,
        ),
      ),
    );

    if (authResult == null || !authResult.success) {
      ToastUtil.showWarning('人脸验证未通过，无法保存');
      return;
    }

    setState(() {
      _isSaving = true;
      _savedCount = 0;
      _failedCount = 0;
    });

    try {
      for (final tag in _scannedTags) {
        try {
          final recordNo = UuidUtil.generateWasteInNo();
          final containerCode = tag.matched
              ? tag.containerCode ?? tag.epc
              : 'RFID_${tag.epc}';

          final record = <String, dynamic>{
            'record_no': recordNo,
            'waste_code': _selectedCatalog!.wasteCode,
            'waste_name': _selectedCatalog!.wasteName,
            'waste_category': _selectedCatalog!.wasteCategory,
            'container_code': containerCode,
            'weight': weight,
            'weight_unit': 'kg',
            'source': 'rfid',
            'operator': currentUsername,
            'warehouse': _storageLocationController.text.trim(),
            'remark': _remarkController.text.trim(),
            'in_time': DateTime.now().toIso8601String(),
            'produce_date': _produceDate.toIso8601String(),
            'produce_department': _produceDepartmentController.text.trim(),
            'rfid_epc': tag.epc,
            'face_auth_id': authResult!.authId,
            'face_id': authResult.userFace?.faceId,
            if (authResult.capturedImage != null)
              'operator_face_image': base64Encode(authResult.capturedImage!),
          };

          await _wasteInService.addWasteInRecord(record);
          _savedCount++;
        } catch (e) {
          _failedCount++;
          LoggerUtil.error('批量入库单条保存失败: ${tag.epc}', e);
        }
      }

      if (_failedCount == 0) {
        ToastUtil.showSuccess('批量入库完成！成功入库 $_savedCount 个容器');
      } else {
        ToastUtil.showWarning('入库完成：成功 $_savedCount 个，失败 $_failedCount 个');
      }

      _showBatchResultDialog();
    } catch (e) {
      ToastUtil.showError('批量入库失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyle.caption),
          Text(value, style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showBatchResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _failedCount == 0 ? Icons.check_circle : Icons.warning,
                color: _failedCount == 0 ? AppTheme.successColor : AppTheme.warningColor,
                size: 24.r,
              ),
              SizedBox(width: 8.w),
              Text('批量入库结果', style: AppTextStyle.title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('总计容器', '${_scannedTags.length} 个'),
              _buildSummaryRow('成功入库', '$_savedCount 个'),
              if (_failedCount > 0)
                _buildSummaryRow('入库失败', '$_failedCount 个'),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppTheme.bgPrimary,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('危废代码: ${_selectedCatalog?.wasteCode ?? ''}', style: AppTextStyle.caption),
                    Text('危废名称: ${_selectedCatalog?.wasteName ?? ''}', style: AppTextStyle.caption),
                    Text('单容器重量: ${_weightController.text} kg', style: AppTextStyle.caption),
                    Text(
                      '总重量: ${(double.tryParse(_weightController.text) ?? 0) * _savedCount} kg',
                      style: AppTextStyle.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(this.context);
              },
              child: Text('返回首页'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetAndContinue();
              },
              child: Text('继续入库', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _resetAndContinue() {
    setState(() {
      _rfidService.clearTags();
      _scannedTags = [];
      _savedCount = 0;
      _failedCount = 0;
      _weightController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RFID批量入库'),
        actions: [
          if (_isScanning)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text('扫描中', style: TextStyle(fontSize: 13.sp, color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '扫描录入'),
            Tab(text: '入库设置'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildScanTab() {
    return Column(
      children: [
        _buildConnectionBar(),
        _buildScanControl(),
        Expanded(child: _buildTagList()),
      ],
    );
  }

  Widget _buildConnectionBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _isConnected
            ? AppTheme.successColor.withOpacity(0.05)
            : AppTheme.dangerColor.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: _isConnected
                ? AppTheme.successColor.withOpacity(0.2)
                : AppTheme.dangerColor.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8.r,
            height: 8.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? AppTheme.successColor : AppTheme.dangerColor,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected
                      ? 'RFID读卡器已连接${_connectedDeviceName != null ? " - $_connectedDeviceName" : ""}'
                      : 'RFID读卡器未连接',
                  style: AppTextStyle.body.copyWith(
                    color: _isConnected ? AppTheme.successColor : AppTheme.dangerColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!_isConnected)
            CommonButton(
              text: '连接',
              type: ButtonType.primary,
              size: ButtonSize.small,
              onPressed: _connectRfid,
            ),
        ],
      ),
    );
  }

  Widget _buildScanControl() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('已扫描标签', style: AppTextStyle.subtitle),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${_scannedTags.length} 个',
                  style: AppTextStyle.caption.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  text: _isScanning ? '停止扫描' : '批量扫描',
                  type: _isScanning ? ButtonType.outline : ButtonType.primary,
                  size: ButtonSize.medium,
                  prefixIcon: _isScanning ? Icons.stop : Icons.nfc,
                  onPressed: _isConnected ? _toggleScan : null,
                ),
              ),
              SizedBox(width: 8.w),
              CommonButton(
                text: '单次读取',
                type: ButtonType.secondary,
                size: ButtonSize.medium,
                prefixIcon: Icons.search,
                onPressed: _isConnected && !_isScanning ? _singleRead : null,
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: _scannedTags.isNotEmpty ? () {
                  setState(() {
                    _rfidService.clearTags();
                    _scannedTags = [];
                  });
                  ToastUtil.showInfo('已清空标签列表');
                } : null,
                icon: Icon(Icons.delete_outline, color: AppTheme.dangerColor, size: 24.r),
                tooltip: '清空',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor.withOpacity(0.1),
                ),
              ),
            ],
          ),
          if (_isScanning) ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14.r, color: AppTheme.infoColor),
                SizedBox(width: 4.w),
                Text(
                  '正在持续扫描中，将读卡器靠近容器RFID标签即可自动录入',
                  style: AppTextStyle.caption.copyWith(color: AppTheme.infoColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagList() {
    if (_scannedTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.nfc, size: 64.r, color: AppTheme.textHint),
            SizedBox(height: 12.h),
            Text('暂无扫描结果', style: AppTextStyle.bodySecondary),
            SizedBox(height: 8.h),
            Text(
              '连接RFID读卡器后，点击"批量扫描"开始',
              style: AppTextStyle.caption,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: _scannedTags.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final tag = _scannedTags[index];
        return _buildTagItem(tag, index);
      },
    );
  }

  Widget _buildTagItem(RfidTagInfo tag, int index) {
    return Dismissible(
      key: Key(tag.epc),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        _rfidService.removeTag(tag.epc);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16.w),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(Icons.delete, color: Colors.white, size: 24.r),
      ),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: tag.matched
                ? AppTheme.successColor.withOpacity(0.3)
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: tag.matched
                    ? AppTheme.successColor.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                tag.matched ? Icons.check_circle : Icons.nfc,
                size: 22.r,
                color: tag.matched ? AppTheme.successColor : AppTheme.primaryColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: AppTextStyle.caption.copyWith(
                          color: AppTheme.textHint,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (tag.matched)
                        StatusTag(
                          text: '已匹配',
                          type: StatusType.success,
                          size: StatusTagSize.small,
                        )
                      else
                        StatusTag(
                          text: '未匹配',
                          type: StatusType.warning,
                          size: StatusTagSize.small,
                        ),
                      const Spacer(),
                      Text(
                        _formatTime(tag.scanTime),
                        style: AppTextStyle.small,
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    tag.matched
                        ? '容器: ${tag.containerCode}'
                        : 'EPC: ${tag.epc}',
                    style: AppTextStyle.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tag.epc.length > 12)
                    Text(
                      'EPC: ${tag.epc}',
                      style: AppTextStyle.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCatalogSection(),
          SizedBox(height: 16.h),
          _buildWeightSection(),
          SizedBox(height: 16.h),
          _buildFormFieldsSection(),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _buildCatalogSection() {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('危废代码', style: AppTextStyle.subtitle),
              SizedBox(width: 4.w),
              Text('*', style: TextStyle(color: AppTheme.dangerColor, fontSize: 14.sp)),
            ],
          ),
          SizedBox(height: 8.h),
          InkWell(
            onTap: _showCatalogPicker,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _selectedCatalog != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      _selectedCatalog!.wasteCode ?? '',
                                      style: AppTextStyle.caption.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      _selectedCatalog!.wasteName ?? '',
                                      style: AppTextStyle.body,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedCatalog!.wasteCategory != null) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  '${_selectedCatalog!.wasteCategory} | ${_selectedCatalog!.hazardCode ?? ''}',
                                  style: AppTextStyle.small,
                                ),
                              ],
                            ],
                          )
                        : Text(
                            '请选择危废代码（所有容器共用）',
                            style: TextStyle(color: AppTheme.textHint, fontSize: 14.sp),
                          ),
                  ),
                  Icon(Icons.arrow_drop_down, color: AppTheme.textHint, size: 24.r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSection() {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('单容器重量(kg)', style: AppTextStyle.subtitle),
              SizedBox(width: 4.w),
              Text('*', style: TextStyle(color: AppTheme.dangerColor, fontSize: 14.sp)),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            '所有容器将使用相同重量，如有差异请入库后单独修改',
            style: AppTextStyle.caption.copyWith(color: AppTheme.textHint),
          ),
          SizedBox(height: 8.h),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '请输入单容器重量',
              suffixText: 'kg',
            ),
          ),
          if (_weightController.text.isNotEmpty && _scannedTags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('预估总重量', style: AppTextStyle.caption),
                  Text(
                    '${(double.tryParse(_weightController.text) ?? 0) * _scannedTags.length} kg',
                    style: AppTextStyle.body.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormFieldsSection() {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateField(),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _produceDepartmentController,
            decoration: const InputDecoration(
              labelText: '产生部门',
              hintText: '请输入产生部门',
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _storageLocationController,
            decoration: const InputDecoration(
              labelText: '存放位置',
              hintText: '请输入存放位置',
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _remarkController,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '请输入备注信息',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectProduceDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '产生日期',
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_produceDate.year}-${_produceDate.month.toString().padLeft(2, '0')}-${_produceDate.day.toString().padLeft(2, '0')}',
              style: AppTextStyle.body,
            ),
            Icon(Icons.calendar_today, size: 18.r, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已扫描 ${_scannedTags.length} 个容器',
                    style: AppTextStyle.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_weightController.text.isNotEmpty)
                    Text(
                      '预估总重: ${(double.tryParse(_weightController.text) ?? 0) * _scannedTags.length} kg',
                      style: AppTextStyle.caption,
                    ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            CommonButton(
              text: _isSaving ? '入库中...' : '批量入库',
              type: ButtonType.primary,
              size: ButtonSize.medium,
              prefixIcon: _isSaving ? null : Icons.save,
              loading: _isSaving,
              disabled: _scannedTags.isEmpty || _selectedCatalog == null || _isSaving,
              onPressed: _handleBatchSave,
            ),
          ],
        ),
      ),
    );
  }
}
