class SyncRecord {
  final int? id;
  final String? syncNo;
  final String? syncType;
  final String? syncDirection;
  final String? deviceId;
  final int? totalCount;
  final int? successCount;
  final int? failCount;
  final DateTime? syncTime;
  final int? syncDuration;
  final int? status;
  final String? failReason;
  final int? operatorId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  SyncRecord({
    this.id,
    this.syncNo,
    this.syncType,
    this.syncDirection,
    this.deviceId,
    this.totalCount,
    this.successCount,
    this.failCount,
    this.syncTime,
    this.syncDuration,
    this.status,
    this.failReason,
    this.operatorId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    return SyncRecord(
      id: json['id'] as int?,
      syncNo: json['syncNo'] as String?,
      syncType: json['syncType'] as String?,
      syncDirection: json['syncDirection'] as String?,
      deviceId: json['deviceId'] as String?,
      totalCount: json['totalCount'] as int?,
      successCount: json['successCount'] as int?,
      failCount: json['failCount'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      syncDuration: json['syncDuration'] as int?,
      status: json['status'] as int?,
      failReason: json['failReason'] as String?,
      operatorId: json['operatorId'] as int?,
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
      'syncNo': syncNo,
      'syncType': syncType,
      'syncDirection': syncDirection,
      'deviceId': deviceId,
      'totalCount': totalCount,
      'successCount': successCount,
      'failCount': failCount,
      'syncTime': syncTime?.toIso8601String(),
      'syncDuration': syncDuration,
      'status': status,
      'failReason': failReason,
      'operatorId': operatorId,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  SyncRecord copyWith({
    int? id,
    String? syncNo,
    String? syncType,
    String? syncDirection,
    String? deviceId,
    int? totalCount,
    int? successCount,
    int? failCount,
    DateTime? syncTime,
    int? syncDuration,
    int? status,
    String? failReason,
    int? operatorId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return SyncRecord(
      id: id ?? this.id,
      syncNo: syncNo ?? this.syncNo,
      syncType: syncType ?? this.syncType,
      syncDirection: syncDirection ?? this.syncDirection,
      deviceId: deviceId ?? this.deviceId,
      totalCount: totalCount ?? this.totalCount,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      syncTime: syncTime ?? this.syncTime,
      syncDuration: syncDuration ?? this.syncDuration,
      status: status ?? this.status,
      failReason: failReason ?? this.failReason,
      operatorId: operatorId ?? this.operatorId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
