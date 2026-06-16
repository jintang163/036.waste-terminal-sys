import 'dart:io';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../services/bluetooth_service.dart';
import '../utils/logger_util.dart';
import '../utils/permission_util.dart';
import '../utils/sp_util.dart';

enum CheckStatus { success, warning, error, unknown }

enum CheckItemType {
  bluetoothAvailable,
  bluetoothOn,
  bluetoothConnected,
  storageSpace,
  cameraPermission,
  bluetoothPermission,
  storagePermission,
  networkStatus,
}

class CheckResult {
  final CheckItemType type;
  final CheckStatus status;
  final String title;
  final String? message;
  final dynamic detail;
  final DateTime checkTime;

  CheckResult({
    required this.type,
    required this.status,
    required this.title,
    this.message,
    this.detail,
    DateTime? checkTime,
  }) : checkTime = checkTime ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'status': status.name,
      'title': title,
      'message': message,
      'detail': detail?.toString(),
      'checkTime': checkTime.toIso8601String(),
    };
  }

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(
      type: CheckItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CheckItemType.networkStatus,
      ),
      status: CheckStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CheckStatus.unknown,
      ),
      title: json['title'] as String,
      message: json['message'] as String?,
      detail: json['detail'],
      checkTime: DateTime.tryParse(json['checkTime'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DeviceDetailInfo {
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;
  final String? manufacturer;
  final String? brand;
  final String? osVersion;
  final String? sdkVersion;
  final String? platform;
  final int? totalStorage;
  final int? freeStorage;
  final int? totalMemory;
  final int? freeMemory;

  DeviceDetailInfo({
    this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.manufacturer,
    this.brand,
    this.osVersion,
    this.sdkVersion,
    this.platform,
    this.totalStorage,
    this.freeStorage,
    this.totalMemory,
    this.freeMemory,
  });

  double get storageUsagePercent {
    if (totalStorage == null || totalStorage == 0) return 0;
    return ((totalStorage! - (freeStorage ?? 0)) / totalStorage!) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
      'brand': brand,
      'osVersion': osVersion,
      'sdkVersion': sdkVersion,
      'platform': platform,
      'totalStorage': totalStorage,
      'freeStorage': freeStorage,
      'totalMemory': totalMemory,
      'freeMemory': freeMemory,
    };
  }
}

class SelfCheckReport {
  final DateTime checkTime;
  final DeviceDetailInfo deviceInfo;
  final List<CheckResult> results;
  final CheckStatus overallStatus;

  SelfCheckReport({
    DateTime? checkTime,
    required this.deviceInfo,
    required this.results,
    CheckStatus? overallStatus,
  })  : checkTime = checkTime ?? DateTime.now(),
        overallStatus = overallStatus ?? _calculateOverallStatus(results);

  static CheckStatus _calculateOverallStatus(List<CheckResult> results) {
    if (results.isEmpty) return CheckStatus.unknown;
    if (results.any((r) => r.status == CheckStatus.error)) return CheckStatus.error;
    if (results.any((r) => r.status == CheckStatus.warning)) return CheckStatus.warning;
    if (results.every((r) => r.status == CheckStatus.success)) return CheckStatus.success;
    return CheckStatus.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'checkTime': checkTime.toIso8601String(),
      'deviceInfo': deviceInfo.toJson(),
      'results': results.map((r) => r.toJson()).toList(),
      'overallStatus': overallStatus.name,
    };
  }

  factory SelfCheckReport.fromJson(Map<String, dynamic> json) {
    return SelfCheckReport(
      checkTime: DateTime.tryParse(json['checkTime'] as String? ?? '') ?? DateTime.now(),
      deviceInfo: DeviceDetailInfo(
        deviceId: json['deviceInfo']?['deviceId'] as String?,
        deviceName: json['deviceInfo']?['deviceName'] as String?,
        deviceModel: json['deviceInfo']?['deviceModel'] as String?,
        manufacturer: json['deviceInfo']?['manufacturer'] as String?,
        brand: json['deviceInfo']?['brand'] as String?,
        osVersion: json['deviceInfo']?['osVersion'] as String?,
        sdkVersion: json['deviceInfo']?['sdkVersion'] as String?,
        platform: json['deviceInfo']?['platform'] as String?,
        totalStorage: json['deviceInfo']?['totalStorage'] as int?,
        freeStorage: json['deviceInfo']?['freeStorage'] as int?,
        totalMemory: json['deviceInfo']?['totalMemory'] as int?,
        freeMemory: json['deviceInfo']?['freeMemory'] as int?,
      ),
      results: (json['results'] as List? ?? [])
          .map((e) => CheckResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      overallStatus: CheckStatus.values.firstWhere(
        (e) => e.name == json['overallStatus'],
        orElse: () => CheckStatus.unknown,
      ),
    );
  }
}

class DeviceSelfCheckService {
  static final DeviceSelfCheckService _instance = DeviceSelfCheckService._internal();
  factory DeviceSelfCheckService() => _instance;

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  final BluetoothService _bluetoothService = BluetoothService();

  SelfCheckReport? _lastReport;
  SelfCheckReport? get lastReport => _lastReport;

  DeviceSelfCheckService._internal();

  Future<DeviceDetailInfo> getDeviceDetailInfo() async {
    try {
      String? deviceId = SpUtil.getDeviceId();
      String? deviceName;
      String? deviceModel;
      String? manufacturer;
      String? brand;
      String? osVersion;
      String? sdkVersion;
      String? platform = Platform.operatingSystem;
      int? totalStorage;
      int? freeStorage;
      int? totalMemory;
      int? freeMemory;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceId ??= androidInfo.id;
        deviceName = androidInfo.model;
        deviceModel = androidInfo.model;
        manufacturer = androidInfo.manufacturer;
        brand = androidInfo.brand;
        osVersion = androidInfo.version.release;
        sdkVersion = androidInfo.version.sdkInt.toString();
        totalMemory = androidInfo.totalMemory;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId ??= iosInfo.identifierForVendor;
        deviceName = iosInfo.name;
        deviceModel = iosInfo.model;
        manufacturer = 'Apple';
        brand = 'Apple';
        osVersion = iosInfo.systemVersion;
        sdkVersion = iosInfo.utsname.release;
      }

      final storageInfo = await _getStorageInfo();
      totalStorage = storageInfo['total'];
      freeStorage = storageInfo['free'];

      return DeviceDetailInfo(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceModel: deviceModel,
        manufacturer: manufacturer,
        brand: brand,
        osVersion: osVersion,
        sdkVersion: sdkVersion,
        platform: platform,
        totalStorage: totalStorage,
        freeStorage: freeStorage,
        totalMemory: totalMemory,
        freeMemory: freeMemory,
      );
    } catch (e) {
      LoggerUtil.error('获取设备详细信息失败', e);
      return DeviceDetailInfo(platform: Platform.operatingSystem);
    }
  }

  Future<Map<String, int>> _getStorageInfo() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final stat = await directory.stat();
      int free = 0;
      int total = 0;

      try {
        if (Platform.isAndroid) {
          final dir = Directory('/storage/emulated/0');
          if (await dir.exists()) {
            final fsType = await dir.stat();
            free = fsType.size > 0 ? fsType.size : 0;
          }
        }
      } catch (_) {}

      return {
        'total': total > 0 ? total : 1024 * 1024 * 1024 * 64,
        'free': free > 0 ? free : 1024 * 1024 * 1024 * 10,
      };
    } catch (e) {
      LoggerUtil.warning('获取存储信息失败: $e');
      return {
        'total': 1024 * 1024 * 1024 * 64,
        'free': 1024 * 1024 * 1024 * 10,
      };
    }
  }

  Future<CheckResult> _checkBluetoothAvailable() async {
    try {
      final available = await _bluetoothService.isBluetoothAvailable();
      return CheckResult(
        type: CheckItemType.bluetoothAvailable,
        status: available ? CheckStatus.success : CheckStatus.error,
        title: '蓝牙硬件支持',
        message: available ? '设备支持蓝牙功能' : '设备不支持蓝牙功能',
        detail: available,
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.bluetoothAvailable,
        status: CheckStatus.error,
        title: '蓝牙硬件支持',
        message: '蓝牙检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkBluetoothOn() async {
    try {
      final isOn = await _bluetoothService.isBluetoothOn();
      return CheckResult(
        type: CheckItemType.bluetoothOn,
        status: isOn ? CheckStatus.success : CheckStatus.warning,
        title: '蓝牙开关状态',
        message: isOn ? '蓝牙已开启' : '蓝牙未开启，部分功能将不可用',
        detail: isOn,
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.bluetoothOn,
        status: CheckStatus.error,
        title: '蓝牙开关状态',
        message: '蓝牙状态检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkBluetoothConnected() async {
    try {
      final isConnected = _bluetoothService.isConnected;
      final deviceName = _bluetoothService.connectedDeviceName;
      final deviceType = _bluetoothService.connectedDeviceType?.name;

      String message;
      CheckStatus status;

      if (isConnected) {
        message = '已连接: $deviceName (${deviceType ?? '未知类型'})';
        status = CheckStatus.success;
      } else {
        message = '未连接蓝牙设备（打印机/地磅/RFID）';
        status = CheckStatus.warning;
      }

      return CheckResult(
        type: CheckItemType.bluetoothConnected,
        status: status,
        title: '蓝牙设备连接',
        message: message,
        detail: {
          'isConnected': isConnected,
          'deviceName': deviceName,
          'deviceType': deviceType,
        },
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.bluetoothConnected,
        status: CheckStatus.error,
        title: '蓝牙设备连接',
        message: '蓝牙连接检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkStorageSpace() async {
    try {
      final storageInfo = await _getStorageInfo();
      final free = storageInfo['free'] ?? 0;
      final total = storageInfo['total'] ?? 1;
      final usagePercent = ((total - free) / total) * 100;
      final freeGB = free / (1024 * 1024 * 1024);

      CheckStatus status;
      String message;

      if (free < AppConfig.storageWarningThreshold) {
        status = CheckStatus.error;
        message = '存储空间严重不足，剩余 ${freeGB.toStringAsFixed(1)} GB';
      } else if (usagePercent > 85) {
        status = CheckStatus.warning;
        message = '存储空间紧张，已使用 ${usagePercent.toStringAsFixed(1)}%，剩余 ${freeGB.toStringAsFixed(1)} GB';
      } else {
        status = CheckStatus.success;
        message = '存储空间充足，已使用 ${usagePercent.toStringAsFixed(1)}%，剩余 ${freeGB.toStringAsFixed(1)} GB';
      }

      return CheckResult(
        type: CheckItemType.storageSpace,
        status: status,
        title: '存储空间',
        message: message,
        detail: {
          'total': total,
          'free': free,
          'usagePercent': usagePercent,
        },
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.storageSpace,
        status: CheckStatus.unknown,
        title: '存储空间',
        message: '存储检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      CheckStatus checkStatus;
      String message;

      switch (status) {
        case PermissionStatus.granted:
        case PermissionStatus.limited:
          checkStatus = CheckStatus.success;
          message = '相机权限已授予';
          break;
        case PermissionStatus.denied:
          checkStatus = CheckStatus.warning;
          message = '相机权限未授予，请在设置中开启';
          break;
        case PermissionStatus.permanentlyDenied:
          checkStatus = CheckStatus.error;
          message = '相机权限被永久拒绝，需要手动到系统设置开启';
          break;
        case PermissionStatus.restricted:
          checkStatus = CheckStatus.warning;
          message = '相机权限受系统限制';
          break;
        case PermissionStatus.provisional:
          checkStatus = CheckStatus.warning;
          message = '相机权限为临时授权';
          break;
      }

      return CheckResult(
        type: CheckItemType.cameraPermission,
        status: checkStatus,
        title: '相机权限',
        message: message,
        detail: status.name,
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.cameraPermission,
        status: CheckStatus.error,
        title: '相机权限',
        message: '相机权限检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkBluetoothPermission() async {
    try {
      PermissionStatus scanStatus;
      PermissionStatus connectStatus;
      if (Platform.isAndroid) {
        scanStatus = await Permission.bluetoothScan.status;
        connectStatus = await Permission.bluetoothConnect.status;
      } else {
        scanStatus = await Permission.bluetooth.status;
        connectStatus = scanStatus;
      }

      final allGranted = (scanStatus.isGranted || scanStatus.isLimited) &&
          (connectStatus.isGranted || connectStatus.isLimited);

      CheckStatus checkStatus;
      String message;

      if (allGranted) {
        checkStatus = CheckStatus.success;
        message = '蓝牙权限已授予';
      } else if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
        checkStatus = CheckStatus.error;
        message = '蓝牙权限被永久拒绝，需要手动到系统设置开启';
      } else {
        checkStatus = CheckStatus.warning;
        message = '蓝牙权限未完整授予（扫描:${scanStatus.name}, 连接:${connectStatus.name}）';
      }

      return CheckResult(
        type: CheckItemType.bluetoothPermission,
        status: checkStatus,
        title: '蓝牙权限',
        message: message,
        detail: {
          'scan': scanStatus.name,
          'connect': connectStatus.name,
        },
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.bluetoothPermission,
        status: CheckStatus.error,
        title: '蓝牙权限',
        message: '蓝牙权限检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkStoragePermission() async {
    try {
      final PermissionStatus status;
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.photos.status;
        } else {
          status = await Permission.storage.status;
        }
      } else {
        status = await Permission.photos.status;
      }

      CheckStatus checkStatus;
      String message;

      switch (status) {
        case PermissionStatus.granted:
        case PermissionStatus.limited:
          checkStatus = CheckStatus.success;
          message = '存储权限已授予';
          break;
        case PermissionStatus.denied:
          checkStatus = CheckStatus.warning;
          message = '存储权限未授予，请在设置中开启';
          break;
        case PermissionStatus.permanentlyDenied:
          checkStatus = CheckStatus.error;
          message = '存储权限被永久拒绝，需要手动到系统设置开启';
          break;
        case PermissionStatus.restricted:
          checkStatus = CheckStatus.warning;
          message = '存储权限受系统限制';
          break;
        case PermissionStatus.provisional:
          checkStatus = CheckStatus.warning;
          message = '存储权限为临时授权';
          break;
      }

      return CheckResult(
        type: CheckItemType.storagePermission,
        status: checkStatus,
        title: '存储权限',
        message: message,
        detail: status.name,
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.storagePermission,
        status: CheckStatus.error,
        title: '存储权限',
        message: '存储权限检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<CheckResult> _checkNetworkStatus() async {
    try {
      final isAvailable = await _isNetworkAvailable();
      final networkType = await _getNetworkType();

      CheckStatus status;
      String message;

      if (isAvailable) {
        status = CheckStatus.success;
        message = '网络连接正常 ($networkType)';
      } else {
        status = CheckStatus.warning;
        message = '网络未连接，将使用离线模式';
      }

      return CheckResult(
        type: CheckItemType.networkStatus,
        status: status,
        title: '网络连接',
        message: message,
        detail: {
          'available': isAvailable,
          'type': networkType,
        },
      );
    } catch (e) {
      return CheckResult(
        type: CheckItemType.networkStatus,
        status: CheckStatus.unknown,
        title: '网络连接',
        message: '网络检测失败: $e',
        detail: e.toString(),
      );
    }
  }

  Future<bool> _isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('baidu.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getNetworkType() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wifi')) {
          return 'WiFi';
        }
        if (name.contains('rmnet') || name.contains('mobile') || name.contains('cellular')) {
          return '移动网络';
        }
      }
      return '未知';
    } catch (_) {
      return '未知';
    }
  }

  Future<SelfCheckReport> performSelfCheck() async {
    LoggerUtil.info('开始执行设备自检');

    final deviceInfo = await getDeviceDetailInfo();
    final results = <CheckResult>[];

    results.add(await _checkNetworkStatus());
    results.add(await _checkBluetoothAvailable());
    results.add(await _checkBluetoothPermission());
    results.add(await _checkBluetoothOn());
    results.add(await _checkBluetoothConnected());
    results.add(await _checkStorageSpace());
    results.add(await _checkCameraPermission());
    results.add(await _checkStoragePermission());

    final report = SelfCheckReport(
      checkTime: DateTime.now(),
      deviceInfo: deviceInfo,
      results: results,
    );

    _lastReport = report;

    await SpUtil.putString(
      StorageConstants.deviceSelfCheckResult,
      jsonEncode(report.toJson()),
    );

    final successCount = results.where((r) => r.status == CheckStatus.success).length;
    final warningCount = results.where((r) => r.status == CheckStatus.warning).length;
    final errorCount = results.where((r) => r.status == CheckStatus.error).length;

    LoggerUtil.info(
      '设备自检完成: 成功$successCount项, 警告$warningCount项, 错误$errorCount项',
    );

    return report;
  }

  Future<SelfCheckReport?> getCachedReport() async {
    try {
      final cached = SpUtil.getString(StorageConstants.deviceSelfCheckResult);
      if (cached != null && cached.isNotEmpty) {
        return SelfCheckReport.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (e) {
      LoggerUtil.warning('读取缓存自检结果失败: $e');
    }
    return null;
  }

  Future<bool> requestBluetoothPermissions() async {
    try {
      if (Platform.isAndroid) {
        final results = await PermissionUtil.requestList([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetooth,
        ]);
        return results.values.every((s) => s.isGranted || s.isLimited);
      } else {
        return await PermissionUtil.requestBluetooth();
      }
    } catch (e) {
      LoggerUtil.error('请求蓝牙权限失败', e);
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    return await PermissionUtil.requestCamera();
  }

  Future<bool> requestStoragePermission() async {
    return await PermissionUtil.requestStorage();
  }

  Future<bool> requestAllRequiredPermissions() async {
    final btOk = await requestBluetoothPermissions();
    final cameraOk = await requestCameraPermission();
    final storageOk = await requestStoragePermission();
    return btOk && cameraOk && storageOk;
  }

  Future<void> turnOnBluetooth() async {
    await _bluetoothService.turnOnBluetooth();
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
