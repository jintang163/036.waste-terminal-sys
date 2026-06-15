import 'dart:async';

import '../db/waste_container_db.dart';
import '../services/bluetooth_service.dart';
import '../utils/logger_util.dart';

enum RfidScanMode {
  single,
  inventory,
}

class RfidTagInfo {
  final String epc;
  final DateTime scanTime;
  final String? containerCode;
  final bool matched;

  RfidTagInfo({
    required this.epc,
    required this.scanTime,
    this.containerCode,
    this.matched = false,
  });

  RfidTagInfo copyWith({
    String? epc,
    DateTime? scanTime,
    String? containerCode,
    bool? matched,
  }) {
    return RfidTagInfo(
      epc: epc ?? this.epc,
      scanTime: scanTime ?? this.scanTime,
      containerCode: containerCode ?? this.containerCode,
      matched: matched ?? this.matched,
    );
  }
}

class RfidService {
  static final RfidService _instance = RfidService._internal();
  factory RfidService() => _instance;

  final BluetoothService _bluetoothService = BluetoothService();
  final WasteContainerDb _containerDb = WasteContainerDb();

  final List<RfidTagInfo> _scannedTags = [];
  final Map<String, RfidTagInfo> _tagMap = {};

  RfidScanMode _scanMode = RfidScanMode.inventory;
  bool _isScanning = false;
  bool _isConnected = false;
  StreamSubscription<String>? _rfidTagSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  final StreamController<List<RfidTagInfo>> _tagsController =
      StreamController<List<RfidTagInfo>>.broadcast();
  final StreamController<RfidTagInfo> _newTagController =
      StreamController<RfidTagInfo>.broadcast();
  final StreamController<bool> _scanningStateController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  RfidService._internal();

  List<RfidTagInfo> get scannedTags => List.unmodifiable(_scannedTags);
  int get tagCount => _scannedTags.length;
  int get matchedCount => _scannedTags.where((t) => t.matched).length;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  RfidScanMode get scanMode => _scanMode;

  Stream<List<RfidTagInfo>> get tagsStream => _tagsController.stream;
  Stream<RfidTagInfo> get newTagStream => _newTagController.stream;
  Stream<bool> get scanningStateStream => _scanningStateController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  Future<void> init() async {
    _connectionSubscription?.cancel();
    _connectionSubscription = _bluetoothService.connectionStateStream.listen((connected) {
      _isConnected = connected && _bluetoothService.isRfidConnected;
      _connectionStateController.add(_isConnected);
    });

    _rfidTagSubscription?.cancel();
    _rfidTagSubscription = _bluetoothService.rfidTagStream.listen((epc) {
      _handleTagRead(epc);
    });

    _isConnected = _bluetoothService.isRfidConnected;
    _connectionStateController.add(_isConnected);
  }

  Future<bool> connect({String? deviceAddress}) async {
    try {
      if (deviceAddress != null && deviceAddress.isNotEmpty) {
        await _bluetoothService.connectByAddress(deviceAddress);
      } else {
        final connected = await _bluetoothService.autoConnectRfid();
        if (!connected) {
          LoggerUtil.warning('RFID读卡器自动连接失败');
          return false;
        }
      }
      _isConnected = _bluetoothService.isRfidConnected;
      _connectionStateController.add(_isConnected);
      return _isConnected;
    } catch (e) {
      LoggerUtil.error('连接RFID读卡器失败', e);
      _isConnected = false;
      _connectionStateController.add(false);
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_isScanning) {
        await stopScan();
      }
      if (_bluetoothService.isRfidConnected) {
        await _bluetoothService.disconnect();
      }
      _isConnected = false;
      _connectionStateController.add(false);
    } catch (e) {
      LoggerUtil.error('断开RFID读卡器失败', e);
    }
  }

  Future<void> startScan({RfidScanMode mode = RfidScanMode.inventory}) async {
    if (_isScanning) return;
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) {
        throw Exception('RFID读卡器未连接');
      }
    }

    _scanMode = mode;
    _isScanning = true;
    _scanningStateController.add(true);

    try {
      if (mode == RfidScanMode.inventory) {
        await _bluetoothService.sendRfidStartInventoryCommand();
      } else {
        await _bluetoothService.sendRfidSingleReadCommand();
      }
      LoggerUtil.info('开始RFID扫描，模式: $mode');
    } catch (e) {
      _isScanning = false;
      _scanningStateController.add(false);
      rethrow;
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      if (_scanMode == RfidScanMode.inventory) {
        await _bluetoothService.sendRfidStopInventoryCommand();
      }
    } catch (e) {
      LoggerUtil.warning('停止RFID扫描指令发送失败: $e');
    } finally {
      _isScanning = false;
      _scanningStateController.add(false);
      LoggerUtil.info('停止RFID扫描，已读取标签数: ${_scannedTags.length}');
    }
  }

  void _handleTagRead(String epc) {
    if (_tagMap.containsKey(epc)) {
      return;
    }

    final tag = RfidTagInfo(
      epc: epc,
      scanTime: DateTime.now(),
      matched: false,
    );

    _tagMap[epc] = tag;
    _scannedTags.add(tag);
    _tagsController.add(List.from(_scannedTags));
    _newTagController.add(tag);

    _matchContainer(epc);
  }

  Future<void> _matchContainer(String epc) async {
    try {
      final container = await _containerDb.queryByRfidCode(epc);
      if (container != null) {
        final code = container['container_code'] as String?;
        final index = _scannedTags.indexWhere((t) => t.epc == epc);
        if (index >= 0) {
          _scannedTags[index] = _scannedTags[index].copyWith(
            containerCode: code,
            matched: true,
          );
          _tagMap[epc] = _scannedTags[index];
          _tagsController.add(List.from(_scannedTags));
        }
      }
    } catch (e) {
      LoggerUtil.debug('匹配容器失败: $e');
    }
  }

  Future<void> matchAllContainers() async {
    for (int i = 0; i < _scannedTags.length; i++) {
      final tag = _scannedTags[i];
      if (!tag.matched) {
        try {
          final container = await _containerDb.queryByRfidCode(tag.epc);
          if (container != null) {
            final code = container['container_code'] as String?;
            _scannedTags[i] = tag.copyWith(
              containerCode: code,
              matched: true,
            );
            _tagMap[tag.epc] = _scannedTags[i];
          }
        } catch (_) {}
      }
    }
    _tagsController.add(List.from(_scannedTags));
  }

  void removeTag(String epc) {
    _scannedTags.removeWhere((t) => t.epc == epc);
    _tagMap.remove(epc);
    _tagsController.add(List.from(_scannedTags));
  }

  void clearTags() {
    _scannedTags.clear();
    _tagMap.clear();
    _tagsController.add([]);
  }

  void dispose() {
    _rfidTagSubscription?.cancel();
    _connectionSubscription?.cancel();
    _tagsController.close();
    _newTagController.close();
    _scanningStateController.close();
    _connectionStateController.close();
  }
}
