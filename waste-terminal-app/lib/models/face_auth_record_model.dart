class FaceAuthRecordModel {
  final int? id;
  final String? authId;
  final int? userId;
  final String? username;
  final String? realName;
  final String? faceId;
  final double? similarity;
  final int? authStatus;
  final String? authType;
  final String? businessType;
  final String? businessId;
  final String? businessNo;
  final String? deviceId;
  final String? ip;
  final DateTime? authTime;
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
    this.authStatus,
    this.authType,
    this.businessType,
    this.businessId,
    this.businessNo,
    this.deviceId,
    this.ip,
    this.authTime,
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
      'authStatus': authStatus,
      'authType': authType,
      'businessType': businessType,
      'businessId': businessId,
      'businessNo': businessNo,
      'deviceId': deviceId,
      'ip': ip,
      'authTime': authTime?.toIso8601String(),
      'enterpriseId': enterpriseId,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  FaceAuthRecordModel copyWith({
    int? id,
    String? authId,
    int? userId,
    String? username,
    String? realName,
    String? faceId,
    double? similarity,
    int? authStatus,
    String? authType,
    String? businessType,
    String? businessId,
    String? businessNo,
    String? deviceId,
    String? ip,
    DateTime? authTime,
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
      authStatus: authStatus ?? this.authStatus,
      authType: authType ?? this.authType,
      businessType: businessType ?? this.businessType,
      businessId: businessId ?? this.businessId,
      businessNo: businessNo ?? this.businessNo,
      deviceId: deviceId ?? this.deviceId,
      ip: ip ?? this.ip,
      authTime: authTime ?? this.authTime,
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
