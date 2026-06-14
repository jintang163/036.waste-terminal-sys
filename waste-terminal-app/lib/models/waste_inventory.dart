class WasteInventory {
  final int? id;
  final int? containerId;
  final String? containerCode;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final String? hazardCode;
  final double? weight;
  final double? inWeight;
  final double? outWeight;
  final int? storageDays;
  final int? storageLimit;
  final DateTime? produceDate;
  final DateTime? inDate;
  final String? storageLocation;
  final int? warnStatus;
  final int? status;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  WasteInventory({
    this.id,
    this.containerId,
    this.containerCode,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.hazardCode,
    this.weight,
    this.inWeight,
    this.outWeight,
    this.storageDays,
    this.storageLimit,
    this.produceDate,
    this.inDate,
    this.storageLocation,
    this.warnStatus,
    this.status,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory WasteInventory.fromJson(Map<String, dynamic> json) {
    return WasteInventory(
      id: json['id'] as int?,
      containerId: json['containerId'] as int?,
      containerCode: json['containerCode'] as String?,
      wasteId: json['wasteId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      wasteCategory: json['wasteCategory'] as String?,
      hazardCode: json['hazardCode'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      inWeight: (json['inWeight'] as num?)?.toDouble(),
      outWeight: (json['outWeight'] as num?)?.toDouble(),
      storageDays: json['storageDays'] as int?,
      storageLimit: json['storageLimit'] as int?,
      produceDate: json['produceDate'] != null
          ? DateTime.tryParse(json['produceDate'] as String)
          : null,
      inDate: json['inDate'] != null
          ? DateTime.tryParse(json['inDate'] as String)
          : null,
      storageLocation: json['storageLocation'] as String?,
      warnStatus: json['warnStatus'] as int?,
      status: json['status'] as int?,
      enterpriseId: json['enterpriseId'] as int?,
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
      'containerId': containerId,
      'containerCode': containerCode,
      'wasteId': wasteId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'wasteCategory': wasteCategory,
      'hazardCode': hazardCode,
      'weight': weight,
      'inWeight': inWeight,
      'outWeight': outWeight,
      'storageDays': storageDays,
      'storageLimit': storageLimit,
      'produceDate': produceDate?.toIso8601String(),
      'inDate': inDate?.toIso8601String(),
      'storageLocation': storageLocation,
      'warnStatus': warnStatus,
      'status': status,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  WasteInventory copyWith({
    int? id,
    int? containerId,
    String? containerCode,
    int? wasteId,
    String? wasteCode,
    String? wasteName,
    String? wasteCategory,
    String? hazardCode,
    double? weight,
    double? inWeight,
    double? outWeight,
    int? storageDays,
    int? storageLimit,
    DateTime? produceDate,
    DateTime? inDate,
    String? storageLocation,
    int? warnStatus,
    int? status,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return WasteInventory(
      id: id ?? this.id,
      containerId: containerId ?? this.containerId,
      containerCode: containerCode ?? this.containerCode,
      wasteId: wasteId ?? this.wasteId,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      hazardCode: hazardCode ?? this.hazardCode,
      weight: weight ?? this.weight,
      inWeight: inWeight ?? this.inWeight,
      outWeight: outWeight ?? this.outWeight,
      storageDays: storageDays ?? this.storageDays,
      storageLimit: storageLimit ?? this.storageLimit,
      produceDate: produceDate ?? this.produceDate,
      inDate: inDate ?? this.inDate,
      storageLocation: storageLocation ?? this.storageLocation,
      warnStatus: warnStatus ?? this.warnStatus,
      status: status ?? this.status,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
