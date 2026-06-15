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
