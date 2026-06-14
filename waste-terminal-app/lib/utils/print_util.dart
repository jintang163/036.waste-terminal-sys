import 'dart:typed_data';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:logger/logger.dart';

class PrintUtil {
  static final PrintUtil _instance = PrintUtil._internal();
  factory PrintUtil() => _instance;

  final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  final Logger _logger = Logger();

  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;

  PrintUtil._internal();

  BluetoothPrint get bluetoothPrint => _bluetoothPrint;
  bool get isConnected => _isConnected;
  BluetoothDevice? get selectedDevice => _selectedDevice;

  Future<void> init() async {
    await _bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
    _logger.i('蓝牙打印初始化完成');
  }

  Stream<List<BluetoothDevice>> get scanResults => _bluetoothPrint.scanResults;

  Future<bool> connect(BluetoothDevice device) async {
    try {
      bool result = await _bluetoothPrint.connect(device) ?? false;
      if (result) {
        _selectedDevice = device;
        _isConnected = true;
        _logger.i('蓝牙打印机连接成功: ${device.name}');
      }
      return result;
    } catch (e) {
      _logger.e('蓝牙打印机连接失败: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _bluetoothPrint.disconnect();
    _isConnected = false;
    _selectedDevice = null;
    _logger.i('蓝牙打印机已断开');
  }

  Future<bool> printTransferOrder(Map<String, dynamic> orderData) async {
    if (!_isConnected) {
      _logger.w('打印机未连接');
      return false;
    }

    try {
      List<LineText> list = [];

      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '危险废物转移联单',
          weight: 2,
          width: 2,
          height: 2,
          align: LineText.ALIGN_CENTER,
          linefeed: 1));

      list.add(LineText(type: LineText.TYPE_TEXT, content: '=' * 32, align: LineText.ALIGN_CENTER, linefeed: 1));

      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '联单号: ${orderData['orderNo'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));

      if (orderData['nationalOrderNo'] != null && orderData['nationalOrderNo'].toString().isNotEmpty) {
        list.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '国家联单号: ${orderData['nationalOrderNo']}',
            align: LineText.ALIGN_LEFT,
            linefeed: 1));
      }

      list.add(LineText(type: LineText.TYPE_TEXT, content: '-' * 32, align: LineText.ALIGN_LEFT, linefeed: 1));

      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '产生单位: ${orderData['generatorUnitName'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '接收单位: ${orderData['receiverUnitName'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '运输单位: ${orderData['transporterName'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '车牌号码: ${orderData['vehicleNo'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '驾驶员: ${orderData['driverName'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));

      list.add(LineText(type: LineText.TYPE_TEXT, content: '-' * 32, align: LineText.ALIGN_LEFT, linefeed: 1));

      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '危废名称: ${orderData['wasteName'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '危废代码: ${orderData['wasteCode'] ?? '-'}',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '总重量: ${orderData['totalWeight']?.toString() ?? '0'} kg',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '容器数量: ${orderData['totalContainers']?.toString() ?? '0'} 个',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));

      list.add(LineText(type: LineText.TYPE_TEXT, content: '-' * 32, align: LineText.ALIGN_LEFT, linefeed: 1));

      String statusName = _getStatusName(orderData['status'] as int?);
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '当前状态: $statusName',
          align: LineText.ALIGN_LEFT,
          linefeed: 1));

      if (orderData['createTime'] != null) {
        list.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '创建时间: ${orderData['createTime']}',
            align: LineText.ALIGN_LEFT,
            linefeed: 1));
      }

      list.add(LineText(type: LineText.TYPE_TEXT, content: '=' * 32, align: LineText.ALIGN_CENTER, linefeed: 1));
      list.add(LineText(type: LineText.TYPE_TEXT, content: '    危废智能终端系统打印    ', align: LineText.ALIGN_CENTER, linefeed: 1));
      list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 2));

      await _bluetoothPrint.printReceipt(config: {}, lines: list);
      _logger.i('联单打印成功: ${orderData['orderNo']}');
      return true;
    } catch (e) {
      _logger.e('联单打印失败: $e');
      return false;
    }
  }

  Future<bool> printTest() async {
    if (!_isConnected) {
      return false;
    }
    try {
      List<LineText> list = [];
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '测试打印成功',
          weight: 1,
          align: LineText.ALIGN_CENTER,
          linefeed: 2));
      await _bluetoothPrint.printReceipt(config: {}, lines: list);
      return true;
    } catch (e) {
      _logger.e('测试打印失败: $e');
      return false;
    }
  }

  Future<bool> printQrCode(String content) async {
    if (!_isConnected) {
      return false;
    }
    try {
      List<LineText> list = [];
      list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '联单二维码',
          align: LineText.ALIGN_CENTER,
          linefeed: 1));
      list.add(LineText(
          type: LineText.TYPE_QRCODE,
          content: content,
          align: LineText.ALIGN_CENTER,
          linefeed: 1,
          size: 10));
      list.add(LineText(type: LineText.TYPE_TEXT, content: content, align: LineText.ALIGN_CENTER, linefeed: 2));
      await _bluetoothPrint.printReceipt(config: {}, lines: list);
      return true;
    } catch (e) {
      _logger.e('二维码打印失败: $e');
      return false;
    }
  }

  String _getStatusName(int? status) {
    switch (status) {
      case 0:
        return '待提交';
      case 1:
        return '待上报';
      case 2:
        return '待运输';
      case 3:
        return '运输中';
      case 4:
        return '已到达';
      case 5:
        return '已签收';
      case 6:
        return '已完成';
      case -1:
        return '已取消';
      default:
        return '未知';
    }
  }
}
