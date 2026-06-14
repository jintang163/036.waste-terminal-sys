class WasteCatalog {
  final int? id;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final String? wasteType;
  final String? hazardCode;
  final String? disposalMethod;
  final String? storageRequirement;
  final String? safetyMeasures;
  final String? description;
  final int? sortOrder;
  final int? status;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  WasteCatalog({
    this.id,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.wasteType,
    this.hazardCode,
    this.disposalMethod,
    this.storageRequirement,
    this.safetyMeasures,
    this.description,
    this.sortOrder,
    this.status,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory WasteCatalog.fromJson(Map<String, dynamic> json) {
    return WasteCatalog(
      id: json['id'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      wasteCategory: json['wasteCategory'] as String?,
      wasteType: json['wasteType'] as String?,
      hazardCode: json['hazardCode'] as String?,
      disposalMethod: json['disposalMethod'] as String?,
      storageRequirement: json['storageRequirement'] as String?,
      safetyMeasures: json['safetyMeasures'] as String?,
      description: json['description'] as String?,
      sortOrder: json['sortOrder'] as int?,
      status: json['status'] as int?,
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
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'wasteCategory': wasteCategory,
      'wasteType': wasteType,
      'hazardCode': hazardCode,
      'disposalMethod': disposalMethod,
      'storageRequirement': storageRequirement,
      'safetyMeasures': safetyMeasures,
      'description': description,
      'sortOrder': sortOrder,
      'status': status,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  WasteCatalog copyWith({
    int? id,
    String? wasteCode,
    String? wasteName,
    String? wasteCategory,
    String? wasteType,
    String? hazardCode,
    String? disposalMethod,
    String? storageRequirement,
    String? safetyMeasures,
    String? description,
    int? sortOrder,
    int? status,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return WasteCatalog(
      id: id ?? this.id,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      wasteType: wasteType ?? this.wasteType,
      hazardCode: hazardCode ?? this.hazardCode,
      disposalMethod: disposalMethod ?? this.disposalMethod,
      storageRequirement: storageRequirement ?? this.storageRequirement,
      safetyMeasures: safetyMeasures ?? this.safetyMeasures,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      status: status ?? this.status,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
