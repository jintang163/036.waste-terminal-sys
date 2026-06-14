import 'package:permission_handler/permission_handler.dart';

import 'logger_util.dart';

class PermissionUtil {
  PermissionUtil._();

  static Future<PermissionStatus> request(Permission permission) async {
    final status = await permission.status;
    LoggerUtil.permission(permission.toString(), status.toString());

    if (status.isGranted) {
      return status;
    }

    if (status.isDenied) {
      final result = await permission.request();
      LoggerUtil.permission(
        permission.toString(),
        'request result: $result',
      );
      return result;
    }

    if (status.isPermanentlyDenied) {
      LoggerUtil.permission(
        permission.toString(),
        'permanently denied, open settings',
      );
      await openAppSettings();
      return status;
    }

    if (status.isRestricted) {
      return status;
    }

    return status;
  }

  static Future<bool> isGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  static Future<bool> isDenied(Permission permission) async {
    final status = await permission.status;
    return status.isDenied;
  }

  static Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  static Future<Map<Permission, PermissionStatus>> requestList(
    List<Permission> permissions,
  ) async {
    final result = await permissions.request();
    LoggerUtil.permission('multiple permissions', result.toString());
    return result;
  }

  static Future<bool> requestAllGranted(List<Permission> permissions) async {
    final results = await requestList(permissions);
    return results.values.every((status) => status.isGranted);
  }

  static Future<bool> requestCamera() async {
    final status = await request(Permission.camera);
    return status.isGranted;
  }

  static Future<bool> requestPhotos() async {
    final status = await request(Permission.photos);
    return status.isGranted;
  }

  static Future<bool> requestStorage() async {
    final status = await request(Permission.storage);
    return status.isGranted;
  }

  static Future<bool> requestLocation() async {
    final status = await request(Permission.location);
    return status.isGranted;
  }

  static Future<bool> requestLocationAlways() async {
    final status = await request(Permission.locationAlways);
    return status.isGranted;
  }

  static Future<bool> requestLocationWhenInUse() async {
    final status = await request(Permission.locationWhenInUse);
    return status.isGranted;
  }

  static Future<bool> requestMicrophone() async {
    final status = await request(Permission.microphone);
    return status.isGranted;
  }

  static Future<bool> requestBluetooth() async {
    final status = await request(Permission.bluetooth);
    return status.isGranted;
  }

  static Future<bool> requestBluetoothScan() async {
    final status = await request(Permission.bluetoothScan);
    return status.isGranted;
  }

  static Future<bool> requestBluetoothConnect() async {
    final status = await request(Permission.bluetoothConnect);
    return status.isGranted;
  }

  static Future<bool> requestPhone() async {
    final status = await request(Permission.phone);
    return status.isGranted;
  }

  static Future<bool> requestSms() async {
    final status = await request(Permission.sms);
    return status.isGranted;
  }

  static Future<bool> requestContacts() async {
    final status = await request(Permission.contacts);
    return status.isGranted;
  }

  static Future<bool> requestNotification() async {
    final status = await request(Permission.notification);
    return status.isGranted;
  }

  static Future<bool> requestMediaLibrary() async {
    final status = await request(Permission.mediaLibrary);
    return status.isGranted;
  }

  static Future<bool> requestSensors() async {
    final status = await request(Permission.sensors);
    return status.isGranted;
  }

  static Future<bool> requestActivityRecognition() async {
    final status = await request(Permission.activityRecognition);
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  static Future<bool> shouldShowRequestRationale(Permission permission) async {
    return await permission.shouldShowRequestRationale;
  }

  static String getPermissionName(Permission permission) {
    return permission.toString().split('.').last;
  }
}
