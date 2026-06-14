import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../utils/logger_util.dart';
import '../utils/sp_util.dart';

/// 蓝牙设备类型
enum BluetoothDeviceType {
  /// 打印机
  printer,

  /// 地磅
  scale,

  /// 其他
  other,
}

/// 蓝牙设备信息
class BluetoothDeviceInfo {
  final String name;
  final String address;
  final BluetoothDeviceType type;
  final int rssi;
  final bool isBonded;

  BluetoothDeviceInfo({
    required this.name,
    required this.address,
    this.type = BluetoothDeviceType.other,
    this.rssi = 0,
    this.isBonded = false,
  });

  factory BluetoothDeviceInfo.fromScanResult(ScanResult result) {
    final deviceName = result.device.localName.isNotEmpty
        ? result.device.localName
        : result.device.platformName;
    final type = _detectDeviceType(deviceName);
    return BluetoothDeviceInfo(
      name: deviceName,
      address: result.device.remoteId.toString(),
      type: type,
      rssi: result.rssi,
      isBonded: false,
    );
  }

  static BluetoothDeviceType _detectDeviceType(String name) {
    final upperName = name.toUpperCase();
    if (upperName.contains('PRINTER') ||
        upperName.contains('PRINT') ||
        upperName.contains('打印') ||
        upperName.contains('MP-') ||
        upperName.contains('BLUETOOTH PRINTER')) {
      return BluetoothDeviceType.printer;
    }
    if (upperName.contains('SCALE') ||
        upperName.contains('WEIGHT') ||
        upperName.contains('地磅') ||
        upperName.contains('称重') ||
        upperName.contains('SCALES')) {
      return BluetoothDeviceType.scale;
    }
    return BluetoothDeviceType.other;
  }
}

/// ESC/POS 打印指令工具类
class EscPosCommands {
  EscPosCommands._();

  /// 初始化打印机
  static List<int> get initPrinter => [0x1B, 0x40];

  /// 选择加粗字体
  static List<int> get boldOn => [0x1B, 0x45, 0x01];

  /// 取消加粗字体
  static List<int> get boldOff => [0x1B, 0x45, 0x00];

  /// 选择倍高倍宽
  static List<int> get doubleSize => [0x1D, 0x21, 0x11];

  /// 选择倍高
  static List<int> get doubleHeight => [0x1D, 0x21, 0x01];

  /// 选择倍宽
  static List<int> get doubleWidth => [0x1D, 0x21, 0x10];

  /// 取消倍高倍宽
  static List<int> get normalSize => [0x1D, 0x21, 0x00];

  /// 左对齐
  static List<int> get alignLeft => [0x1B, 0x61, 0x00];

  /// 居中对齐
  static List<int> get alignCenter => [0x1B, 0x61, 0x01];

  /// 右对齐
  static List<int> get alignRight => [0x1B, 0x61, 0x02];

  /// 下划线开启
  static List<int> get underlineOn => [0x1B, 0x2D, 0x01];

  /// 下划线关闭
  static List<int> get underlineOff => [0x1B, 0x2D, 0x00];

  /// 打印并换行
  static List<int> get lineFeed => [0x0A];

  /// 走纸并切纸
  static List<int> get cutPaper => [0x1D, 0x56, 0x01];

  /// 打印并走纸n行
  static List<int> feedLines(int n) => [0x1B, 0x64, n];

  /// 设置字符间距
  static List<int> setCharSpacing(int n) => [0x1B, 0x20, n];

  /// 设置行间距
  static List<int> setLineSpacing(int n) => [0x1B, 0x33, n];

  /// 生成打印文本的字节数据
  static List<int> text(String text, {String encoding = 'gbk'}) {
    try {
      if (encoding.toLowerCase() == 'gbk') {
        return utf8.encode(text);
      }
      return utf8.encode(text);
    } catch (e) {
      return utf8.encode(text);
    }
  }

  /// 打印一行文本
  static List<int> printLine(String text) {
    return [...text(text), ...lineFeed];
  }

  /// 打印分割线
  static List<int> printDivider({char = '-', int width = 32}) {
    final divider = List.filled(width, char).join();
    return printLine(divider);
  }

