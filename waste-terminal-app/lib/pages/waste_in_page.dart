import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../config/app_routes.dart';
import '../services/bluetooth_service.dart';
import '../services/scale_service.dart';
import '../services/waste_in_service.dart';
import '../services/waste_catalog_service.dart';
import '../services/file_service.dart';
import '../services/video_player_service.dart';
import '../services/camera_service.dart';
import '../providers/app_provider.dart';
import '../widgets/common_button.dart';
import '../widgets/status_tag.dart';
import '../utils/toast_util.dart';
import '../utils/uuid_util.dart';
import '../utils/permission_util.dart';
import '../models/waste_catalog.dart';
import '../models/camera_model.dart';

class WasteInPage extends StatefulWidget {
  const WasteInPage({super.key});

  @override
  State<WasteInPage> createState() => _WasteInPageState();
}

class _WasteInPageState extends State<WasteInPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _containerCodeController = TextEditingController();
  final TextEditingController _produceDepartmentController = TextEditingController();
  final TextEditingController _storageLocationController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _catalogSearchController = TextEditingController();

  final WasteCatalogService _catalogService = WasteCatalogService();
  final WasteInService _wasteInService = WasteInService();
  final BluetoothService _bluetoothService = BluetoothService();
  final ScaleService _scaleService = ScaleService();
  final VideoPlayerService _videoPlayerService = VideoPlayerService();
  final CameraService _cameraService = CameraService();

  WasteCatalog? _selectedCatalog;
  List<WasteCatalog> _catalogList = [];
  List<WasteCatalog> _filteredCatalogList = [];
  DateTime _produceDate = DateTime.now();
  bool _isScaleMode = false;
  double _liveWeight = 0.0;
  bool _isWeightStable = false;
  List<String> _photoPaths = [];
  bool _isSaving = false;
  int _containerSeq = 0;

  bool _enableOperationRecord = true;
  CameraModel? _selectedCamera;
  List<CameraModel> _cameraList = [];
  bool _isRecording = false;

  StreamSubscription<double>? _weightSubscription;
  StreamSubscription<bool>? _stableSubscription;
  StreamSubscription<ScaleStatus>? _scaleStatusSubscription;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
    _initContainerSeq();
    _loadCameras();
    if (_isScaleMode) {
      _connectScale();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _containerCodeController.dispose();
    _produceDepartmentController.dispose();
    _storageLocationController.dispose();
    _remarkController.dispose();
    _catalogSearchController.dispose();
    _weightSubscription?.cancel();
    _stableSubscription?.cancel();
    _scaleStatusSubscription?.cancel();
    _videoPlayerService.disconnect();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final list = await _catalogService.getAllCatalogs();
      final catalogs = list.map((e) => WasteCatalog.fromJson(e)).toList();
      setState(() {
        _catalogList = catalogs;
        _filteredCatalogList = catalogs;
      });
    } catch (e) {
      ToastUtil.showError('加载危废名录失败');
    }
  }

  Future<void> _initContainerSeq() async {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'C$dateStr';
    int maxSeq = 0;
    for (int i = 0; i < 9999; i++) {
      final code = '$prefix${(i + 1).toString().padLeft(4, '0')}';
      if (!_catalogList.any((c) => c.wasteCode == code)) {
        maxSeq = i;
        break;
      }
    }
    setState(() {
      _containerSeq = maxSeq;
    });
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
        triggerType: 'waste_in',
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

  String _generateContainerCode() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    _containerSeq++;
    final seqStr = _containerSeq.toString().padLeft(4, '0');
    return 'C$dateStr$seqStr';
  }

  Future<void> _connectScale() async {
    try {
      _scaleStatusSubscription?.cancel();
      _weightSubscription?.cancel();
      _stableSubscription?.cancel();

      _scaleStatusSubscription = _scaleService.statusStream.listen((status) {
        if (mounted) {
          setState(() {});
        }
      });

      _weightSubscription = _scaleService.weightStream.listen((weight) {
        if (mounted) {
          setState(() {
            _liveWeight = weight;
          });
        }
      });

      _stableSubscription = _scaleService.stableStream.listen((stable) {
        if (mounted) {
          setState(() {
            _isWeightStable = stable;
          });
        }
      });

      if (!_scaleService.isConnected) {
        await _bluetoothService.autoConnectScale();
      }
    } catch (e) {
      ToastUtil.showError('连接地磅失败');
    }
  }

  void _filterCatalogs(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredCatalogList = _catalogList;
      } else {
        _filteredCatalogList = _catalogList.where((c) {
          final code = c.wasteCode?.toLowerCase() ?? '';
          final name = c.wasteName?.toLowerCase() ?? '';
          final lower = keyword.toLowerCase();
          return code.contains(lower) || name.contains(lower);
        }).toList();
      }
    });
  }

  Future<void> _showCatalogPicker() async {
    _catalogSearchController.clear();
    _filteredCatalogList = _catalogList;

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
                    controller: _catalogSearchController,
                    decoration: InputDecoration(
                      hintText: '搜索危废代码或名称',
                      prefixIcon: Icon(Icons.search, size: 20.r),
                      suffixIcon: _catalogSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 20.r),
                              onPressed: () {
                                _catalogSearchController.clear();
                                _filterCatalogs('');
                                setModalState(() {
                                  _filteredCatalogList = _catalogList;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      _filterCatalogs(value);
                      setModalState(() {});
                    },
                  ),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: _filteredCatalogList.isEmpty
                        ? Center(
                            child: Text('无匹配结果', style: AppTextStyle.bodySecondary),
                          )
                        : ListView.separated(
                            itemCount: _filteredCatalogList.length,
                            separatorBuilder: (_, __) => Divider(height: 1.h),
                            itemBuilder: (context, index) {
                              final catalog = _filteredCatalogList[index];
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
                                subtitle: catalog.wasteCategory != null
                                    ? Padding(
                                        padding: EdgeInsets.only(top: 4.h),
                                        child: Text(
                                          catalog.wasteCategory!,
                                          style: AppTextStyle.small,
                                        ),
                                      )
                                    : null,
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
  }

  Future<void> _scanContainerCode() async {
    final granted = await PermissionUtil.requestCamera();
    if (!granted) {
      ToastUtil.showError('需要相机权限才能扫描二维码');
      return;
    }

    String? scannedCode;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('扫描容器码', style: AppTextStyle.title),
                    IconButton(
                      icon: Icon(Icons.close, size: 24.r),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        scannedCode = barcode.rawValue;
                        Navigator.pop(context);
                        break;
                      }
                    }
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  '将二维码放入框内自动扫描',
                  style: AppTextStyle.bodySecondary,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (scannedCode != null) {
      setState(() {
        _containerCodeController.text = scannedCode!;
      });
    }
  }

  void _autoGenerateContainerCode() {
    final code = _generateContainerCode();
    setState(() {
      _containerCodeController.text = code;
    });
    ToastUtil.showSuccess('已生成容器编号: $code');
  }

  Future<void> _takePhoto() async {
    if (_photoPaths.length >= 3) {
      ToastUtil.showInfo('最多拍摄3张照片');
      return;
    }

    final granted = await PermissionUtil.requestCamera();
    if (!granted) {
      ToastUtil.showError('需要相机权限才能拍照');
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: AppConfig.imageMaxWidth.toDouble(),
        maxHeight: AppConfig.imageMaxHeight.toDouble(),
        imageQuality: AppConfig.imageCompressQuality,
      );

      if (picked == null) return;

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: AppConfig.imageCompressQuality,
        minWidth: AppConfig.imageMaxWidth,
        minHeight: AppConfig.imageMaxHeight,
      );

      if (compressed == null) {
        ToastUtil.showError('图片压缩失败');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'waste_in_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(compressed);

      setState(() {
        _photoPaths.add(filePath);
      });
    } catch (e) {
      ToastUtil.showError('拍照失败');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });
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

  Future<void> _readStableWeight() async {
    if (!_scaleService.isConnected) {
      ToastUtil.showError('地磅未连接');
      return;
    }

    try {
      ToastUtil.showLoading(status: '等待稳定读数...');
      final weight = await _scaleService.getStableWeight();
      ToastUtil.dismiss();
      setState(() {
        _weightController.text = weight.toStringAsFixed(AppConfig.weightDecimalPlaces);
      });
      ToastUtil.showSuccess('读取稳定重量: ${weight.toStringAsFixed(AppConfig.weightDecimalPlaces)} kg');
    } catch (e) {
      ToastUtil.dismiss();
      ToastUtil.showError('读取重量超时，请重试');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCatalog == null) {
      ToastUtil.showError('请选择危废代码');
      return;
    }

    final weightText = _weightController.text.trim();
    if (weightText.isEmpty) {
      ToastUtil.showError('请输入重量');
      return;
    }

    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) {
      ToastUtil.showError('重量必须大于0');
      return;
    }

    final containerCode = _containerCodeController.text.trim();
    if (containerCode.isEmpty) {
      ToastUtil.showError('请输入或扫描容器编号');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final record = <String, dynamic>{
        'record_no': UuidUtil.generateWasteInNo(),
        'waste_code': _selectedCatalog!.wasteCode,
        'waste_name': _selectedCatalog!.wasteName,
        'waste_category': _selectedCatalog!.wasteCategory,
        'container_code': containerCode,
        'weight': weight,
        'weight_unit': 'kg',
        'source': _isScaleMode ? 'scale' : 'manual',
        'operator': context.read<AppProvider>().username ?? '',
        'warehouse': _storageLocationController.text.trim(),
        'remark': _remarkController.text.trim(),
        'in_time': DateTime.now().toIso8601String(),
        'photos': _photoPaths.join(','),
        'produce_date': _produceDate.toIso8601String(),
        'produce_department': _produceDepartmentController.text.trim(),
      };

      await _wasteInService.addWasteInRecord(record);

      ToastUtil.showSuccess('入库记录保存成功');

      if (_enableOperationRecord && _selectedCamera != null) {
        _triggerOperationRecord(record['record_no']);
      }

      _showPrintDialog(record, weight, containerCode);
    } catch (e) {
      ToastUtil.showError('保存失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showPrintDialog(Map<String, dynamic> record, double weight, String containerCode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('打印标签', style: AppTextStyle.title),
          content: Text('入库记录已保存，是否打印危废标签？', style: AppTextStyle.body),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
              },
              child: Text('暂不打印', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _printLabel(record, weight, containerCode);
                _resetForm();
              },
              child: Text('打印', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printLabel(Map<String, dynamic> record, double weight, String containerCode) async {
    try {
      if (!_bluetoothService.isPrinterConnected) {
        final connected = await _bluetoothService.autoConnectPrinter();
        if (!connected) {
          ToastUtil.showError('打印机未连接');
          return;
        }
      }

      final labelData = WasteLabelData(
        containerCode: containerCode,
        wasteCode: record['waste_code'] ?? '',
        wasteName: record['waste_name'] ?? '',
        wasteCategory: record['waste_category'] ?? '',
        hazardCode: _selectedCatalog?.hazardCode ?? '',
        weight: weight,
        produceUnit: record['produce_department'] ?? '',
        produceDate: _produceDate.toString().substring(0, 10),
        storageLocation: record['warehouse'] ?? '',
        operatorName: record['operator'],
      );

      await _bluetoothService.printWasteLabel(labelData);
      ToastUtil.showSuccess('标签打印成功');
    } catch (e) {
      ToastUtil.showError('打印失败: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _resetForm() {
    setState(() {
      _selectedCatalog = null;
      _weightController.clear();
      _containerCodeController.clear();
      _produceDepartmentController.clear();
      _storageLocationController.clear();
      _remarkController.clear();
      _produceDate = DateTime.now();
      _photoPaths.clear();
      _liveWeight = 0.0;
      _isWeightStable = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('危废入库'),
        actions: [
          Consumer<AppProvider>(
            builder: (context, appProvider, _) {
              if (!appProvider.isOnline) {
                return Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: Center(
                    child: StatusTag(
                      text: '离线',
                      type: StatusType.warning,
                      prefixIcon: Icons.cloud_off,
                      fontSize: 11.sp,
                    ),
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
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCatalogSection(),
                    SizedBox(height: 16.h),
                    _buildWeightSection(),
                    SizedBox(height: 16.h),
                    _buildContainerCodeSection(),
                    SizedBox(height: 16.h),
                    _buildPhotoSection(),
                    SizedBox(height: 16.h),
                    if (_cameraList.isNotEmpty) _buildRecordSettingSection(),
                    SizedBox(height: 16.h),
                    _buildFormFieldsSection(),
                    SizedBox(height: 80.h),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomBar(),
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
                            '请选择危废代码',
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('重量(kg)', style: AppTextStyle.subtitle),
                  SizedBox(width: 4.w),
                  Text('*', style: TextStyle(color: AppTheme.dangerColor, fontSize: 14.sp)),
                ],
              ),
              _buildWeightModeToggle(),
            ],
          ),
          SizedBox(height: 8.h),
          if (_isScaleMode) ...[
            _buildScaleDisplay(),
            SizedBox(height: 8.h),
          ],
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
            ],
            decoration: InputDecoration(
              hintText: _isScaleMode ? '点击读取重量或手动输入' : '请输入重量',
              suffixText: 'kg',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入重量';
              }
              final w = double.tryParse(value);
              if (w == null || w <= 0) {
                return '重量必须大于0';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeightModeToggle() {
    return Container(
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isScaleMode = false;
              });
              _weightSubscription?.cancel();
              _stableSubscription?.cancel();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: !_isScaleMode ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                '手动',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: !_isScaleMode ? AppTheme.textInverse : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isScaleMode = true;
              });
              _connectScale();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _isScaleMode ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                '地磅',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: _isScaleMode ? AppTheme.textInverse : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleDisplay() {
    final isConnected = _scaleService.isConnected;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(
          color: isConnected ? AppTheme.successColor.withOpacity(0.3) : AppTheme.dangerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8.r,
                    height: 8.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? AppTheme.successColor : AppTheme.dangerColor,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    isConnected ? '地磅已连接' : '地磅未连接',
                    style: AppTextStyle.caption.copyWith(
                      color: isConnected ? AppTheme.successColor : AppTheme.dangerColor,
                    ),
                  ),
                ],
              ),
              if (isConnected)
                Row(
                  children: [
                    Icon(
                      _isWeightStable ? Icons.check_circle : Icons.sync,
                      size: 16.r,
                      color: _isWeightStable ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _isWeightStable ? '稳定' : '波动中',
                      style: AppTextStyle.caption.copyWith(
                        color: _isWeightStable ? AppTheme.successColor : AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _liveWeight.toStringAsFixed(AppConfig.weightDecimalPlaces),
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontFamily: 'monospace',
                ),
              ),
              SizedBox(width: 4.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  'kg',
                  style: AppTextStyle.subtitle.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: CommonButton(
              text: '读取稳定重量',
              type: ButtonType.secondary,
              size: ButtonSize.small,
              prefixIcon: Icons.scale,
              onPressed: isConnected ? _readStableWeight : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCodeSection() {
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
              Text('容器编号', style: AppTextStyle.subtitle),
              SizedBox(width: 4.w),
              Text('*', style: TextStyle(color: AppTheme.dangerColor, fontSize: 14.sp)),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _containerCodeController,
                  decoration: InputDecoration(
                    hintText: '扫描或生成容器编号',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入容器编号';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: _scanContainerCode,
                icon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor, size: 28.r),
                tooltip: '扫描',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                ),
              ),
              SizedBox(width: 4.w),
              IconButton(
                onPressed: _autoGenerateContainerCode,
                icon: Icon(Icons.auto_fix_high, color: AppTheme.secondaryColor, size: 28.r),
                tooltip: '自动生成',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('现场照片', style: AppTextStyle.subtitle),
              Text(
                '${_photoPaths.length}/3',
                style: AppTextStyle.caption,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              ...List.generate(_photoPaths.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                        child: Image.file(
                          File(_photoPaths[index]),
                          width: 80.w,
                          height: 80.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2.r,
                        right: 2.r,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            width: 20.r,
                            height: 20.r,
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, size: 14.r, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_photoPaths.length < 3)
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      color: AppTheme.bgPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 28.r, color: AppTheme.textHint),
                        SizedBox(height: 4.h),
                        Text('拍照', style: AppTextStyle.small),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSettingSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('操作录像', style: AppTextStyle.subtitle),
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
            SizedBox(height: 8.h),
            DropdownButtonFormField<CameraModel>(
              value: _selectedCamera,
              decoration: InputDecoration(
                labelText: '选择摄像头',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.r8),
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
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '请输入备注信息',
              alignLabelWithHint: true,
            ),
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
            Icon(Icons.calendar_today, size: 20.r, color: AppTheme.textHint),
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
        child: CommonButton(
          text: '保存入库记录',
          type: ButtonType.primary,
          size: ButtonSize.large,
          block: true,
          loading: _isSaving,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ),
    );
  }
}
