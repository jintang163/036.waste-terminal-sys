import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../models/transfer_order.dart';
import '../services/transfer_order_service.dart';
import '../utils/date_util.dart';
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

  TransferOrder? _order;
  List<TransferOrderTimeline> _timelineList = [];
  bool _isLoading = true;
  String? _qrCodeBase64;
  File? _signPhotoFile;
  File? _receiptPhotoFile;
  String? _pendingSignPhotoPath;
  String? _pendingReceiptPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联单详情'),
        actions: [
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
            const Row(
              children: [
                Icon(Icons.photo_library, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '照片凭证',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    child: _buildPhotoWidget(currentPhoto, pendingFile),
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

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: buttons,
        ),
        if (_pendingSignPhotoPath != null || _pendingReceiptPhotoPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '有离线暂存的照片待同步，请联网后重新进入页面提交',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 13),
                    ),
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
        setState(() {
          if (type == PhotoType.sign) {
            _signPhotoFile = file;
          } else {
            _receiptPhotoFile = file;
          }
        });
        ToastUtil.showSuccess('拍照成功，请点击对应按钮提交');
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
          height: 320,
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
              if (_qrCodeBase64 != null) {
                await Clipboard.setData(
                    ClipboardData(text: _order!.orderNo ?? ''));
                ToastUtil.showSuccess('联单号已复制');
              }
            },
            child: const Text('复制联单号'),
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
        _pendingSignPhotoPath = null;
      });
      await _loadData();
    } catch (e) {
      ToastUtil.showError('签收失败: $e');
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
        _pendingReceiptPhotoPath = null;
      });
      await _loadData();
    } catch (e) {
      ToastUtil.showError('上传失败: $e');
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
    ToastUtil.showInfo('正在准备打印...');
    await Future.delayed(const Duration(seconds: 1));
    ToastUtil.showSuccess('打印功能开发中，请稍候');
  }
}

enum PhotoType { sign, receipt }
