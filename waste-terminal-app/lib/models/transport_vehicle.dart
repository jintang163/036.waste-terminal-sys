class TransportVehicle {
  final int? id;
  final String? vehicleId;
  final String? vehicleNo;
  final String? vehicleType;
  final String? vehicleModel;
  final double? loadWeight;
  final double? loadVolume;
  final String? ownerUnit;
  final String? driverId;
  final String? driverName;
  final String? roadTransportLicense;
  final String? gpsTerminalId;
  final String? amapTerminalId;
  final int? status;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? isDeleted;

  TransportVehicle({
    this.id,
    this.vehicleId,
    this.vehicleNo,
    this.vehicleType,
    this.vehicleModel,
    this.loadWeight,
    this.loadVolume,
    this.ownerUnit,
    this.driverId,
    this.driverName,
    this.roadTransportLicense,
    this.gpsTerminalId,
    this.amapTerminalId,
    this.status,
    this.remark,
    this.createTime,
    this.updateTime,
    this.isDeleted,
  });

  factory TransportVehicle.fromJson(Map<String, dynamic> json) {
    return TransportVehicle(
      id: json['id'] as int?,
      vehicleId: json['vehicleId'] as String?,
      vehicleNo: json['vehicleNo'] as String?,
      vehicleType: json['vehicleType'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      loadWeight: (json['loadWeight'] as num?)?.toDouble(),
      loadVolume: (json['loadVolume'] as num?)?.toDouble(),
      ownerUnit: json['ownerUnit'] as String?,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      roadTransportLicense: json['roadTransportLicense'] as String?,
      gpsTerminalId: json['gpsTerminalId'] as String?,
      amapTerminalId: json['amapTerminalId'] as String?,
      status: json['status'] as int?,
      remark: json['remark'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      isDeleted: json['isDeleted'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'vehicleNo': vehicleNo,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'loadWeight': loadWeight,
      'loadVolume': loadVolume,
      'ownerUnit': ownerUnit,
      'driverId': driverId,
      'driverName': driverName,
      'roadTransportLicense': roadTransportLicense,
      'gpsTerminalId': gpsTerminalId,
      'amapTerminalId': amapTerminalId,
      'status': status,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory TransportVehicle.fromDbMap(Map<String, dynamic> map) {
    return TransportVehicle(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as String?,
      vehicleNo: map['vehicle_no'] as String?,
      vehicleType: map['vehicle_type'] as String?,
      vehicleModel: map['vehicle_model'] as String?,
      loadWeight: (map['load_weight'] as num?)?.toDouble(),
      loadVolume: (map['load_volume'] as num?)?.toDouble(),
      ownerUnit: map['owner_unit'] as String?,
      driverId: map['driver_id'] as String?,
      driverName: map['driver_name'] as String?,
      roadTransportLicense: map['road_transport_license'] as String?,
      gpsTerminalId: map['gps_terminal_id'] as String?,
      amapTerminalId: map['amap_terminal_id'] as String?,
      status: map['status'] as int?,
      remark: map['remark'] as String?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
      updateTime: map['update_time'] != null
          ? DateTime.tryParse(map['update_time'] as String)
          : null,
      isDeleted: map['is_deleted'] as int?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'vehicle_no': vehicleNo,
      'vehicle_type': vehicleType,
      'vehicle_model': vehicleModel,
      'load_weight': loadWeight,
      'load_volume': loadVolume,
      'owner_unit': ownerUnit,
      'driver_id': driverId,
      'driver_name': driverName,
      'road_transport_license': roadTransportLicense,
      'gps_terminal_id': gpsTerminalId,
      'amap_terminal_id': amapTerminalId,
      'status': status,
      'remark': remark,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  TransportVehicle copyWith({
    int? id,
    String? vehicleId,
    String? vehicleNo,
    String? vehicleType,
    String? vehicleModel,
    double? loadWeight,
    double? loadVolume,
    String? ownerUnit,
    String? driverId,
    String? driverName,
    String? roadTransportLicense,
    String? gpsTerminalId,
    String? amapTerminalId,
    int? status,
    String? remark,
    DateTime? createTime,
    DateTime? updateTime,
    int? isDeleted,
  }) {
    return TransportVehicle(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      loadWeight: loadWeight ?? this.loadWeight,
      loadVolume: loadVolume ?? this.loadVolume,
      ownerUnit: ownerUnit ?? this.ownerUnit,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      roadTransportLicense: roadTransportLicense ?? this.roadTransportLicense,
      gpsTerminalId: gpsTerminalId ?? this.gpsTerminalId,
      amapTerminalId: amapTerminalId ?? this.amapTerminalId,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