  /// 打印空行
  static List<int> printEmptyLine({int count = 1}) {
    return List.generate(count, (_) => 0x0A);
  }

  /// 生成二维码数据（QR Code Model 2）
  static List<int> printQrCode(String data, {int size = 8}) {
    final bytes = <int>[];

    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x33]);

    final dataBytes = utf8.encode(data);
    final dataLength = dataBytes.length + 3;
    final pL = dataLength % 256;
    final pH = dataLength ~/ 256;
    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...dataBytes]);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }

  /// 打印条码（CODE128）
  static List<int> printBarcode(String data, {int height = 80}) {
    final bytes = <int>[];
    bytes.addAll([0x1D, 0x68, height]);
    bytes.addAll([0x1D, 0x77, 0x02]);
    bytes.addAll([0x1D, 0x48, 0x02]);
    bytes.addAll([0x1D, 0x6B, 0x49]);
    bytes.add(data.length);
    bytes.addAll(utf8.encode(data));
    return bytes;
  }
}

/// 危废标签数据
class WasteLabelData {
  final String containerCode;
  final String wasteCode;
  final String wasteName;
  final String wasteCategory;
  final String hazardCode;
  final double weight;
  final String produceUnit;
  final String produceDate;
  final String storageLocation;
  final String? operatorName;
  final String? qrData;

  WasteLabelData({
    required this.containerCode,
    required this.wasteCode,
    required this.wasteName,
    required this.wasteCategory,
    required this.hazardCode,
    required this.weight,
    required this.produceUnit,
    required this.produceDate,
    required this.storageLocation,
    this.operatorName,
    this.qrData,
  });
}

