class FaceAuthRecordModel {
  final int? id;
  final String? authId;
  final int? userId;
  final String? username;
  final String? realName;
  final String? faceId;
  final double? similarity;
  final double? livenessScore;
  final int? faceQuality;
  final int? authStatus;
  final String? authType;
  final String? businessType;
  final String? businessId;
  final String? businessNo;
  final String? deviceId;
  final String? ip;
  final DateTime? authTime;
  final int? syncStatus;
  final DateTime? syncTime;
  final int? enterpriseId;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;

  FaceAuthRecordModel({
    this.id,
    this.authId,
    this.userId,
    this.username,
    this.realName,
    this.faceId,
    this.similarity,
    this.livenessScore,
    this.faceQuality,
    this.authStatus,
    this.authType,
    this.businessType,
    this.businessId,
    this.businessNo,
    this.deviceId,
    this.ip,
    this.authTime,
    this.syncStatus,
    this.syncTime,
    this.enterpriseId,
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory FaceAuthRecordModel.fromJson(Map<String, dynamic> json) {
    return FaceAuthRecordModel(
      id: json['id'] as int?,
      authId: json['authId'] as String?,
      userId: json['userId'] as int?,
      username: json['username'] as String?,
      realName: json['realName'] as String?,
      faceId: json['faceId'] as String?,
      similarity: (json['similarity'] as num?)?.toDouble(),
      livenessScore: (json['livenessScore'] as num?)?.toDouble(),
      faceQuality: json['faceQuality'] as int?,
      authStatus: json['authStatus'] as int?,
      authType: json['authType'] as String?,
      businessType: json['businessType'] as String?,
      businessId: json['businessId'] as String?,
      businessNo: json['businessNo'] as String?,
      deviceId: json['deviceId'] as String?,
      ip: json['ip'] as String?,
      authTime: json['authTime'] != null
          ? DateTime.tryParse(json['authTime'] as String)
          : null,
      syncStatus: json['syncStatus'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      enterpriseId: json['enterpriseId'] as int?,
      remark: json['remark'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authId': authId,
      'userId': userId,
      'username': username,
      'realName': realName,
      'faceId': faceId,
      'similarity': similarity,
      'livenessScore': livenessScore,
      'faceQuality': faceQuality,
      'authStatus': authStatus,
      'authType': authType,
      'businessType': businessType,
      'businessId': businessId,
      'businessNo': businessNo,
      'deviceId': deviceId,
      'ip': ip,
      'authTime': authTime?.toIso8601String(),
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'enterpriseId': enterpriseId,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'auth_id': authId,
      'user_id': userId,
      'username': username,
      'real_name': realName,
      'face_id': faceId,
      'similarity': similarity,
      'liveness_score': livenessScore,
      'face_quality': faceQuality,
      'auth_status': authStatus,
      'auth_type': authType,
      'business_type': businessType,
      'business_id': businessId,
      'business_no': businessNo,
      'device_id': deviceId,
      'ip': ip,
      'auth_time': authTime?.toIso8601String(),
      'sync_status': syncStatus ?? 0,
      'sync_time': syncTime?.toIso8601String(),
      'enterprise_id': enterpriseId,
      'remark': remark,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
    };
  }

  factory FaceAuthRecordModel.fromDbMap(Map<String, dynamic> map) {
    return FaceAuthRecordModel(
      id: map['id'] as int?,
      authId: map['auth_id'] as String?,
      userId: map['user_id'] as int?,
      username: map['username'] as String?,
      realName: map['real_name'] as String?,
      faceId: map['face_id'] as String?,
      similarity: (map['similarity'] as num?)?.toDouble(),
      livenessScore: (map['liveness_score'] as num?)?.toDouble(),
      faceQuality: map['face_quality'] as int?,
      authStatus: map['auth_status'] as int?,
      authType: map['auth_type'] as String?,
      businessType: map['business_type'] as String?,
      businessId: map['business_id'] as String?,
      businessNo: map['business_no'] as String?,
      deviceId: map['device_id'] as String?,
      ip: map['ip'] as String?,
      authTime: map['auth_time'] != null
          ? DateTime.tryParse(map['auth_time'] as String)
          : null,
      syncStatus: map['sync_status'] as int?,
      syncTime: map['sync_time'] != null
          ? DateTime.tryParse(map['sync_time'] as String)
          : null,
      enterpriseId: map['enterprise_id'] as int?,
      remark: map['remark'] as String?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
      updateTime: map['update_time'] != null
          ? DateTime.tryParse(map['update_time'] as String)
          : null,
    );
  }

  FaceAuthRecordModel copyWith({
    int? id,
    String? authId,
    int? userId,
    String? username,
    String? realName,
    String? faceId,
    double? similarity,
    double? livenessScore,
    int? faceQuality,
    int? authStatus,
    String? authType,
    String? businessType,
    String? businessId,
    String? businessNo,
    String? deviceId,
    String? ip,
    DateTime? authTime,
    int? syncStatus,
    DateTime? syncTime,
    int? enterpriseId,
    String? remark,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return FaceAuthRecordModel(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      realName: realName ?? this.realName,
      faceId: faceId ?? this.faceId,
      similarity: similarity ?? this.similarity,
      livenessScore: livenessScore ?? this.livenessScore,
      faceQuality: faceQuality ?? this.faceQuality,
      authStatus: authStatus ?? this.authStatus,
      authType: authType ?? this.authType,
      businessType: businessType ?? this.businessType,
      businessId: businessId ?? this.businessId,
      businessNo: businessNo ?? this.businessNo,
      deviceId: deviceId ?? this.deviceId,
      ip: ip ?? this.ip,
      authTime: authTime ?? this.authTime,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      remark: remark ?? this.remark,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  String get authTypeText {
    switch (authType) {
      case 'login':
        return '登录';
      case 'verify':
        return '操作验证';
      default:
        return '未知';
    }
  }

  String get authStatusText {
    switch (authStatus) {
      case 0:
        return '失败';
      case 1:
        return '成功';
      default:
        return '未知';
    }
  }

  bool get isSuccess => authStatus == 1;

  String get similarityText {
    if (similarity == null) return '-';
    return '${(similarity! * 100).toStringAsFixed(1)}%';
  }
}
