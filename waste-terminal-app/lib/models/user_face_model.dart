class UserFaceModel {
  final int? id;
  final int? userId;
  final String? username;
  final String? faceId;
  final String? faceFeature;
  final String? faceImage;
  final int? status;
  final int? enrollQuality;
  final String? deviceId;
  final int? enterpriseId;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;

  UserFaceModel({
    this.id,
    this.userId,
    this.username,
    this.faceId,
    this.faceFeature,
    this.faceImage,
    this.status,
    this.enrollQuality,
    this.deviceId,
    this.enterpriseId,
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory UserFaceModel.fromJson(Map<String, dynamic> json) {
    return UserFaceModel(
      id: json['id'] as int?,
      userId: json['userId'] as int?,
      username: json['username'] as String?,
      faceId: json['faceId'] as String?,
      faceFeature: json['faceFeature'] as String?,
      faceImage: json['faceImage'] as String?,
      status: json['status'] as int?,
      enrollQuality: json['enrollQuality'] as int?,
      deviceId: json['deviceId'] as String?,
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
      'userId': userId,
      'username': username,
      'faceId': faceId,
      'faceFeature': faceFeature,
      'faceImage': faceImage,
      'status': status,
      'enrollQuality': enrollQuality,
      'deviceId': deviceId,
      'enterpriseId': enterpriseId,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  UserFaceModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? faceId,
    String? faceFeature,
    String? faceImage,
    int? status,
    int? enrollQuality,
    String? deviceId,
    int? enterpriseId,
    String? remark,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return UserFaceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      faceId: faceId ?? this.faceId,
      faceFeature: faceFeature ?? this.faceFeature,
      faceImage: faceImage ?? this.faceImage,
      status: status ?? this.status,
      enrollQuality: enrollQuality ?? this.enrollQuality,
      deviceId: deviceId ?? this.deviceId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      remark: remark ?? this.remark,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  String get statusText {
    switch (status) {
      case 0:
        return '禁用';
      case 1:
        return '启用';
      default:
        return '未知';
    }
  }

  bool get isEnabled => status == 1;
}
