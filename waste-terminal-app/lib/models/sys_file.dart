class SysFile {
  final int? id;
  final String? fileName;
  final String? fileUrl;
  final int? fileSize;
  final String? fileType;
  final String? fileExt;
  final String? storageType;
  final String? bucketName;
  final String? objectKey;
  final String? md5;
  final String? bizType;
  final String? bizId;
  final int? uploadUserId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  SysFile({
    this.id,
    this.fileName,
    this.fileUrl,
    this.fileSize,
    this.fileType,
    this.fileExt,
    this.storageType,
    this.bucketName,
    this.objectKey,
    this.md5,
    this.bizType,
    this.bizId,
    this.uploadUserId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory SysFile.fromJson(Map<String, dynamic> json) {
    return SysFile(
      id: json['id'] as int?,
      fileName: json['fileName'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileSize: json['fileSize'] as int?,
      fileType: json['fileType'] as String?,
      fileExt: json['fileExt'] as String?,
      storageType: json['storageType'] as String?,
      bucketName: json['bucketName'] as String?,
      objectKey: json['objectKey'] as String?,
      md5: json['md5'] as String?,
      bizType: json['bizType'] as String?,
      bizId: json['bizId'] as String?,
      uploadUserId: json['uploadUserId'] as int?,
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
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'fileType': fileType,
      'fileExt': fileExt,
      'storageType': storageType,
      'bucketName': bucketName,
      'objectKey': objectKey,
      'md5': md5,
      'bizType': bizType,
      'bizId': bizId,
      'uploadUserId': uploadUserId,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  SysFile copyWith({
    int? id,
    String? fileName,
    String? fileUrl,
    int? fileSize,
    String? fileType,
    String? fileExt,
    String? storageType,
    String? bucketName,
    String? objectKey,
    String? md5,
    String? bizType,
    String? bizId,
    int? uploadUserId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return SysFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      fileExt: fileExt ?? this.fileExt,
      storageType: storageType ?? this.storageType,
      bucketName: bucketName ?? this.bucketName,
      objectKey: objectKey ?? this.objectKey,
      md5: md5 ?? this.md5,
      bizType: bizType ?? this.bizType,
      bizId: bizId ?? this.bizId,
      uploadUserId: uploadUserId ?? this.uploadUserId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }

  String get sizeText {
    if (fileSize == null) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = fileSize!.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}