/// 蓝牙服务类
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  bool _isScanning = false;
  bool _isConnected = false;
  BluetoothDeviceType? _connectedDeviceType;

  final StreamController<List<BluetoothDeviceInfo>> _scanResultsController =
      StreamController<List<BluetoothDeviceInfo>>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  final StreamController<List<int>> _dataReceivedController =
      StreamController<List<int>>.broadcast();
  final StreamController<double> _weightStreamController =
      StreamController<double>.broadcast();
  final StreamController<String> _scaleDataStreamController =
      StreamController<String>.broadcast();

  final List<BluetoothDeviceInfo> _scanResults = [];
  final List<int> _weightBuffer = [];
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BluetoothService._internal();

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isPrinterConnected =>
      _isConnected && _connectedDeviceType == BluetoothDeviceType.printer;
  bool get isScaleConnected =>
      _isConnected && _connectedDeviceType == BluetoothDeviceType.scale;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothDeviceType? get connectedDeviceType => _connectedDeviceType;
  String? get connectedDeviceName => _connectedDevice?.localName.isNotEmpty == true
      ? _connectedDevice!.localName
      : _connectedDevice?.platformName;
  String? get connectedDeviceAddress => _connectedDevice?.remoteId.toString();

  Stream<List<BluetoothDeviceInfo>> get scanResultsStream =>
      _scanResultsController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<List<int>> get dataReceivedStream => _dataReceivedController.stream;
  Stream<double> get weightStream => _weightStreamController.stream;
  Stream<String> get scaleDataStream => _scaleDataStreamController.stream;

  /// 检查蓝牙是否支持
  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      LoggerUtil.error('检查蓝牙可用性失败', e);
      return false;
    }
  }

  /// 检查蓝牙是否开启
  Future<bool> isBluetoothOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      LoggerUtil.error('检查蓝牙状态失败', e);
      return false;
    }
  }

  /// 监听蓝牙适配器状态
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// 请求开启蓝牙
  Future<bool> turnOnBluetooth() async {
    try {
      if (await isBluetoothOn()) return true;
      await FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(seconds: 1));
      return await isBluetoothOn();
    } catch (e) {
      LoggerUtil.error('开启蓝牙失败', e);
      return false;
    }
  }

  /// 开始蓝牙扫描
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    List<Guid> withServices = const [],
    List<String> withNames = const [],
    bool allowDuplicates = false,
    bool androidUsesFineLocation = true,
  }) async {
    try {
      if (_isScanning) {
        LoggerUtil.warning('蓝牙扫描已在进行中');
        return;
      }

      final isOn = await isBluetoothOn();
      if (!isOn) {
        throw Exception('蓝牙未开启，请先开启蓝牙');
      }

      _isScanning = true;
      _scanResults.clear();
      _scanResultsController.add([]);

      FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final deviceName = result.device.localName.isNotEmpty
              ? result.device.localName
              : result.device.platformName;
          if (deviceName.isEmpty) continue;
          if (withNames.isNotEmpty &&
              !withNames.any((name) => deviceName.contains(name))) {
            continue;
          }
          final exists = _scanResults.any(
            (d) => d.address == result.device.remoteId.toString(),
          );
          if (!exists) {
            final info = BluetoothDeviceInfo.fromScanResult(result);
            _scanResults.add(info);
            _scanResultsController.add(List.from(_scanResults));
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: withServices,
        continuousUpdates: allowDuplicates,
        androidUsesFineLocation: androidUsesFineLocation,
      );

      LoggerUtil.info('开始蓝牙扫描，超时: ${timeout.inSeconds}秒');
    } catch (e) {
      LoggerUtil.error('开始蓝牙扫描失败', e);
      _isScanning = false;
      rethrow;
    }
  }

  /// 停止蓝牙扫描
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      LoggerUtil.info('停止蓝牙扫描，发现设备: ${_scanResults.length}');
    } catch (e) {
      LoggerUtil.error('停止蓝牙扫描失败', e);
    }
  }

  /// 获取扫描结果
  List<BluetoothDeviceInfo> getScanResults() {
    return List.from(_scanResults);
  }

  /// 连接蓝牙设备
  Future<void> connect(BluetoothDevice device) async {
    try {
      LoggerUtil.info('连接蓝牙设备: ${device.localName} (${device.remoteId})');

      if (_connectedDevice != null && _isConnected) {
        if (_connectedDevice!.remoteId == device.remoteId) {
          LoggerUtil.warning('设备已连接');
          return;
        }
        await disconnect();
      }

      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _connectedDevice = null;
          _connectedDeviceType = null;
          _connectionStateController.add(false);
          _notifySubscription?.cancel();
          LoggerUtil.warning('蓝牙设备已断开');
        }
      });

      await device.connect(
        timeout: Duration(seconds: AppConfig.bluetoothConnectTimeout),
        autoConnect: false,
      );

      _connectedDevice = device;
      _isConnected = true;
      _connectionStateController.add(true);

      final deviceName = device.localName.isNotEmpty
          ? device.localName
          : device.platformName;
      _connectedDeviceType = BluetoothDeviceInfo._detectDeviceType(deviceName);

      await _discoverServices();

      LoggerUtil.info('蓝牙设备连接成功: $deviceName, 类型: $_connectedDeviceType');

      if (_connectedDeviceType == BluetoothDeviceType.printer) {
        await SpUtil.putString(StorageConstants.connectedPrinterAddress,
            device.remoteId.toString());
        await SpUtil.putString(
            StorageConstants.connectedPrinterName, deviceName);
      } else if (_connectedDeviceType == BluetoothDeviceType.scale) {
        await SpUtil.putString(StorageConstants.connectedScaleAddress,
            device.remoteId.toString());
        await SpUtil.putString(
            StorageConstants.connectedScaleName, deviceName);
        _startListeningScaleData();
      }
    } catch (e) {
      LoggerUtil.error('连接蓝牙设备失败', e);
      _isConnected = false;
      _connectedDevice = null;
      _connectedDeviceType = null;
      _connectionStateController.add(false);
      rethrow;
    }
  }

  /// 通过地址连接设备
  Future<void> connectByAddress(String address) async {
    try {
      final device = BluetoothDevice.fromId(address);
      await connect(device);
    } catch (e) {
      LoggerUtil.error('通过地址连接蓝牙设备失败: $address', e);
      rethrow;
    }
  }

  /// 自动连接已保存的打印机
  Future<bool> autoConnectPrinter() async {
    try {
      final address = SpUtil.getString(StorageConstants.connectedPrinterAddress);
      if (address == null || address.isEmpty) return false;
      await connectByAddress(address);
      return isPrinterConnected;
    } catch (e) {
      LoggerUtil.warning('自动连接打印机失败: $e');
      return false;
    }
  }

  /// 自动连接已保存的地磅
  Future<bool> autoConnectScale() async {
    try {
      final address = SpUtil.getString(StorageConstants.connectedScaleAddress);
      if (address == null || address.isEmpty) return false;
      await connectByAddress(address);
      return isScaleConnected;
    } catch (e) {
      LoggerUtil.warning('自动连接地磅失败: $e');
      return false;
    }
  }

  /// 发现服务和特征值
  Future<void> _discoverServices() async {
    try {
      if (_connectedDevice == null) {
        throw Exception('未连接蓝牙设备');
      }

      final services = await _connectedDevice!.discoverServices();
      LoggerUtil.debug('发现服务数量: ${services.length}');

      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final props = characteristic.properties;

          if (props.write || props.writeWithoutResponse) {
            if (_writeCharacteristic == null) {
              _writeCharacteristic = characteristic;
              LoggerUtil.debug('找到写入特征: ${characteristic.uuid}');
            }
          }

          if (props.read) {
            if (_readCharacteristic == null) {
              _readCharacteristic = characteristic;
              LoggerUtil.debug('找到读取特征: ${characteristic.uuid}');
            }
          }

          if (props.notify || props.indicate) {
            if (_notifyCharacteristic == null) {
              _notifyCharacteristic = characteristic;
              LoggerUtil.debug('找到通知特征: ${characteristic.uuid}');
            }
          }
        }
      }

      if (_notifyCharacteristic != null) {
        try {
          await _notifyCharacteristic!.setNotifyValue(true);
          _notifySubscription =
              _notifyCharacteristic!.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
              _dataReceivedController.add(value);
              if (_connectedDeviceType == BluetoothDeviceType.scale) {
                _parseScaleData(value);
              }
            }
          });
          LoggerUtil.debug('已启用特征值通知');
        } catch (e) {
          LoggerUtil.warning('启用特征值通知失败: $e');
        }
      }
    } catch (e) {
      LoggerUtil.error('发现服务失败', e);
    }
  }

  /// 断开蓝牙连接
  Future<void> disconnect() async {
    try {
      _notifySubscription?.cancel();
      _connectionStateSubscription?.cancel();

      if (_connectedDevice != null) {
        try {
          await _connectedDevice!.disconnect();
          LoggerUtil.info('蓝牙设备已断开: ${connectedDeviceName ?? ""}');
        } catch (e) {
          LoggerUtil.warning('断开设备出错: $e');
        }
      }

      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
      _notifyCharacteristic = null;
      _isConnected = false;
      _connectedDeviceType = null;
      _weightBuffer.clear();
      _connectionStateController.add(false);
    } catch (e) {
      LoggerUtil.error('断开蓝牙设备失败', e);
    }
  }

  /// 发送原始字节数据
  Future<void> sendData(List<int> data) async {
    try {
      if (_writeCharacteristic == null) {
        throw Exception('未连接蓝牙设备或未找到写入特征');
      }

      await _writeCharacteristic!.write(data, withoutResponse: true);
      LoggerUtil.debug('发送数据成功，长度: ${data.length}');
    } catch (e) {
      LoggerUtil.error('发送数据失败', e);
      rethrow;
    }
  }

  /// 发送字符串数据
  Future<void> sendString(String data) async {
    try {
      final bytes = utf8.encode(data);
      await sendData(bytes);
    } catch (e) {
      LoggerUtil.error('发送字符串失败', e);
      rethrow;
    }
  }

  /// 读取数据
  Future<List<int>?> readData() async {
    try {
      if (_readCharacteristic == null) {
        throw Exception('未设置读取特征');
      }
      final data = await _readCharacteristic!.read();
      LoggerUtil.debug('读取数据成功，长度: ${data.length}');
      return data;
    } catch (e) {
      LoggerUtil.error('读取数据失败', e);
      return null;
    }
  }

  // ==================== 打印相关方法 ====================

  /// 检查打印机是否连接
  Future<bool> checkPrinterReady() async {
    if (!isPrinterConnected) {
      return await autoConnectPrinter();
    }
    return true;
  }

  /// 初始化打印机
  Future<void> initPrinter() async {
    if (!await checkPrinterReady()) {
      throw Exception('打印机未连接');
    }
    await sendData(EscPosCommands.initPrinter);
  }

  /// 打印简单文本
  Future<void> printText(String text) async {
    if (!await checkPrinterReady()) {
      throw Exception('打印机未连接');
    }
    final bytes = <int>[];
    bytes.addAll(EscPosCommands.alignLeft);
    bytes.addAll(EscPosCommands.text(text));
    bytes.addAll(EscPosCommands.lineFeed);
    await sendData(bytes);
  }

  /// 打印多行文本
  Future<void> printLines(List<String> lines) async {
    if (!await checkPrinterReady()) {
      throw Exception('打印机未连接');
    }
    final bytes = <int>[];
    bytes.addAll(EscPosCommands.alignLeft);
    for (final line in lines) {
      bytes.addAll(EscPosCommands.text(line));
      bytes.addAll(EscPosCommands.lineFeed);
    }
    bytes.addAll(EscPosCommands.printEmptyLine(count: 3));
    await sendData(bytes);
  }

  /// 打印危废标签
  Future<void> printWasteLabel(WasteLabelData labelData) async {
    if (!await checkPrinterReady()) {
      throw Exception('打印机未连接');
    }

    final bytes = <int>[];

    bytes.addAll(EscPosCommands.initPrinter);
    bytes.addAll(EscPosCommands.setLineSpacing(40));

    bytes.addAll(EscPosCommands.alignCenter);
    bytes.addAll(EscPosCommands.boldOn);
    bytes.addAll(EscPosCommands.doubleHeight);
    bytes.addAll(EscPosCommands.printLine('危险废物标签'));
    bytes.addAll(EscPosCommands.boldOff);
    bytes.addAll(EscPosCommands.normalSize);

    bytes.addAll(EscPosCommands.printDivider());

    bytes.addAll(EscPosCommands.alignLeft);
    bytes.addAll(EscPosCommands.printLine('容器编号: ${labelData.containerCode}'));
    bytes.addAll(EscPosCommands.printLine('危废代码: ${labelData.wasteCode}'));
    bytes.addAll(EscPosCommands.printLine('危废名称: ${labelData.wasteName}'));
    bytes.addAll(EscPosCommands.printLine('废物类别: ${labelData.wasteCategory}'));
    bytes.addAll(EscPosCommands.printLine('危险特性: ${labelData.hazardCode}'));
    bytes.addAll(EscPosCommands.printLine(
        '重量: ${labelData.weight.toStringAsFixed(AppConfig.weightDecimalPlaces)} kg'));
    bytes.addAll(EscPosCommands.printLine('产生单位: ${labelData.produceUnit}'));
    bytes.addAll(EscPosCommands.printLine('产生日期: ${labelData.produceDate}'));
    bytes.addAll(EscPosCommands.printLine('存放位置: ${labelData.storageLocation}'));
    if (labelData.operatorName != null) {
      bytes.addAll(EscPosCommands.printLine('经办人: ${labelData.operatorName}'));
    }

    bytes.addAll(EscPosCommands.printEmptyLine());

    final qrData = labelData.qrData ??
        'WC:${labelData.containerCode};W:${labelData.wasteCode};WT:${labelData.weight.toStringAsFixed(2)}';
    bytes.addAll(EscPosCommands.alignCenter);
    bytes.addAll(EscPosCommands.printQrCode(qrData, size: 8));

    bytes.addAll(EscPosCommands.printEmptyLine(count: 2));
    bytes.addAll(EscPosCommands.printLine('扫码查看详情'));
    bytes.addAll(EscPosCommands.printEmptyLine(count: 3));

    await sendData(bytes);
    LoggerUtil.info('打印危废标签成功: ${labelData.containerCode}');
  }

  /// 打印入库单
  Future<void> printWasteInReceipt({
    required String inNo,
    required String containerCode,
    required String wasteCode,
    required String wasteName,
    required double weight,
    required String produceDate,
    required String operatorName,
    required String printTime,
  }) async {
    if (!await checkPrinterReady()) {
      throw Exception('打印机未连接');
    }

    final bytes = <int>[];
    bytes.addAll(EscPosCommands.initPrinter);

    bytes.addAll(EscPosCommands.alignCenter);
    bytes.addAll(EscPosCommands.boldOn);
    bytes.addAll(EscPosCommands.doubleHeight);
    bytes.addAll(EscPosCommands.printLine('危险废物入库单'));
    bytes.addAll(EscPosCommands.boldOff);
    bytes.addAll(EscPosCommands.normalSize);

    bytes.addAll(EscPosCommands.printDivider());

    bytes.addAll(EscPosCommands.alignLeft);
    bytes.addAll(EscPosCommands.printLine('入库单号: $inNo'));
    bytes.addAll(EscPosCommands.printLine('容器编号: $containerCode'));
    bytes.addAll(EscPosCommands.printLine('危废代码: $wasteCode'));
    bytes.addAll(EscPosCommands.printLine('危废名称: $wasteName'));
    bytes.addAll(EscPosCommands.printLine(
        '入库重量: ${weight.toStringAsFixed(AppConfig.weightDecimalPlaces)} kg'));
    bytes.addAll(EscPosCommands.printLine('产生日期: $produceDate'));
    bytes.addAll(EscPosCommands.printLine('经办人: $operatorName'));

    bytes.addAll(EscPosCommands.printDivider());
    bytes.addAll(EscPosCommands.alignRight);
    bytes.addAll(EscPosCommands.printLine('打印时间: $printTime'));
    bytes.addAll(EscPosCommands.printEmptyLine(count: 3));

    await sendData(bytes);
    LoggerUtil.info('打印入库单成功: $inNo');
  }

  /// 打印出库单
  Future<void> printWasteOutReceipt({
    required String outNo,
    required String containerCode,
    required String wasteCode,
    required String wasteName,
    required double weight,
    required String receiverUnit,
    required String operatorName,
    required String printTime,
  }) async {
    if (!await checkPrinterReady()) {
      throw Exception('打印机未连接');
    }

    final bytes = <int>[];
    bytes.addAll(EscPosCommands.initPrinter);

    bytes.addAll(EscPosCommands.alignCenter);
    bytes.addAll(EscPosCommands.boldOn);
    bytes.addAll(EscPosCommands.doubleHeight);
    bytes.addAll(EscPosCommands.printLine('危险废物出库单'));
    bytes.addAll(EscPosCommands.boldOff);
    bytes.addAll(EscPosCommands.normalSize);

    bytes.addAll(EscPosCommands.printDivider());

    bytes.addAll(EscPosCommands.alignLeft);
    bytes.addAll(EscPosCommands.printLine('出库单号: $outNo'));
    bytes.addAll(EscPosCommands.printLine('容器编号: $containerCode'));
    bytes.addAll(EscPosCommands.printLine('危废代码: $wasteCode'));
    bytes.addAll(EscPosCommands.printLine('危废名称: $wasteName'));
    bytes.addAll(EscPosCommands.printLine(
        '出库重量: ${weight.toStringAsFixed(AppConfig.weightDecimalPlaces)} kg'));
    bytes.addAll(EscPosCommands.printLine('接收单位: $receiverUnit'));
    bytes.addAll(EscPosCommands.printLine('经办人: $operatorName'));

    bytes.addAll(EscPosCommands.printDivider());
    bytes.addAll(EscPosCommands.alignRight);
    bytes.addAll(EscPosCommands.printLine('打印时间: $printTime'));
    bytes.addAll(EscPosCommands.printEmptyLine(count: 3));

    await sendData(bytes);
    LoggerUtil.info('打印出库单成功: $outNo');
  }

  // ==================== 地磅相关方法 ====================

  /// 检查地磅是否连接
  Future<bool> checkScaleReady() async {
    if (!isScaleConnected) {
      return await autoConnectScale();
    }
    return true;
  }

  /// 开始监听地磅数据
  void _startListeningScaleData() {
    _weightBuffer.clear();
    LoggerUtil.debug('开始监听地磅数据');
  }

  /// 解析地磅数据
  void _parseScaleData(List<int> data) {
    _weightBuffer.addAll(data);

    while (_weightBuffer.length > 0) {
      int startIndex = -1;
      int endIndex = -1;

      for (int i = 0; i < _weightBuffer.length; i++) {
        if (_weightBuffer[i] == 0x02 || _weightBuffer[i] == 61 || _weightBuffer[i] == 87) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        _weightBuffer.clear();
        return;
      }

      for (int i = startIndex; i < _weightBuffer.length; i++) {
        if (_weightBuffer[i] == 0x03 || _weightBuffer[i] == 0x0D || _weightBuffer[i] == 0x0A) {
          endIndex = i;
          break;
        }
      }

      if (endIndex == -1) {
        if (_weightBuffer.length > 50) {
          _weightBuffer.removeRange(0, startIndex + 1);
        }
        return;
      }

      final frameData = _weightBuffer.sublist(startIndex, endIndex + 1);
      _weightBuffer.removeRange(0, endIndex + 1);

      try {
        final weight = _decodeWeight(frameData);
        if (weight != null) {
          _weightStreamController.add(weight);
          _scaleDataStreamController.add(weight.toStringAsFixed(3));
        }
      } catch (e) {
        LoggerUtil.debug('解析地磅数据失败: $e');
      }
    }
  }

  /// 解码重量数据
  double? _decodeWeight(List<int> data) {
    try {
      String str = String.fromCharCodes(data);

      final numericRegex = RegExp(r'[-+]?\d+\.?\d*');
      final match = numericRegex.firstMatch(str);
      if (match != null) {
        final numStr = match.group(0);
        if (numStr != null) {
          final weight = double.tryParse(numStr);
          if (weight != null && weight >= 0) {
            return double.parse(weight.toStringAsFixed(AppConfig.weightDecimalPlaces));
          }
        }
      }

      if (data.length >= 8) {
        final byteData = ByteData.sublistView(Uint8List.fromList(data));
        if (data.length >= 4) {
          try {
            final floatValue = byteData.getFloat32(0, Endian.little);
            if (floatValue >= 0 && floatValue < 100000) {
              return double.parse(floatValue.toStringAsFixed(AppConfig.weightDecimalPlaces));
            }
          } catch (_) {}
          try {
            final floatValue = byteData.getFloat32(0, Endian.big);
            if (floatValue >= 0 && floatValue < 100000) {
              return double.parse(floatValue.toStringAsFixed(AppConfig.weightDecimalPlaces));
            }
          } catch (_) {}
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 发送地磅指令（读取重量）
  Future<void> sendScaleReadCommand() async {
    if (!await checkScaleReady()) {
      throw Exception('地磅未连接');
    }
    await sendData([0x01, 0x03, 0x00, 0x00, 0x00, 0x02, 0xC4, 0x0B]);
  }

  /// 发送去皮指令
  Future<void> sendScaleTareCommand() async {
    if (!await checkScaleReady()) {
      throw Exception('地磅未连接');
    }
    await sendData([0x01, 0x06, 0x00, 0x01, 0x00, 0x01, 0x19, 0xCB]);
  }

  /// 发送归零指令
  Future<void> sendScaleZeroCommand() async {
    if (!await checkScaleReady()) {
      throw Exception('地磅未连接');
    }
    await sendData([0x01, 0x06, 0x00, 0x02, 0x00, 0x01, 0x69, 0xCB]);
  }

  /// 释放资源
  void dispose() {
    stopScan();
    disconnect();
    _scanResultsController.close();
    _connectionStateController.close();
    _dataReceivedController.close();
    _weightStreamController.close();
    _scaleDataStreamController.close();
  }
}
