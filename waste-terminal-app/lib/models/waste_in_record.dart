class WasteInRecord {
  final int? id;
  final String? inNo;
  final int? containerId;
  final String? containerCode;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final String? hazardCode;
  final double? weight;
  final String? weightSource;
  final String? scaleDevice;
  final DateTime? produceDate;
  final String? produceDepartment;
  final String? storageLocation;
  final int? operatorId;
  final String? operatorName;
  final String? photos;
  final String? remark;
  final int? status;
  final int? syncStatus;
  final DateTime? syncTime;
  final String? syncFailReason;
  final String? offlineId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;
  final String? faceAuthId;
  final String? faceId;
  final String? operatorFaceImage;

  WasteInRecord({
    this.id,
    this.inNo,
    this.containerId,
    this.containerCode,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.hazardCode,
    this.weight,
    this.weightSource,
    this.scaleDevice,
    this.produceDate,
    this.produceDepartment,
    this.storageLocation,
    this.operatorId,
    this.operatorName,
    this.photos,
    this.remark,
    this.status,
    this.syncStatus,
    this.syncTime,
    this.syncFailReason,
    this.offlineId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
    this.faceAuthId,
    this.faceId,
    this.operatorFaceImage,
  });

  factory WasteInRecord.fromJson(Map<String, dynamic> json) {
    return WasteInRecord(
      id: json['id'] as int?,
      inNo: json['inNo'] as String?,
      containerId: json['containerId'] as int?,
      containerCode: json['containerCode'] as String?,
      wasteId: json['wasteId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      wasteCategory: json['wasteCategory'] as String?,
      hazardCode: json['hazardCode'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      weightSource: json['weightSource'] as String?,
      scaleDevice: json['scaleDevice'] as String?,
      produceDate: json['produceDate'] != null
          ? DateTime.tryParse(json['produceDate'] as String)
          : null,
      produceDepartment: json['produceDepartment'] as String?,
      storageLocation: json['storageLocation'] as String?,
      operatorId: json['operatorId'] as int?,
      operatorName: json['operatorName'] as String?,
      photos: json['photos'] as String?,
      remark: json['remark'] as String?,
      status: json['status'] as int?,
      syncStatus: json['syncStatus'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      syncFailReason: json['syncFailReason'] as String?,
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
      'inNo': inNo,
      'containerId': containerId,
      'containerCode': containerCode,
      'wasteId': wasteId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'wasteCategory': wasteCategory,
      'hazardCode': hazardCode,
      'weight': weight,
      'weightSource': weightSource,
      'scaleDevice': scaleDevice,
      'produceDate': produceDate?.toIso8601String(),
      'produceDepartment': produceDepartment,
      'storageLocation': storageLocation,
      'operatorId': operatorId,
      'operatorName': operatorName,
      'photos': photos,
      'remark': remark,
      'status': status,
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'syncFailReason': syncFailReason,
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

  factory WasteInRecord.fromDbMap(Map<String, dynamic> map) {
    return WasteInRecord(
      id: map['id'] as int?,
      inNo: map['record_no'] as String?,
      containerId: map['container_id'] as int?,
      containerCode: map['container_code'] as String?,
      wasteId: map['waste_id'] as int?,
      wasteCode: map['waste_code'] as String?,
      wasteName: map['waste_name'] as String?,
      wasteCategory: map['waste_category'] as String?,
      hazardCode: map['hazard_code'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      weightSource: map['weight_source'] as String?,
      scaleDevice: map['scale_device'] as String?,
      produceDate: map['produce_date'] != null
          ? DateTime.tryParse(map['produce_date'] as String)
          : null,
      produceDepartment: map['produce_department'] as String?,
      storageLocation: map['warehouse'] as String?,
      operatorId: map['operator_id'] as int?,
      operatorName: map['operator'] as String?,
      photos: map['photos'] as String?,
      remark: map['remark'] as String?,
      status: map['status'] as int?,
      syncStatus: map['sync_status'] as int?,
      syncTime: map['sync_time'] != null
          ? DateTime.tryParse(map['sync_time'] as String)
          : null,
      syncFailReason: map['sync_fail_reason'] as String?,
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
      'record_no': inNo,
      'container_id': containerId,
      'container_code': containerCode,
      'waste_id': wasteId,
      'waste_code': wasteCode,
      'waste_name': wasteName,
      'waste_category': wasteCategory,
      'hazard_code': hazardCode,
      'weight': weight,
      'weight_source': weightSource,
      'weight_unit': 'kg',
      'scale_device': scaleDevice,
      'produce_date': produceDate?.toIso8601String(),
      'produce_department': produceDepartment,
      'warehouse': storageLocation,
      'operator_id': operatorId,
      'operator': operatorName,
      'source': weightSource ?? 'manual',
      'in_time': createTime?.toIso8601String(),
      'photos': photos,
      'remark': remark,
      'status': status ?? 1,
      'sync_status': syncStatus ?? 0,
      'sync_time': syncTime?.toIso8601String(),
      'sync_fail_reason': syncFailReason,
      'offline_id': offlineId,
      'enterprise_id': enterpriseId,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': deleted ?? 0,
      'face_auth_id': faceAuthId,
      'face_id': faceId,
      'operator_face_image': operatorFaceImage,
    };
  }

  WasteInRecord copyWith({
    int? id,
    String? inNo,
    int? containerId,
    String? containerCode,
    int? wasteId,
    String? wasteCode,
    String? wasteName,
    String? wasteCategory,
    String? hazardCode,
    double? weight,
    String? weightSource,
    String? scaleDevice,
    DateTime? produceDate,
    String? produceDepartment,
    String? storageLocation,
    int? operatorId,
    String? operatorName,
    String? photos,
    String? remark,
    int? status,
    int? syncStatus,
    DateTime? syncTime,
    String? syncFailReason,
    String? offlineId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
    String? faceAuthId,
    String? faceId,
    String? operatorFaceImage,
  }) {
    return WasteInRecord(
      id: id ?? this.id,
      inNo: inNo ?? this.inNo,
      containerId: containerId ?? this.containerId,
      containerCode: containerCode ?? this.containerCode,
      wasteId: wasteId ?? this.wasteId,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      hazardCode: hazardCode ?? this.hazardCode,
      weight: weight ?? this.weight,
      weightSource: weightSource ?? this.weightSource,
      scaleDevice: scaleDevice ?? this.scaleDevice,
      produceDate: produceDate ?? this.produceDate,
      produceDepartment: produceDepartment ?? this.produceDepartment,
      storageLocation: storageLocation ?? this.storageLocation,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      photos: photos ?? this.photos,
      remark: remark ?? this.remark,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      syncFailReason: syncFailReason ?? this.syncFailReason,
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
