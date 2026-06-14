class InventoryCheckDetail {
  final int? id;
  final int? checkId;
  final int? containerId;
  final String? containerCode;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final double? inventoryWeight;
  final double? checkWeight;
  final double? diffWeight;
  final String? diffType;
  final int? isFound;
  final DateTime? checkTime;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  InventoryCheckDetail({
    this.id,
    this.checkId,
    this.containerId,
    this.containerCode,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.inventoryWeight,
    this.checkWeight,
    this.diffWeight,
    this.diffType,
    this.isFound,
    this.checkTime,
    this.remark,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory InventoryCheckDetail.fromJson(Map<String, dynamic> json) {
    return InventoryCheckDetail(
      id: json['id'] as int?,
      checkId: json['checkId'] as int?,
      containerId: json['containerId'] as int?,
      containerCode: json['containerCode'] as String?,
      wasteId: json['wasteId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      inventoryWeight: (json['inventoryWeight'] as num?)?.toDouble(),
      checkWeight: (json['checkWeight'] as num?)?.toDouble(),
      diffWeight: (json['diffWeight'] as num?)?.toDouble(),
      diffType: json['diffType'] as String?,
      isFound: json['isFound'] as int?,
      checkTime: json['checkTime'] != null
          ? DateTime.tryParse(json['checkTime'] as String)
          : null,
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
      'checkId': checkId,
      'containerId': containerId,
      'containerCode': containerCode,
      'wasteId': wasteId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'inventoryWeight': inventoryWeight,
      'checkWeight': checkWeight,
      'diffWeight': diffWeight,
      'diffType': diffType,
      'isFound': isFound,
      'checkTime': checkTime?.toIso8601String(),
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }
}

class InventoryCheck {
  final int? id;
  final String? checkNo;
  final String? checkName;
  final String? checkType;
  final DateTime? checkDate;
  final int? totalContainers;
  final int? checkedContainers;
  final int? missingContainers;
  final int? extraContainers;
  final double? diffWeight;
  final List<InventoryCheckDetail>? details;
  final int? status;
  final int? auditStatus;
  final int? auditUserId;
  final DateTime? auditTime;
  final String? auditRemark;
  final int? operatorId;
  final String? operatorName;
  final String? remark;
  final int? syncStatus;
  final String? offlineId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  InventoryCheck({
    this.id,
    this.checkNo,
    this.checkName,
    this.checkType,
    this.checkDate,
    this.totalContainers,
    this.checkedContainers,
    this.missingContainers,
    this.extraContainers,
    this.diffWeight,
    this.details,
    this.status,
    this.auditStatus,
    this.auditUserId,
    this.auditTime,
    this.auditRemark,
    this.operatorId,
    this.operatorName,
    this.remark,
    this.syncStatus,
    this.offlineId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory InventoryCheck.fromJson(Map<String, dynamic> json) {
    final detailsJson = json['details'] as List<dynamic>?;
    return InventoryCheck(
      id: json['id'] as int?,
      checkNo: json['checkNo'] as String?,
      checkName: json['checkName'] as String?,
      checkType: json['checkType'] as String?,
      checkDate: json['checkDate'] != null
          ? DateTime.tryParse(json['checkDate'] as String)
          : null,
      totalContainers: json['totalContainers'] as int?,
      checkedContainers: json['checkedContainers'] as int?,
      missingContainers: json['missingContainers'] as int?,
      extraContainers: json['extraContainers'] as int?,
      diffWeight: (json['diffWeight'] as num?)?.toDouble(),
      details: detailsJson
          ?.map((e) => InventoryCheckDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as int?,
      auditStatus: json['auditStatus'] as int?,
      auditUserId: json['auditUserId'] as int?,
      auditTime: json['auditTime'] != null
          ? DateTime.tryParse(json['auditTime'] as String)
          : null,
      auditRemark: json['auditRemark'] as String?,
      operatorId: json['operatorId'] as int?,
      operatorName: json['operatorName'] as String?,
      remark: json['remark'] as String?,
      syncStatus: json['syncStatus'] as int?,
      offlineId: json['offlineId'] as String?,
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
      'checkNo': checkNo,
      'checkName': checkName,
      'checkType': checkType,
      'checkDate': checkDate?.toIso8601String(),
      'totalContainers': totalContainers,
      'checkedContainers': checkedContainers,
      'missingContainers': missingContainers,
      'extraContainers': extraContainers,
      'diffWeight': diffWeight,
      'details': details?.map((e) => e.toJson()).toList(),
      'status': status,
      'auditStatus': auditStatus,
      'auditUserId': auditUserId,
      'auditTime': auditTime?.toIso8601String(),
      'auditRemark': auditRemark,
      'operatorId': operatorId,
      'operatorName': operatorName,
      'remark': remark,
      'syncStatus': syncStatus,
      'offlineId': offlineId,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  InventoryCheck copyWith({
    int? id,
    String? checkNo,
    String? checkName,
    String? checkType,
    DateTime? checkDate,
    int? totalContainers,
    int? checkedContainers,
    int? missingContainers,
    int? extraContainers,
    double? diffWeight,
    List<InventoryCheckDetail>? details,
    int? status,
    int? auditStatus,
    int? auditUserId,
    DateTime? auditTime,
    String? auditRemark,
    int? operatorId,
    String? operatorName,
    String? remark,
    int? syncStatus,
    String? offlineId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return InventoryCheck(
      id: id ?? this.id,
      checkNo: checkNo ?? this.checkNo,
      checkName: checkName ?? this.checkName,
      checkType: checkType ?? this.checkType,
      checkDate: checkDate ?? this.checkDate,
      totalContainers: totalContainers ?? this.totalContainers,
      checkedContainers: checkedContainers ?? this.checkedContainers,
      missingContainers: missingContainers ?? this.missingContainers,
      extraContainers: extraContainers ?? this.extraContainers,
      diffWeight: diffWeight ?? this.diffWeight,
      details: details ?? this.details,
      status: status ?? this.status,
      auditStatus: auditStatus ?? this.auditStatus,
      auditUserId: auditUserId ?? this.auditUserId,
      auditTime: auditTime ?? this.auditTime,
      auditRemark: auditRemark ?? this.auditRemark,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      remark: remark ?? this.remark,
      syncStatus: syncStatus ?? this.syncStatus,
      offlineId: offlineId ?? this.offlineId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
