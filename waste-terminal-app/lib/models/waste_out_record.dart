class WasteOutRecord {
  final int? id;
  final String? outNo;
  final int? transferOrderId;
  final int? containerId;
  final String? containerCode;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final double? weight;
  final int? receiverUnitId;
  final String? receiverUnitName;
  final int? transporterId;
  final String? transporterName;
  final String? vehicleNo;
  final String? driverName;
  final String? driverPhone;
  final DateTime? outTime;
  final int? operatorId;
  final String? operatorName;
  final String? remark;
  final int? status;
  final int? signStatus;
  final DateTime? signTime;
  final String? signPhoto;
  final String? receiptPhoto;
  final int? syncStatus;
  final DateTime? syncTime;
  final String? offlineId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;
  final String? faceAuthId;
  final String? faceId;
  final String? operatorFaceImage;

  WasteOutRecord({
    this.id,
    this.outNo,
    this.transferOrderId,
    this.containerId,
    this.containerCode,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.weight,
    this.receiverUnitId,
    this.receiverUnitName,
    this.transporterId,
    this.transporterName,
    this.vehicleNo,
    this.driverName,
    this.driverPhone,
    this.outTime,
    this.operatorId,
    this.operatorName,
    this.remark,
    this.status,
    this.signStatus,
    this.signTime,
    this.signPhoto,
    this.receiptPhoto,
    this.syncStatus,
    this.syncTime,
    this.offlineId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
    this.faceAuthId,
    this.faceId,
    this.operatorFaceImage,
  });

  factory WasteOutRecord.fromJson(Map<String, dynamic> json) {
    return WasteOutRecord(
      id: json['id'] as int?,
      outNo: json['outNo'] as String?,
      transferOrderId: json['transferOrderId'] as int?,
      containerId: json['containerId'] as int?,
      containerCode: json['containerCode'] as String?,
      wasteId: json['wasteId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      receiverUnitId: json['receiverUnitId'] as int?,
      receiverUnitName: json['receiverUnitName'] as String?,
      transporterId: json['transporterId'] as int?,
      transporterName: json['transporterName'] as String?,
      vehicleNo: json['vehicleNo'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      outTime: json['outTime'] != null
          ? DateTime.tryParse(json['outTime'] as String)
          : null,
      operatorId: json['operatorId'] as int?,
      operatorName: json['operatorName'] as String?,
      remark: json['remark'] as String?,
      status: json['status'] as int?,
      signStatus: json['signStatus'] as int?,
      signTime: json['signTime'] != null
          ? DateTime.tryParse(json['signTime'] as String)
          : null,
      signPhoto: json['signPhoto'] as String?,
      receiptPhoto: json['receiptPhoto'] as String?,
      syncStatus: json['syncStatus'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      offlineId: json['offlineId'] as String?,
      enterpriseId: json['enterpriseId'] as int?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      deleted: json['deleted'] as int?,
      faceAuthId: json['faceAuthId'] as String?,
      faceId: json['faceId'] as String?,
      operatorFaceImage: json['operatorFaceImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outNo': outNo,
      'transferOrderId': transferOrderId,
      'containerId': containerId,
      'containerCode': containerCode,
      'wasteId': wasteId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'weight': weight,
      'receiverUnitId': receiverUnitId,
      'receiverUnitName': receiverUnitName,
      'transporterId': transporterId,
      'transporterName': transporterName,
      'vehicleNo': vehicleNo,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'outTime': outTime?.toIso8601String(),
      'operatorId': operatorId,
      'operatorName': operatorName,
      'remark': remark,
      'status': status,
      'signStatus': signStatus,
      'signTime': signTime?.toIso8601String(),
      'signPhoto': signPhoto,
      'receiptPhoto': receiptPhoto,
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'offlineId': offlineId,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
      'faceAuthId': faceAuthId,
      'faceId': faceId,
      'operatorFaceImage': operatorFaceImage,
    };
  }

  factory WasteOutRecord.fromDbMap(Map<String, dynamic> map) {
    return WasteOutRecord(
      id: map['id'] as int?,
      outNo: map['record_no'] as String?,
      transferOrderId: map['transfer_order_id'] as int?,
      containerId: map['container_id'] as int?,
      containerCode: map['container_code'] as String?,
      wasteId: map['waste_id'] as int?,
      wasteCode: map['waste_code'] as String?,
      wasteName: map['waste_name'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      receiverUnitId: map['receiver_id'] as int?,
      receiverUnitName: map['receiver'] as String?,
      transporterId: map['transporter_id'] as int?,
      transporterName: map['transporter'] as String?,
      vehicleNo: map['vehicle_no'] as String?,
      driverName: map['driver_name'] as String?,
      driverPhone: map['driver_phone'] as String?,
      outTime: map['out_time'] != null
          ? DateTime.tryParse(map['out_time'] as String)
          : null,
      operatorId: map['operator_id'] as int?,
      operatorName: map['operator'] as String?,
      remark: map['remark'] as String?,
      status: map['status'] as int?,
      signStatus: map['sign_status'] as int?,
      signTime: map['sign_time'] != null
          ? DateTime.tryParse(map['sign_time'] as String)
          : null,
      signPhoto: map['sign_photo'] as String?,
      receiptPhoto: map['receipt_photo'] as String?,
      syncStatus: map['sync_status'] as int?,
      syncTime: map['sync_time'] != null
          ? DateTime.tryParse(map['sync_time'] as String)
          : null,
      offlineId: map['offline_id'] as String?,
      enterpriseId: map['enterprise_id'] as int?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
      updateTime: map['update_time'] != null
          ? DateTime.tryParse(map['update_time'] as String)
          : null,
      deleted: map['is_deleted'] as int?,
      faceAuthId: map['face_auth_id'] as String?,
      faceId: map['face_id'] as String?,
      operatorFaceImage: map['operator_face_image'] as String?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'record_no': outNo,
      'transfer_order_id': transferOrderId,
      'container_id': containerId,
      'container_code': containerCode,
      'waste_id': wasteId,
      'waste_code': wasteCode,
      'waste_name': wasteName,
      'weight': weight,
      'receiver_id': receiverUnitId,
      'receiver': receiverUnitName,
      'transporter_id': transporterId,
      'transporter': transporterName,
      'vehicle_no': vehicleNo,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'out_time': outTime?.toIso8601String(),
      'operator_id': operatorId,
      'operator': operatorName,
      'remark': remark,
      'status': status,
      'sign_status': signStatus,
      'sign_time': signTime?.toIso8601String(),
      'sign_photo': signPhoto,
      'receipt_photo': receiptPhoto,
      'sync_status': syncStatus,
      'sync_time': syncTime?.toIso8601String(),
      'offline_id': offlineId,
      'enterprise_id': enterpriseId,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': deleted,
      'face_auth_id': faceAuthId,
      'face_id': faceId,
      'operator_face_image': operatorFaceImage,
    };
  }

  WasteOutRecord copyWith({
    int? id,
    String? outNo,
    int? transferOrderId,
    int? containerId,
    String? containerCode,
    int? wasteId,
    String? wasteCode,
    String? wasteName,
    double? weight,
    int? receiverUnitId,
    String? receiverUnitName,
    int? transporterId,
    String? transporterName,
    String? vehicleNo,
    String? driverName,
    String? driverPhone,
    DateTime? outTime,
    int? operatorId,
    String? operatorName,
    String? remark,
    int? status,
    int? signStatus,
    DateTime? signTime,
    String? signPhoto,
    String? receiptPhoto,
    int? syncStatus,
    DateTime? syncTime,
    String? offlineId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
    String? faceAuthId,
    String? faceId,
    String? operatorFaceImage,
  }) {
    return WasteOutRecord(
      id: id ?? this.id,
      outNo: outNo ?? this.outNo,
      transferOrderId: transferOrderId ?? this.transferOrderId,
      containerId: containerId ?? this.containerId,
      containerCode: containerCode ?? this.containerCode,
      wasteId: wasteId ?? this.wasteId,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      weight: weight ?? this.weight,
      receiverUnitId: receiverUnitId ?? this.receiverUnitId,
      receiverUnitName: receiverUnitName ?? this.receiverUnitName,
      transporterId: transporterId ?? this.transporterId,
      transporterName: transporterName ?? this.transporterName,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      outTime: outTime ?? this.outTime,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      remark: remark ?? this.remark,
      status: status ?? this.status,
      signStatus: signStatus ?? this.signStatus,
      signTime: signTime ?? this.signTime,
      signPhoto: signPhoto ?? this.signPhoto,
      receiptPhoto: receiptPhoto ?? this.receiptPhoto,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      offlineId: offlineId ?? this.offlineId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
      faceAuthId: faceAuthId ?? this.faceAuthId,
      faceId: faceId ?? this.faceId,
      operatorFaceImage: operatorFaceImage ?? this.operatorFaceImage,
    );
  }
}
