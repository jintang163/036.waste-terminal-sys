class WarningRecord {
  final int? id;
  final String? warningNo;
  final String? warningType;
  final int? warningLevel;
  final String? wasteCode;
  final String? wasteName;
  final int? containerId;
  final String? containerCode;
  final String? warningContent;
  final DateTime? triggerTime;
  final int? handleStatus;
  final int? handleUserId;
  final DateTime? handleTime;
  final String? handleRemark;
  final int? pushStatus;
  final DateTime? pushTime;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  WarningRecord({
    this.id,
    this.warningNo,
    this.warningType,
    this.warningLevel,
    this.wasteCode,
    this.wasteName,
    this.containerId,
    this.containerCode,
    this.warningContent,
    this.triggerTime,
    this.handleStatus,
    this.handleUserId,
    this.handleTime,
    this.handleRemark,
    this.pushStatus,
    this.pushTime,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory WarningRecord.fromJson(Map<String, dynamic> json) {
    return WarningRecord(
      id: json['id'] as int?,
      warningNo: json['warningNo'] as String?,
      warningType: json['warningType'] as String?,
      warningLevel: json['warningLevel'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      containerId: json['containerId'] as int?,
      containerCode: json['containerCode'] as String?,
      warningContent: json['warningContent'] as String?,
      triggerTime: json['triggerTime'] != null
          ? DateTime.tryParse(json['triggerTime'] as String)
          : null,
      handleStatus: json['handleStatus'] as int?,
      handleUserId: json['handleUserId'] as int?,
      handleTime: json['handleTime'] != null
          ? DateTime.tryParse(json['handleTime'] as String)
          : null,
      handleRemark: json['handleRemark'] as String?,
      pushStatus: json['pushStatus'] as int?,
      pushTime: json['pushTime'] != null
          ? DateTime.tryParse(json['pushTime'] as String)
          : null,
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
      'warningNo': warningNo,
      'warningType': warningType,
      'warningLevel': warningLevel,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'containerId': containerId,
      'containerCode': containerCode,
      'warningContent': warningContent,
      'triggerTime': triggerTime?.toIso8601String(),
      'handleStatus': handleStatus,
      'handleUserId': handleUserId,
      'handleTime': handleTime?.toIso8601String(),
      'handleRemark': handleRemark,
      'pushStatus': pushStatus,
      'pushTime': pushTime?.toIso8601String(),
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  WarningRecord copyWith({
    int? id,
    String? warningNo,
    String? warningType,
    int? warningLevel,
    String? wasteCode,
    String? wasteName,
    int? containerId,
    String? containerCode,
    String? warningContent,
    DateTime? triggerTime,
    int? handleStatus,
    int? handleUserId,
    DateTime? handleTime,
    String? handleRemark,
    int? pushStatus,
    DateTime? pushTime,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return WarningRecord(
      id: id ?? this.id,
      warningNo: warningNo ?? this.warningNo,
      warningType: warningType ?? this.warningType,
      warningLevel: warningLevel ?? this.warningLevel,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      containerId: containerId ?? this.containerId,
      containerCode: containerCode ?? this.containerCode,
      warningContent: warningContent ?? this.warningContent,
      triggerTime: triggerTime ?? this.triggerTime,
      handleStatus: handleStatus ?? this.handleStatus,
      handleUserId: handleUserId ?? this.handleUserId,
      handleTime: handleTime ?? this.handleTime,
      handleRemark: handleRemark ?? this.handleRemark,
      pushStatus: pushStatus ?? this.pushStatus,
      pushTime: pushTime ?? this.pushTime,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
