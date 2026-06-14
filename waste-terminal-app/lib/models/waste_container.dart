class WasteContainer {
  final int? id;
  final String? containerCode;
  final String? containerType;
  final String? containerSpec;
  final String? material;
  final double? capacity;
  final int? status;
  final String? location;
  final String? rfidCode;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  WasteContainer({
    this.id,
    this.containerCode,
    this.containerType,
    this.containerSpec,
    this.material,
    this.capacity,
    this.status,
    this.location,
    this.rfidCode,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory WasteContainer.fromJson(Map<String, dynamic> json) {
    return WasteContainer(
      id: json['id'] as int?,
      containerCode: json['containerCode'] as String?,
      containerType: json['containerType'] as String?,
      containerSpec: json['containerSpec'] as String?,
      material: json['material'] as String?,
      capacity: (json['capacity'] as num?)?.toDouble(),
      status: json['status'] as int?,
      location: json['location'] as String?,
      rfidCode: json['rfidCode'] as String?,
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
      'containerCode': containerCode,
      'containerType': containerType,
      'containerSpec': containerSpec,
      'material': material,
      'capacity': capacity,
      'status': status,
      'location': location,
      'rfidCode': rfidCode,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  WasteContainer copyWith({
    int? id,
    String? containerCode,
    String? containerType,
    String? containerSpec,
    String? material,
    double? capacity,
    int? status,
    String? location,
    String? rfidCode,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return WasteContainer(
      id: id ?? this.id,
      containerCode: containerCode ?? this.containerCode,
      containerType: containerType ?? this.containerType,
      containerSpec: containerSpec ?? this.containerSpec,
      material: material ?? this.material,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      location: location ?? this.location,
      rfidCode: rfidCode ?? this.rfidCode,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
