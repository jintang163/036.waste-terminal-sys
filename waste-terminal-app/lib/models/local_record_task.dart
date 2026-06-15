class LocalRecordTask {
  final int? id;
  final String? taskId;
  final int? cameraId;
  final String? cameraCode;
  final String? cameraName;
  final String? triggerType;
  final String? triggerId;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final String? preSeconds;
  final String? postSeconds;
  final String? filePath;
  final int? fileSize;
  final int? status;
  final int? syncStatus;
  final DateTime? syncTime;
  final String? deviceId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;

  LocalRecordTask({
    this.id,
    this.taskId,
    this.cameraId,
    this.cameraCode,
    this.cameraName,
    this.triggerType,
    this.triggerId,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.preSeconds,
    this.postSeconds,
    this.filePath,
    this.fileSize,
    this.status,
    this.syncStatus,
    this.syncTime,
    this.deviceId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
  });

  factory LocalRecordTask.fromJson(Map<String, dynamic> json) {
    return LocalRecordTask(
      id: json['id'] as int?,
      taskId: json['taskId'] as String?,
      cameraId: json['cameraId'] as int?,
      cameraCode: json['cameraCode'] as String?,
      cameraName: json['cameraName'] as String?,
      triggerType: json['triggerType'] as String?,
      triggerId: json['triggerId'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      durationSeconds: json['durationSeconds'] as int?,
      preSeconds: json['preSeconds'] as String?,
      postSeconds: json['postSeconds'] as String?,
      filePath: json['filePath'] as String?,
      fileSize: json['fileSize'] as int?,
      status: json['status'] as int?,
      syncStatus: json['syncStatus'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      deviceId: json['deviceId'] as String?,
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
      'taskId': taskId,
      'cameraId': cameraId,
      'cameraCode': cameraCode,
      'cameraName': cameraName,
      'triggerType': triggerType,
      'triggerId': triggerId,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'preSeconds': preSeconds,
      'postSeconds': postSeconds,
      'filePath': filePath,
      'fileSize': fileSize,
      'status': status,
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'deviceId': deviceId,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  String get triggerTypeText {
    switch (triggerType) {
      case 'waste_in':
        return '入库操作';
      case 'waste_out':
        return '出库操作';
      case 'ai_event':
        return 'AI事件';
      case 'manual':
        return '手动录制';
      default:
        return triggerType ?? '未知';
    }
  }

  String get statusText {
    switch (status) {
      case 0:
        return '待录制';
      case 1:
        return '录制完成';
      case 2:
        return '上传中';
      case 3:
        return '上传失败';
      default:
        return '未知';
    }
  }

  String get syncStatusText {
    switch (syncStatus) {
      case 0:
        return '未同步';
      case 1:
        return '已同步';
      default:
        return '未知';
    }
  }

  String get fileSizeText {
    if (fileSize == null) return '0 B';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    if (fileSize! < 1024 * 1024 * 1024) return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get durationText {
    if (durationSeconds == null) return '--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    if (minutes > 0) {
      return '$minutes分${seconds}秒';
    }
    return '${seconds}秒';
  }

  bool get isCompleted => status == 1;
  bool get isUnsynced => syncStatus == 0 && status == 1;

  LocalRecordTask copyWith({
    int? id,
    String? taskId,
    int? cameraId,
    String? cameraCode,
    String? cameraName,
    String? triggerType,
    String? triggerId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? preSeconds,
    String? postSeconds,
    String? filePath,
    int? fileSize,
    int? status,
    int? syncStatus,
    DateTime? syncTime,
    String? deviceId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return LocalRecordTask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      cameraId: cameraId ?? this.cameraId,
      cameraCode: cameraCode ?? this.cameraCode,
      cameraName: cameraName ?? this.cameraName,
      triggerType: triggerType ?? this.triggerType,
      triggerId: triggerId ?? this.triggerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      preSeconds: preSeconds ?? this.preSeconds,
      postSeconds: postSeconds ?? this.postSeconds,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      deviceId: deviceId ?? this.deviceId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}
