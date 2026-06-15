class CameraModel {
  final int? id;
  final String? cameraCode;
  final String? cameraName;
  final String? cameraType;
  final String? brand;
  final String? rtspUrl;
  final String? httpUrl;
  final String? location;
  final String? warehouseCode;
  final int? status;
  final bool? aiEnabled;
  final String? aiTaskId;
  final String? snapshotUrl;
  final String? resolution;
  final int? streamType;
  final String? username;
  final String? password;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;

  CameraModel({
    this.id,
    this.cameraCode,
    this.cameraName,
    this.cameraType,
    this.brand,
    this.rtspUrl,
    this.httpUrl,
    this.location,
    this.warehouseCode,
    this.status,
    this.aiEnabled,
    this.aiTaskId,
    this.snapshotUrl,
    this.resolution,
    this.streamType,
    this.username,
    this.password,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
  });

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id'] as int?,
      cameraCode: json['cameraCode'] as String?,
      cameraName: json['cameraName'] as String?,
      cameraType: json['cameraType'] as String?,
      brand: json['brand'] as String?,
      rtspUrl: json['rtspUrl'] as String?,
      httpUrl: json['httpUrl'] as String?,
      location: json['location'] as String?,
      warehouseCode: json['warehouseCode'] as String?,
      status: json['status'] as int?,
      aiEnabled: json['aiEnabled'] as bool?,
      aiTaskId: json['aiTaskId'] as String?,
      snapshotUrl: json['snapshotUrl'] as String?,
      resolution: json['resolution'] as String?,
      streamType: json['streamType'] as int?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      enterpriseId: json['enterpriseId'] as int?,
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
      'cameraCode': cameraCode,
      'cameraName': cameraName,
      'cameraType': cameraType,
      'brand': brand,
      'rtspUrl': rtspUrl,
      'httpUrl': httpUrl,
      'location': location,
      'warehouseCode': warehouseCode,
      'status': status,
      'aiEnabled': aiEnabled,
      'aiTaskId': aiTaskId,
      'snapshotUrl': snapshotUrl,
      'resolution': resolution,
      'streamType': streamType,
      'username': username,
      'password': password,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  String get cameraTypeText {
    switch (cameraType) {
      case 'ptz':
        return '云台';
      case 'fixed':
        return '固定';
      case 'dome':
        return '半球';
      default:
        return '未知';
    }
  }

  String get brandText {
    switch (brand) {
      case 'hikvision':
        return '海康威视';
      case 'dahua':
        return '大华';
      case 'uniview':
        return '宇视';
      default:
        return brand ?? '其他';
    }
  }

  String get statusText {
    switch (status) {
      case 0:
        return '离线';
      case 1:
        return '在线';
      case 2:
        return '故障';
      default:
        return '未知';
    }
  }

  bool get isOnline => status == 1;

  String? get previewUrl => rtspUrl ?? httpUrl;

  CameraModel copyWith({
    int? id,
    String? cameraCode,
    String? cameraName,
    String? cameraType,
    String? brand,
    String? rtspUrl,
    String? httpUrl,
    String? location,
    String? warehouseCode,
    int? status,
    bool? aiEnabled,
    String? aiTaskId,
    String? snapshotUrl,
    String? resolution,
    int? streamType,
    String? username,
    String? password,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return CameraModel(
      id: id ?? this.id,
      cameraCode: cameraCode ?? this.cameraCode,
      cameraName: cameraName ?? this.cameraName,
      cameraType: cameraType ?? this.cameraType,
      brand: brand ?? this.brand,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      httpUrl: httpUrl ?? this.httpUrl,
      location: location ?? this.location,
      warehouseCode: warehouseCode ?? this.warehouseCode,
      status: status ?? this.status,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiTaskId: aiTaskId ?? this.aiTaskId,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      resolution: resolution ?? this.resolution,
      streamType: streamType ?? this.streamType,
      username: username ?? this.username,
      password: password ?? this.password,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}
