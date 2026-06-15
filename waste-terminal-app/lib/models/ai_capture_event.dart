class AiCaptureEvent {
  final int? id;
  final String? eventNo;
  final int? cameraId;
  final String? cameraCode;
  final String? cameraName;
  final String? eventType;
  final String? eventCategory;
  final int? confidence;
  final String? snapshotPath;
  final String? videoClipPath;
  final String? detail;
  final DateTime? captureTime;
  final int? handleStatus;
  final int? handleUserId;
  final DateTime? handleTime;
  final String? handleRemark;
  final int? pushStatus;
  final DateTime? pushTime;
  final String? pushFailReason;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;

  AiCaptureEvent({
    this.id,
    this.eventNo,
    this.cameraId,
    this.cameraCode,
    this.cameraName,
    this.eventType,
    this.eventCategory,
    this.confidence,
    this.snapshotPath,
    this.videoClipPath,
    this.detail,
    this.captureTime,
    this.handleStatus,
    this.handleUserId,
    this.handleTime,
    this.handleRemark,
    this.pushStatus,
    this.pushTime,
    this.pushFailReason,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
  });

  factory AiCaptureEvent.fromJson(Map<String, dynamic> json) {
    return AiCaptureEvent(
      id: json['id'] as int?,
      eventNo: json['eventNo'] as String?,
      cameraId: json['cameraId'] as int?,
      cameraCode: json['cameraCode'] as String?,
      cameraName: json['cameraName'] as String?,
      eventType: json['eventType'] as String?,
      eventCategory: json['eventCategory'] as String?,
      confidence: json['confidence'] as int?,
      snapshotPath: json['snapshotPath'] as String?,
      videoClipPath: json['videoClipPath'] as String?,
      detail: json['detail'] as String?,
      captureTime: json['captureTime'] != null
          ? DateTime.tryParse(json['captureTime'] as String)
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
      pushFailReason: json['pushFailReason'] as String?,
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
      'eventNo': eventNo,
      'cameraId': cameraId,
      'cameraCode': cameraCode,
      'cameraName': cameraName,
      'eventType': eventType,
      'eventCategory': eventCategory,
      'confidence': confidence,
      'snapshotPath': snapshotPath,
      'videoClipPath': videoClipPath,
      'detail': detail,
      'captureTime': captureTime?.toIso8601String(),
      'handleStatus': handleStatus,
      'handleUserId': handleUserId,
      'handleTime': handleTime?.toIso8601String(),
      'handleRemark': handleRemark,
      'pushStatus': pushStatus,
      'pushTime': pushTime?.toIso8601String(),
      'pushFailReason': pushFailReason,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  String get eventTypeText {
    switch (eventType) {
      case 'no_goggles':
        return '未戴护目镜';
      case 'no_mask':
        return '未戴口罩';
      case 'no_helmet':
        return '未戴安全帽';
      case 'forklift_speeding':
        return '叉车超速';
      case 'smoking':
        return '吸烟';
      case 'fall_detection':
        return '跌倒检测';
      case 'unauthorized_entry':
        return '非法闯入';
      default:
        return eventType ?? '未知事件';
    }
  }

  String get eventCategoryText {
    switch (eventCategory) {
      case 'safety_violation':
        return '安全违规';
      case 'equipment_warning':
        return '设备预警';
      case 'behavior_abnormal':
        return '行为异常';
      default:
        return eventCategory ?? '未知';
    }
  }

  String get handleStatusText {
    switch (handleStatus) {
      case 0:
        return '未处理';
      case 1:
        return '已处理';
      case 2:
        return '已忽略';
      default:
        return '未知';
    }
  }

  bool get isUnhandled => handleStatus == 0;

  AiCaptureEvent copyWith({
    int? id,
    String? eventNo,
    int? cameraId,
    String? cameraCode,
    String? cameraName,
    String? eventType,
    String? eventCategory,
    int? confidence,
    String? snapshotPath,
    String? videoClipPath,
    String? detail,
    DateTime? captureTime,
    int? handleStatus,
    int? handleUserId,
    DateTime? handleTime,
    String? handleRemark,
    int? pushStatus,
    DateTime? pushTime,
    String? pushFailReason,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return AiCaptureEvent(
      id: id ?? this.id,
      eventNo: eventNo ?? this.eventNo,
      cameraId: cameraId ?? this.cameraId,
      cameraCode: cameraCode ?? this.cameraCode,
      cameraName: cameraName ?? this.cameraName,
      eventType: eventType ?? this.eventType,
      eventCategory: eventCategory ?? this.eventCategory,
      confidence: confidence ?? this.confidence,
      snapshotPath: snapshotPath ?? this.snapshotPath,
      videoClipPath: videoClipPath ?? this.videoClipPath,
      detail: detail ?? this.detail,
      captureTime: captureTime ?? this.captureTime,
      handleStatus: handleStatus ?? this.handleStatus,
      handleUserId: handleUserId ?? this.handleUserId,
      handleTime: handleTime ?? this.handleTime,
      handleRemark: handleRemark ?? this.handleRemark,
      pushStatus: pushStatus ?? this.pushStatus,
      pushTime: pushTime ?? this.pushTime,
      pushFailReason: pushFailReason ?? this.pushFailReason,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}
