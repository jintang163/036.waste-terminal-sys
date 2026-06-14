class DeviceInfo {
  final int? id;
  final String? deviceNo;
  final String? deviceName;
  final String? deviceType;
  final String? deviceModel;
  final String? manufacturer;
  final String? connectType;
  final String? macAddress;
  final String? serialPort;
  final int? baudRate;
  final int? status;
  final DateTime? lastConnectTime;
  final int? enterpriseId;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  DeviceInfo({
    this.id,
    this.deviceNo,
    this.deviceName,
    this.deviceType,
    this.deviceModel,
    this.manufacturer,
    this.connectType,
    this.macAddress,
    this.serialPort,
    this.baudRate,
    this.status,
    this.lastConnectTime,
    this.enterpriseId,
    this.remark,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as int?,
      deviceNo: json['deviceNo'] as String?,
      deviceName: json['deviceName'] as String?,
      deviceType: json['deviceType'] as String?,
      deviceModel: json['deviceModel'] as String?,
      manufacturer: json['manufacturer'] as String?,
      connectType: json['connectType'] as String?,
      macAddress: json['macAddress'] as String?,
      serialPort: json['serialPort'] as String?,
      baudRate: json['baudRate'] as int?,
      status: json['status'] as int?,
      lastConnectTime: json['lastConnectTime'] != null
          ? DateTime.tryParse(json['lastConnectTime'] as String)
          : null,
      enterpriseId: json['enterpriseId'] as int?,
      remark: json['remark'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      deleted: json['deleted'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceNo': deviceNo,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
      'connectType': connectType,
      'macAddress': macAddress,
      'serialPort': serialPort,
      'baudRate': baudRate,
      'status': status,
      'lastConnectTime': lastConnectTime?.toIso8601String(),
      'enterpriseId': enterpriseId,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  DeviceInfo copyWith({
    int? id,
    String? deviceNo,
    String? deviceName,
    String? deviceType,
    String? deviceModel,
    String? manufacturer,
    String? connectType,
    String? macAddress,
    String? serialPort,
    int? baudRate,
    int? status,
    DateTime? lastConnectTime,
    int? enterpriseId,
    String? remark,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      deviceNo: deviceNo ?? this.deviceNo,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      deviceModel: deviceModel ?? this.deviceModel,
      manufacturer: manufacturer ?? this.manufacturer,
      connectType: connectType ?? this.connectType,
      macAddress: macAddress ?? this.macAddress,
      serialPort: serialPort ?? this.serialPort,
      baudRate: baudRate ?? this.baudRate,
      status: status ?? this.status,
      lastConnectTime: lastConnectTime ?? this.lastConnectTime,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      remark: remark ?? this.remark,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
