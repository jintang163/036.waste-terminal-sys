class WasteOutReview {
  final int? id;
  final String reviewNo;
  final int? outRecordId;
  final String? outNo;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final double? weight;
  final String? containerCode;
  final int? operatorId;
  final String? operatorName;
  final int? reviewerId;
  final String? reviewerName;
  final String? reviewType;
  final int? reviewResult;
  final DateTime? reviewTime;
  final String? reviewRemark;
  final String? reviewerFaceAuthId;
  final String? reviewerFaceId;
  final String? reviewerFaceImage;
  final String? reviewQrCode;
  final int? syncStatus;
  final DateTime? syncTime;
  final String? offlineId;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  WasteOutReview({
    this.id,
    required this.reviewNo,
    this.outRecordId,
    this.outNo,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.weight,
    this.containerCode,
    this.operatorId,
    this.operatorName,
    this.reviewerId,
    this.reviewerName,
    this.reviewType,
    this.reviewResult,
    this.reviewTime,
    this.reviewRemark,
    this.reviewerFaceAuthId,
    this.reviewerFaceId,
    this.reviewerFaceImage,
    this.reviewQrCode,
    this.syncStatus,
    this.syncTime,
    this.offlineId,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory WasteOutReview.fromJson(Map<String, dynamic> json) {
    return WasteOutReview(
      id: json['id'] as int?,
      reviewNo: json['reviewNo'] as String? ?? '',
      outRecordId: json['outRecordId'] as int?,
      outNo: json['outNo'] as String?,
      wasteId: json['wasteId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      containerCode: json['containerCode'] as String?,
      operatorId: json['operatorId'] as int?,
      operatorName: json['operatorName'] as String?,
      reviewerId: json['reviewerId'] as int?,
      reviewerName: json['reviewerName'] as String?,
      reviewType: json['reviewType'] as String?,
      reviewResult: json['reviewResult'] as int?,
      reviewTime: json['reviewTime'] != null
          ? DateTime.tryParse(json['reviewTime'] as String)
          : null,
      reviewRemark: json['reviewRemark'] as String?,
      reviewerFaceAuthId: json['reviewerFaceAuthId'] as String?,
      reviewerFaceId: json['reviewerFaceId'] as String?,
      reviewerFaceImage: json['reviewerFaceImage'] as String?,
      reviewQrCode: json['reviewQrCode'] as String?,
      syncStatus: json['syncStatus'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
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
      'reviewNo': reviewNo,
      'outRecordId': outRecordId,
      'outNo': outNo,
      'wasteId': wasteId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'weight': weight,
      'containerCode': containerCode,
      'operatorId': operatorId,
      'operatorName': operatorName,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewType': reviewType,
      'reviewResult': reviewResult,
      'reviewTime': reviewTime?.toIso8601String(),
      'reviewRemark': reviewRemark,
      'reviewerFaceAuthId': reviewerFaceAuthId,
      'reviewerFaceId': reviewerFaceId,
      'reviewerFaceImage': reviewerFaceImage,
      'reviewQrCode': reviewQrCode,
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'offlineId': offlineId,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  factory WasteOutReview.fromDbMap(Map<String, dynamic> map) {
    return WasteOutReview(
      id: map['id'] as int?,
      reviewNo: map['review_no'] as String? ?? '',
      outRecordId: map['out_record_id'] as int?,
      outNo: map['out_no'] as String?,
      wasteId: map['waste_id'] as int?,
      wasteCode: map['waste_code'] as String?,
      wasteName: map['waste_name'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      containerCode: map['container_code'] as String?,
      operatorId: map['operator_id'] as int?,
      operatorName: map['operator_name'] as String?,
      reviewerId: map['reviewer_id'] as int?,
      reviewerName: map['reviewer_name'] as String?,
      reviewType: map['review_type'] as String?,
      reviewResult: map['review_result'] as int?,
      reviewTime: map['review_time'] != null
          ? DateTime.tryParse(map['review_time'] as String)
          : null,
      reviewRemark: map['review_remark'] as String?,
      reviewerFaceAuthId: map['reviewer_face_auth_id'] as String?,
      reviewerFaceId: map['reviewer_face_id'] as String?,
      reviewerFaceImage: map['reviewer_face_image'] as String?,
      reviewQrCode: map['review_qr_code'] as String?,
      syncStatus: map['sync_status'] as int?,
      syncTime: map['sync_time'] != null
          ? DateTime.tryParse(map['sync_time'] as String)
          : null,
      offlineId: map['offline_id'] as String?,
      enterpriseId: map['enterprise_id'] as int?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
      updateTime: map['update_time'] != null
          ? DateTime.tryParse(map['update_time'] as String)
          : null,
      deleted: map['is_deleted'] as int?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'review_no': reviewNo,
      'out_record_id': outRecordId,
      'out_no': outNo,
      'waste_id': wasteId,
      'waste_code': wasteCode,
      'waste_name': wasteName,
      'weight': weight,
      'container_code': containerCode,
      'operator_id': operatorId,
      'operator_name': operatorName,
      'reviewer_id': reviewerId,
      'reviewer_name': reviewerName,
      'review_type': reviewType,
      'review_result': reviewResult,
      'review_time': reviewTime?.toIso8601String(),
      'review_remark': reviewRemark,
      'reviewer_face_auth_id': reviewerFaceAuthId,
      'reviewer_face_id': reviewerFaceId,
      'reviewer_face_image': reviewerFaceImage,
      'review_qr_code': reviewQrCode,
      'sync_status': syncStatus,
      'sync_time': syncTime?.toIso8601String(),
      'offline_id': offlineId,
      'enterprise_id': enterpriseId,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': deleted,
    };
  }

  WasteOutReview copyWith({
    int? id,
    String? reviewNo,
    int? outRecordId,
    String? outNo,
    int? wasteId,
    String? wasteCode,
    String? wasteName,
    double? weight,
    String? containerCode,
    int? operatorId,
    String? operatorName,
    int? reviewerId,
    String? reviewerName,
    String? reviewType,
    int? reviewResult,
    DateTime? reviewTime,
    String? reviewRemark,
    String? reviewerFaceAuthId,
    String? reviewerFaceId,
    String? reviewerFaceImage,
    String? reviewQrCode,
    int? syncStatus,
    DateTime? syncTime,
    String? offlineId,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return WasteOutReview(
      id: id ?? this.id,
      reviewNo: reviewNo ?? this.reviewNo,
      outRecordId: outRecordId ?? this.outRecordId,
      outNo: outNo ?? this.outNo,
      wasteId: wasteId ?? this.wasteId,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      weight: weight ?? this.weight,
      containerCode: containerCode ?? this.containerCode,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewType: reviewType ?? this.reviewType,
      reviewResult: reviewResult ?? this.reviewResult,
      reviewTime: reviewTime ?? this.reviewTime,
      reviewRemark: reviewRemark ?? this.reviewRemark,
      reviewerFaceAuthId: reviewerFaceAuthId ?? this.reviewerFaceAuthId,
      reviewerFaceId: reviewerFaceId ?? this.reviewerFaceId,
      reviewerFaceImage: reviewerFaceImage ?? this.reviewerFaceImage,
      reviewQrCode: reviewQrCode ?? this.reviewQrCode,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      offlineId: offlineId ?? this.offlineId,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
