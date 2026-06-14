import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../models/transfer_order.dart';
import '../services/transfer_order_service.dart';
import '../utils/date_util.dart';
import '../utils/logger_util.dart';
import '../utils/print_util.dart';
import '../utils/sp_util.dart';
import '../utils/toast_util.dart';

class TransferOrderDetailPage extends StatefulWidget {
  final int orderId;

  const TransferOrderDetailPage({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<TransferOrderDetailPage> createState() => _TransferOrderDetailPageState();
}

class _TransferOrderDetailPageState extends State<TransferOrderDetailPage> {
  final TransferOrderService _orderService = TransferOrderService();
  final ImagePicker _imagePicker = ImagePicker();
  final Connectivity _connectivity = Connectivity();
  final PrintUtil _printUtil = PrintUtil();

  TransferOrder? _order;
  List<TransferOrderTimeline> _timelineList = [];
  bool _isLoading = true;
  String? _qrCodeBase64;
  File? _signPhotoFile;
  File? _receiptPhotoFile;

  String get _spSignKey => 'pending_sign_photo_${widget.orderId}';
  String get _spReceiptKey => 'pending_receipt_photo_${widget.orderId}';

  @override
  void initState() {
    super.initState();
    _loadPendingPhotosFromSp();
    _loadData();
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _printUtil.init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPendingPhotosFromSp() async {
    final signPath = SpUtil.getString(_spSignKey);
    final receiptPath = SpUtil.getString(_spReceiptKey);
    if (signPath != null && signPath.isNotEmpty && File(signPath).existsSync()) {
      _signPhotoFile = File(signPath);
    }
    if (receiptPath != null && receiptPath.isNotEmpty && File(receiptPath).existsSync()) {
      _receiptPhotoFile = File(receiptPath);
    }
    if (mounted && (_signPhotoFile != null || _receiptPhotoFile != null)) {
      setState(() {});
    }
  }

  Future<void> _savePendingPhotoToSp(PhotoType type, String path) async {
    if (type == PhotoType.sign) {
      await SpUtil.putString(_spSignKey, path);
    } else {
      await SpUtil.putString(_spReceiptKey, path);
    }
  }

  Future<void> _clearPendingPhotoFromSp(PhotoType type) async {
    if (type == PhotoType.sign) {
      await SpUtil.remove(_spSignKey);
    } else {
      await SpUtil.remove(_spReceiptKey);
    }
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      LoggerUtil.i('网络已恢复，检查待同步照片');
      _tryRetryPendingPhotos();
    }
  }

  Future<void> _tryRetryPendingPhotos() async {
    if (_order == null) return;

    if (_signPhotoFile != null &&
        (_order!.status == TransferOrderStatus.ARRIVED)) {
      LoggerUtil.i('网络恢复，自动尝试提交签收照片');
      try {
        ToastUtil.showLoading('自动提交签收照片...');
        final bytes = await _signPhotoFile!.readAsBytes();
        final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await _orderService.signOrder(widget.orderId, signPhoto: base64);
        setState(() {
          _signPhotoFile = null;
        });
        _clearPendingPhotoFromSp(PhotoType.sign);
        ToastUtil.showSuccess('签收照片自动上传成功');
        _loadData();
      } catch (e) {
        LoggerUtil.e('自动提交签收照片失败: $e');
        ToastUtil.showError('自动提交失败，请手动重试');
      } finally {
        ToastUtil.dismissLoading();
      }
    }

    if (_receiptPhotoFile != null &&
        (_order!.status == TransferOrderStatus.SIGNED)) {
      LoggerUtil.i('网络恢复，自动尝试提交回执照片');
      try {
        ToastUtil.showLoading('自动提交回执照片...');
        final bytes = await _receiptPhotoFile!.readAsBytes();
        final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await _orderService.completeOrder(widget.orderId, receiptPhoto: base64);
        setState(() {
          _receiptPhotoFile = null;
        });
        _clearPendingPhotoFromSp(PhotoType.receipt);
        ToastUtil.showSuccess('回执照片自动上传成功');
        _loadData();
      } catch (e) {
        LoggerUtil.e('自动提交回执照片失败: $e');
        ToastUtil.showError('自动提交失败，请手动重试');
      } finally {
        ToastUtil.dismissLoading();
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _orderService.getDetailFull(widget.orderId);
      if (data != null) {
        setState(() {
          _order = TransferOrder.fromJson(data);
          if (data['timelineList'] != null) {
            _timelineList = (data['timelineList'] as List)
                .map((e) => TransferOrderTimeline.fromJson(e))
                .toList();
          }
          _qrCodeBase64 = _order?.qrCode;
        });
      }

      if (_qrCodeBase64 == null || _qrCodeBase64!.isEmpty) {
        final qrCode = await _orderService.getQrCode(widget.orderId);
        if (qrCode != null && qrCode.isNotEmpty) {
          setState(() {
            _qrCodeBase64 = qrCode;
          });
        }
      }
    } catch (e) {
      ToastUtil.showError('加载数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSyncStatus() async {
    try {
      ToastUtil.showLoading('正在同步状态...');
      final result = await _orderService.syncStatus(widget.orderId);
      if (result) {
        ToastUtil.showSuccess('状态同步成功');
        await _loadData();
      } else {
        ToastUtil.showInfo('状态未变化');
      }
    } catch (e) {
      ToastUtil.showError('同步失败: $e');
    } finally {
      ToastUtil.dismissLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联单详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _handleSyncStatus,
            tooltip: '同步状态',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printOrder,
            tooltip: '打印联单',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('未找到联单数据'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(),
                        const SizedBox(height: 16),
                        _buildQrCodeCard(),
                        const SizedBox(height: 16),
                        _buildBasicInfoCard(),
                        const SizedBox(height: 16),
                        _buildPartiesCard(),
                        const SizedBox(height: 16),
                        _buildWasteItemsCard(),
                        const SizedBox(height: 16),
                        _buildPhotosCard(),
                        const SizedBox(height: 16),
                        _buildTimelineCard(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final status = _order!.status;
    final statusName = TransferOrderStatus.getStatusName(status);
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case TransferOrderStatus.DRAFT:
        statusColor = Colors.grey;
        statusIcon = Icons.edit_note;
        break;
      case TransferOrderStatus.PENDING_REPORT:
        statusColor = Colors.orange;
        statusIcon = Icons.upload_file;
        break;
      case TransferOrderStatus.PENDING_TRANSPORT:
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case TransferOrderStatus.IN_TRANSIT:
        statusColor = Colors.cyan;
        statusIcon = Icons.drive_eta;
        break;
      case TransferOrderStatus.ARRIVED:
        statusColor = Colors.purple;
        statusIcon = Icons.location_on;
        break;
      case TransferOrderStatus.SIGNED:
        statusColor = Colors.teal;
        statusIcon = Icons.check_circle;
        break;
      case TransferOrderStatus.COMPLETED:
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        break;
      case TransferOrderStatus.CANCELLED:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '联单号: ${_order!.orderNo ?? '-'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (_order!.nationalOrderNo != null &&
                      _order!.nationalOrderNo!.isNotEmpty)
                    Text(
                      '国家联单号: ${_order!.nationalOrderNo}',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '联单二维码',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _showQrCodeDialog,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildQrCodeWidget(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '点击二维码可放大查看',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCodeWidget() {
    final qrData = _order!.orderNo ?? '';
    if (_qrCodeBase64 != null && _qrCodeBase64!.isNotEmpty) {
      try {
        if (_qrCodeBase64!.startsWith('data:image')) {
          final base64Str = _qrCodeBase64!.split(',').last;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(base64Str),
              fit: BoxFit.contain,
            ),
          );
        } else {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(_qrCodeBase64!),
              fit: BoxFit.contain,
            ),
          );
        }
      } catch (e) {
        return _buildQrFromQrFlutter(qrData);
      }
    }
    return _buildQrFromQrFlutter(qrData);
  }

  Widget _buildQrFromQrFlutter(String data) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: 180,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '基本信息',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('联单类型', _order!.orderType ?? '普通联单'),
            _buildInfoRow('总重量', '${_order!.totalWeight?.toStringAsFixed(2) ?? '0'} kg'),
            _buildInfoRow('容器数量', '${_order!.totalContainers ?? 0} 个'),
            _buildInfoRow('运输路线', _order!.route ?? '-'),
            _buildInfoRow('应急联系人', _order!.emergencyContact ?? '-'),
            _buildInfoRow('应急电话', _order!.emergencyPhone ?? '-'),
            _buildInfoRow('创建时间',
                DateUtil.formatDateTime(_order!.createTime)),
            _buildInfoRow('备注', _order!.remark ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildPartiesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.business, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '相关单位',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('产生单位'),
            _buildInfoRow('单位名称', _order!.generatorUnitName ?? '-'),
            _buildInfoRow('信用代码', _order!.generatorUnitCode ?? '-'),
            const Divider(height: 24),
            _buildSectionTitle('接收单位'),
            _buildInfoRow('单位名称', _order!.receiverUnitName ?? '-'),
            _buildInfoRow('信用代码', _order!.receiverUnitCode ?? '-'),
            _buildInfoRow('许可证号', _order!.receiverLicenseNo ?? '-'),
            const Divider(height: 24),
            _buildSectionTitle('运输单位'),
            _buildInfoRow('单位名称', _order!.transporterName ?? '-'),
            _buildInfoRow('许可证号', _order!.transporterLicenseNo ?? '-'),
            _buildInfoRow('车牌号', _order!.vehicleNo ?? '-'),
            _buildInfoRow('驾驶员', _order!.driverName ?? '-'),
            _buildInfoRow('从业资格证', _order!.driverLicense ?? '-'),
            _buildInfoRow('押运员', _order!.escortName ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteItemsCard() {
    final items = _order!.items ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '危废明细',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无危废明细'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.wasteCode ?? '-',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.wasteName ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('危废类别', item.wasteCategory ?? '-'),
                      _buildInfoRow('危险特性', item.hazardCode ?? '-'),
                      _buildInfoRow('容器编号', item.containerCode ?? '-'),
                      _buildInfoRow(
                          '重量', '${item.weight?.toStringAsFixed(2) ?? '0'} kg'),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '照片凭证',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_signPhotoFile != null || _receiptPhotoFile != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '待同步',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPhotoItem(
                    title: '签收照片',
                    currentPhoto: _order!.signPhoto,
                    pendingFile: _signPhotoFile,
                    onAdd: () => _pickPhoto(PhotoType.sign),
                    onView: () => _viewPhoto(_order!.signPhoto, _signPhotoFile),
                    canAdd: _canAddSignPhoto(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoItem(
                    title: '回执照片',
                    currentPhoto: _order!.receiptPhoto,
                    pendingFile: _receiptPhotoFile,
                    onAdd: () => _pickPhoto(PhotoType.receipt),
                    onView: () => _viewPhoto(_order!.receiptPhoto, _receiptPhotoFile),
                    canAdd: _canAddReceiptPhoto(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem({
    required String title,
    required String? currentPhoto,
    required File? pendingFile,
    required VoidCallback onAdd,
    required VoidCallback onView,
    required bool canAdd,
  }) {
    final hasPhoto = (currentPhoto != null && currentPhoto.isNotEmpty) ||
        pendingFile != null;

    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: hasPhoto ? onView : (canAdd ? onAdd : null),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canAdd ? Colors.blue.shade200 : Colors.grey.shade300,
              ),
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        SizedBox.expand(child: _buildPhotoWidget(currentPhoto, pendingFile)),
                        if (pendingFile != null)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '待上传',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Icon(
                      canAdd ? Icons.add_a_photo : Icons.lock_outline,
                      color: canAdd ? Colors.blue : Colors.grey,
                      size: 32,
                    ),
                  ),
          ),
        ),
        if (canAdd && !hasPhoto)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '点击拍照',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoWidget(String? networkUrl, File? localFile) {
    if (localFile != null) {
      return Image.file(localFile, fit: BoxFit.cover, width: double.infinity);
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      if (networkUrl.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: networkUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => const Icon(Icons.broken_image),
        );
      } else if (networkUrl.startsWith('data:image')) {
        try {
          final base64Str = networkUrl.split(',').last;
          return Image.memory(
            base64Decode(base64Str),
            fit: BoxFit.cover,
            width: double.infinity,
          );
        } catch (e) {
          return const Icon(Icons.broken_image);
        }
      }
    }
    return const Icon(Icons.image_not_supported);
  }

  Widget _buildTimelineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '联单轨迹',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_timelineList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无轨迹记录'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _timelineList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final timeline = _timelineList[index];
                  final isLast = index == _timelineList.length - 1;
                  return _buildTimelineItem(timeline, isLast);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(TransferOrderTimeline timeline, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isLast ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        timeline.eventName ?? '状态变更',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      DateUtil.formatDateTime(timeline.eventTime),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (timeline.fromStatusName != null &&
                    timeline.toStatusName != null)
                  Text(
                    '${timeline.fromStatusName} → ${timeline.toStatusName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                if (timeline.operatorName != null &&
                    timeline.operatorName!.isNotEmpty)
                  Text(
                    '操作人: ${timeline.operatorName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (timeline.location != null && timeline.location!.isNotEmpty)
                  Text(
                    '地点: ${timeline.location}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (timeline.remark != null && timeline.remark!.isNotEmpty)
                  Text(
                    '备注: ${timeline.remark}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final status = _order!.status;
    final List<Widget> buttons = [];

    if (status == TransferOrderStatus.PENDING_TRANSPORT) {
      buttons.add(_buildActionButton(
        label: '开始运输',
        icon: Icons.drive_eta,
        color: Colors.blue,
        onPressed: _handleStartTransport,
      ));
    }

    if (status == TransferOrderStatus.IN_TRANSIT) {
      buttons.add(_buildActionButton(
        label: '确认到达',
        icon: Icons.location_on,
        color: Colors.purple,
        onPressed: _handleArrive,
      ));
    }

    if (status == TransferOrderStatus.ARRIVED) {
      buttons.add(_buildActionButton(
        label: '联单签收',
        icon: Icons.check_circle,
        color: Colors.teal,
        onPressed: _handleSign,
      ));
    }

    if (status == TransferOrderStatus.SIGNED) {
      buttons.add(_buildActionButton(
        label: '上传回执',
        icon: Icons.photo,
        color: Colors.orange,
        onPressed: _handleUploadReceipt,
      ));
      buttons.add(_buildActionButton(
        label: '完成联单',
        icon: Icons.verified,
        color: Colors.green,
        onPressed: _handleComplete,
      ));
    }

    if (status == TransferOrderStatus.DRAFT ||
        status == TransferOrderStatus.PENDING_REPORT ||
        status == TransferOrderStatus.PENDING_TRANSPORT) {
      buttons.add(_buildActionButton(
        label: '取消联单',
        icon: Icons.cancel,
        color: Colors.red,
        onPressed: _handleCancel,
      ));
    }

    if (buttons.isEmpty && _signPhotoFile == null && _receiptPhotoFile == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (buttons.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: buttons,
          ),
        if (_signPhotoFile != null || _receiptPhotoFile != null)
          Padding(
            padding: EdgeInsets.only(top: buttons.isNotEmpty ? 16 : 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '有 ${(_signPhotoFile != null ? 1 : 0) + (_receiptPhotoFile != null ? 1 : 0)} 张照片暂存本地，联网后将自动上传',
                          style: TextStyle(
                              color: Colors.orange.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_signPhotoFile != null) {
                              _signPhotoFile = null;
                              _clearPendingPhotoFromSp(PhotoType.sign);
                            }
                            if (_receiptPhotoFile != null) {
                              _receiptPhotoFile = null;
                              _clearPendingPhotoFromSp(PhotoType.receipt);
                            }
                          });
                          ToastUtil.showSuccess('已清除本地暂存照片');
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清除暂存'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _tryRetryPendingPhotos,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('立即重试'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  bool _canAddSignPhoto() {
    final status = _order!.status;
    return status == TransferOrderStatus.ARRIVED;
  }

  bool _canAddReceiptPhoto() {
    final status = _order!.status;
    return status == TransferOrderStatus.SIGNED;
  }

  Future<void> _pickPhoto(PhotoType type) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        await _savePendingPhotoToSp(type, file.path);
        setState(() {
          if (type == PhotoType.sign) {
            _signPhotoFile = file;
          } else {
            _receiptPhotoFile = file;
          }
        });
        ToastUtil.showSuccess('拍照成功，已暂存本地');
        final result = await _connectivity.checkConnectivity();
        if (result != ConnectivityResult.none) {
          LoggerUtil.i('当前有网络，立即尝试提交');
          _tryRetryPendingPhotos();
        } else {
          ToastUtil.showInfo('当前无网络，照片已暂存，联网后自动上传');
        }
      }
    } catch (e) {
      ToastUtil.showError('拍照失败: $e');
    }
  }

  void _viewPhoto(String? networkUrl, File? localFile) {
    final hasLocal = localFile != null;
    final hasNetwork = networkUrl != null && networkUrl.isNotEmpty;
    if (!hasLocal && !hasNetwork) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: hasLocal
                ? PhotoView(imageProvider: FileImage(localFile!))
                : PhotoView(
                    imageProvider: networkUrl!.startsWith('http')
                        ? CachedNetworkImageProvider(networkUrl)
                        : MemoryImage(base64Decode(networkUrl.split(',').last))
                            as ImageProvider,
                  ),
          ),
        ),
      ),
    );
  }

  void _showQrCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 300,
          height: 360,
          child: Column(
            children: [
              const Text(
                '联单二维码',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(width: 250, height: 250, child: _buildQrCodeWidget()),
              const SizedBox(height: 8),
              Text(
                _order!.orderNo ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              if (_order?.orderNo != null) {
                await Clipboard.setData(
                    ClipboardData(text: _order!.orderNo ?? ''));
                ToastUtil.showSuccess('联单号已复制');
              }
            },
            child: const Text('复制联单号'),
          ),
          TextButton(
            onPressed: () => _printQrCodeOnly(),
            child: const Text('打印二维码'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartTransport() async {
    try {
      ToastUtil.showLoading('正在提交...');
      await _orderService.startTransport(widget.orderId);
      ToastUtil.showSuccess('开始运输成功');
      await _loadData();
    } catch (e) {
      ToastUtil.showError('操作失败: $e');
    } finally {
      ToastUtil.dismissLoading();
    }
  }

  Future<void> _handleArrive() async {
    final locationController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认到达'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: '到达地点（选填）',
            hintText: '请输入到达地点',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, locationController.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        ToastUtil.showLoading('正在提交...');
        await _orderService.arrive(
          widget.orderId,
          location: result.isEmpty ? null : result,
        );
        ToastUtil.showSuccess('到达确认成功');
        await _loadData();
      } catch (e) {
        ToastUtil.showError('操作失败: $e');
      } finally {
        ToastUtil.dismissLoading();
      }
    }
  }

  Future<void> _handleSign() async {
    String? signPhotoBase64;

    if (_signPhotoFile != null) {
      try {
        final bytes = await _signPhotoFile!.readAsBytes();
        signPhotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (e) {
        ToastUtil.showError('处理照片失败: $e');
        return;
      }
    } else if (_order!.signPhoto == null || _order!.signPhoto!.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('尚未拍摄签收照片，是否继续签收？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('去拍照'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        await _pickPhoto(PhotoType.sign);
        return;
      }
    }

    try {
      ToastUtil.showLoading('正在提交签收...');
      await _orderService.signOrder(
        widget.orderId,
        signPhoto: signPhotoBase64 ?? _order!.signPhoto,
      );
      ToastUtil.showSuccess('签收成功');
      setState(() {
        _signPhotoFile = null;
      });
      _clearPendingPhotoFromSp(PhotoType.sign);
      await _loadData();
    } catch (e) {
      LoggerUtil.e('签收提交失败: $e');
      if (_signPhotoFile != null) {
        ToastUtil.showError('签收提交失败，照片已暂存本地，联网后将自动上传');
      } else {
        ToastUtil.showError('签收失败: $e');
      }
    } finally {
      ToastUtil.dismissLoading();
    }
  }

  Future<void> _handleUploadReceipt() async {
    if (_receiptPhotoFile == null) {
      await _pickPhoto(PhotoType.receipt);
      return;
    }

    try {
      final bytes = await _receiptPhotoFile!.readAsBytes();
      final receiptPhotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      ToastUtil.showLoading('正在上传回执...');
      await _orderService.completeOrder(
        widget.orderId,
        receiptPhoto: receiptPhotoBase64,
      );
      ToastUtil.showSuccess('回执上传成功');
      setState(() {
        _receiptPhotoFile = null;
      });
      _clearPendingPhotoFromSp(PhotoType.receipt);
      await _loadData();
    } catch (e) {
      LoggerUtil.e('回执上传失败: $e');
      ToastUtil.showError('上传失败，照片已暂存本地，联网后将自动上传');
    } finally {
      ToastUtil.dismissLoading();
    }
  }

  Future<void> _handleComplete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认完成'),
        content: const Text('确认完成此联单吗？完成后将无法修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        ToastUtil.showLoading('正在提交...');
        String? receiptPhotoBase64;
        if (_receiptPhotoFile != null) {
          final bytes = await _receiptPhotoFile!.readAsBytes();
          receiptPhotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        } else if (_order!.receiptPhoto != null &&
            _order!.receiptPhoto!.isNotEmpty) {
          receiptPhotoBase64 = _order!.receiptPhoto;
        }
        await _orderService.completeOrder(
          widget.orderId,
          receiptPhoto: receiptPhotoBase64,
        );
        ToastUtil.showSuccess('联单已完成');
        setState(() {
          _receiptPhotoFile = null;
        });
        _clearPendingPhotoFromSp(PhotoType.receipt);
        await _loadData();
      } catch (e) {
        ToastUtil.showError('操作失败: $e');
      } finally {
        ToastUtil.dismissLoading();
      }
    }
  }

  Future<void> _handleCancel() async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消联单'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '取消原因',
            hintText: '请输入取消原因',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        ToastUtil.showLoading('正在取消...');
        await _orderService.cancelOrder(
          widget.orderId,
          reason: result.isEmpty ? null : result,
        );
        ToastUtil.showSuccess('联单已取消');
        await _loadData();
      } catch (e) {
        ToastUtil.showError('取消失败: $e');
      } finally {
        ToastUtil.dismissLoading();
      }
    }
  }

  Future<void> _printOrder() async {
    if (_order == null) return;
    _showPrintDialog();
  }

  void _showPrintDialog() {
    showDialog(
      context: context,
      builder: (context) => _PrinterSelectDialog(
        printUtil: _printUtil,
        onPrint: () async {
          if (_order == null) return;
          final orderData = {
            'orderNo': _order!.orderNo,
            'nationalOrderNo': _order!.nationalOrderNo,
            'generatorUnitName': _order!.generatorUnitName,
            'receiverUnitName': _order!.receiverUnitName,
            'transporterName': _order!.transporterName,
            'vehicleNo': _order!.vehicleNo,
            'driverName': _order!.driverName,
            'wasteName': _order!.items?.isNotEmpty == true ? _order!.items!.first.wasteName : null,
            'wasteCode': _order!.items?.isNotEmpty == true ? _order!.items!.first.wasteCode : null,
            'totalWeight': _order!.totalWeight,
            'totalContainers': _order!.totalContainers,
            'status': _order!.status,
            'createTime': DateUtil.formatDateTime(_order!.createTime),
          };
          final ok = await _printUtil.printTransferOrder(orderData);
          if (ok) {
            ToastUtil.showSuccess('打印指令已发送');
          } else {
            ToastUtil.showError('打印失败，请检查打印机连接');
          }
        },
        onPrintQr: () async {
          if (_order?.orderNo == null) return;
          final ok = await _printUtil.printQrCode(_order!.orderNo!);
          if (ok) {
            ToastUtil.showSuccess('二维码打印指令已发送');
          } else {
            ToastUtil.showError('打印失败，请检查打印机连接');
          }
        },
      ),
    );
  }

  Future<void> _printQrCodeOnly() async {
    if (_order?.orderNo == null) return;
    Navigator.pop(context);
    final ok = await _printUtil.printQrCode(_order!.orderNo!);
    if (ok) {
      ToastUtil.showSuccess('二维码打印指令已发送');
    } else {
      ToastUtil.showError('打印失败，请检查打印机连接');
    }
  }
}

class _PrinterSelectDialog extends StatefulWidget {
  final PrintUtil printUtil;
  final Future<void> Function() onPrint;
  final Future<void> Function() onPrintQr;

  const _PrinterSelectDialog({
    Key? key,
    required this.printUtil,
    required this.onPrint,
    required this.onPrintQr,
  }) : super(key: key);

  @override
  State<_PrinterSelectDialog> createState() => _PrinterSelectDialogState();
}

class _PrinterSelectDialogState extends State<_PrinterSelectDialog> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.printUtil.isConnected;
    _selectedDevice = widget.printUtil.selectedDevice;
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });
    widget.printUtil.bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
    widget.printUtil.bluetoothPrint.scanResults.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    ToastUtil.showLoading('正在连接打印机...');
    final ok = await widget.printUtil.connect(device);
    ToastUtil.dismissLoading();
    if (ok) {
      setState(() {
        _selectedDevice = device;
        _isConnected = true;
      });
      ToastUtil.showSuccess('打印机连接成功');
    } else {
      ToastUtil.showError('打印机连接失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择打印机'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isScanning ? '扫描中...' : '可用设备 (${_devices.length})'),
                TextButton.icon(
                  onPressed: _startScan,
                  icon: Icon(Icons.refresh, size: 18, color: _isScanning ? Colors.grey : Colors.blue),
                  label: Text(_isScanning ? '扫描中' : '重新扫描'),
                ),
              ],
            ),
            if (_isConnected && _selectedDevice != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已连接: ${_selectedDevice!.name ?? _selectedDevice!.address}',
                        style: const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: _isScanning
                          ? const CircularProgressIndicator()
                          : const Text('未发现蓝牙设备，请确保打印机已开启'),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected = _selectedDevice?.address == device.address;
                        return ListTile(
                          leading: const Icon(Icons.print),
                          title: Text(device.name ?? '未知设备'),
                          subtitle: Text(device.address ?? ''),
                          trailing: isSelected && _isConnected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : TextButton(
                                  onPressed: () => _connect(device),
                                  child: const Text('连接'),
                                ),
                          onTap: () {
                            if (isSelected && _isConnected) {
                              setState(() {});
                            } else {
                              _connect(device);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton.icon(
          onPressed: _isConnected
              ? () async {
                  Navigator.pop(context);
                  await widget.onPrintQr();
                }
              : null,
          icon: const Icon(Icons.qr_code, size: 18),
          label: const Text('只打二维码'),
        ),
        ElevatedButton.icon(
          onPressed: _isConnected
              ? () async {
                  Navigator.pop(context);
                  await widget.onPrint();
                }
              : null,
          icon: const Icon(Icons.print, size: 18),
          label: const Text('打印联单'),
        ),
      ],
    );
  }
}

enum PhotoType { sign, receipt }
