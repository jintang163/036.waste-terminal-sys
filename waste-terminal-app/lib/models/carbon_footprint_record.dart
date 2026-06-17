class CarbonFootprintRecord {
  final int? id;
  final String? recordId;
  final String? offlineId;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final double? weight;
  final String? weightUnit;
  final double? transportDistance;
  final String? transportDistanceUnit;
  final String? transportMode;
  final String? disposalMethod;
  final double? transportEmission;
  final double? disposalEmission;
  final double? totalEmission;
  final String? emissionUnit;
  final String? transferOrderId;
  final String? transferOrderNo;
  final String? operator;
  final String? operatorId;
  final String? remark;
  final int? syncStatus;
  final String? syncTime;
  final DateTime? recordTime;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? isDeleted;

  CarbonFootprintRecord({
    this.id,
    this.recordId,
    this.offlineId,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.weight,
    this.weightUnit,
    this.transportDistance,
    this.transportDistanceUnit,
    this.transportMode,
    this.disposalMethod,
    this.transportEmission,
    this.disposalEmission,
    this.totalEmission,
    this.emissionUnit,
    this.transferOrderId,
    this.transferOrderNo,
    this.operator,
    this.operatorId,
    this.remark,
    this.syncStatus,
    this.syncTime,
    this.recordTime,
    this.createTime,
    this.updateTime,
    this.isDeleted,
  });

  factory CarbonFootprintRecord.fromJson(Map<String, dynamic> json) {
    return CarbonFootprintRecord(
      id: json['id'] as int?,
      recordId: json['record_id'] as String?,
      offlineId: json['offline_id'] as String?,
      wasteCode: json['waste_code'] as String?,
      wasteName: json['waste_name'] as String?,
      wasteCategory: json['waste_category'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit: json['weight_unit'] as String?,
      transportDistance: (json['transport_distance'] as num?)?.toDouble(),
      transportDistanceUnit: json['transport_distance_unit'] as String?,
      transportMode: json['transport_mode'] as String?,
      disposalMethod: json['disposal_method'] as String?,
      transportEmission: (json['transport_emission'] as num?)?.toDouble(),
      disposalEmission: (json['disposal_emission'] as num?)?.toDouble(),
      totalEmission: (json['total_emission'] as num?)?.toDouble(),
      emissionUnit: json['emission_unit'] as String?,
      transferOrderId: json['transfer_order_id'] as String?,
      transferOrderNo: json['transfer_order_no'] as String?,
      operator: json['operator'] as String?,
      operatorId: json['operator_id'] as String?,
      remark: json['remark'] as String?,
      syncStatus: json['sync_status'] as int?,
      syncTime: json['sync_time'] as String?,
      recordTime: json['record_time'] != null
          ? DateTime.tryParse(json['record_time'] as String)
          : null,
      createTime: json['create_time'] != null
          ? DateTime.tryParse(json['create_time'] as String)
          : null,
      updateTime: json['update_time'] != null
          ? DateTime.tryParse(json['update_time'] as String)
          : null,
      isDeleted: json['is_deleted'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'record_id': recordId,
      'offline_id': offlineId,
      'waste_code': wasteCode,
      'waste_name': wasteName,
      'waste_category': wasteCategory,
      'weight': weight,
      'weight_unit': weightUnit,
      'transport_distance': transportDistance,
      'transport_distance_unit': transportDistanceUnit,
      'transport_mode': transportMode,
      'disposal_method': disposalMethod,
      'transport_emission': transportEmission,
      'disposal_emission': disposalEmission,
      'total_emission': totalEmission,
      'emission_unit': emissionUnit,
      'transfer_order_id': transferOrderId,
      'transfer_order_no': transferOrderNo,
      'operator': operator,
      'operator_id': operatorId,
      'remark': remark,
      'sync_status': syncStatus,
      'sync_time': syncTime,
      'record_time': recordTime?.toIso8601String(),
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  CarbonFootprintRecord copyWith({
    int? id,
    String? recordId,
    String? offlineId,
    String? wasteCode,
    String? wasteName,
    String? wasteCategory,
    double? weight,
    String? weightUnit,
    double? transportDistance,
    String? transportDistanceUnit,
    String? transportMode,
    String? disposalMethod,
    double? transportEmission,
    double? disposalEmission,
    double? totalEmission,
    String? emissionUnit,
    String? transferOrderId,
    String? transferOrderNo,
    String? operator,
    String? operatorId,
    String? remark,
    int? syncStatus,
    String? syncTime,
    DateTime? recordTime,
    DateTime? createTime,
    DateTime? updateTime,
    int? isDeleted,
  }) {
    return CarbonFootprintRecord(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      offlineId: offlineId ?? this.offlineId,
      wasteCode: wasteCode ?? this.wasteCode,
      wasteName: wasteName ?? this.wasteName,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      transportDistance: transportDistance ?? this.transportDistance,
      transportDistanceUnit: transportDistanceUnit ?? this.transportDistanceUnit,
      transportMode: transportMode ?? this.transportMode,
      disposalMethod: disposalMethod ?? this.disposalMethod,
      transportEmission: transportEmission ?? this.transportEmission,
      disposalEmission: disposalEmission ?? this.disposalEmission,
      totalEmission: totalEmission ?? this.totalEmission,
      emissionUnit: emissionUnit ?? this.emissionUnit,
      transferOrderId: transferOrderId ?? this.transferOrderId,
      transferOrderNo: transferOrderNo ?? this.transferOrderNo,
      operator: operator ?? this.operator,
      operatorId: operatorId ?? this.operatorId,
      remark: remark ?? this.remark,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      recordTime: recordTime ?? this.recordTime,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class CarbonEmissionFactor {
  final String wasteCategory;
  final String disposalMethod;
  final double factor;
  final String unit;
  final String description;

  CarbonEmissionFactor({
    required this.wasteCategory,
    required this.disposalMethod,
    required this.factor,
    required this.unit,
    required this.description,
  });
}

class TransportEmissionFactor {
  final String transportMode;
  final double factor;
  final String unit;
  final String description;

  TransportEmissionFactor({
    required this.transportMode,
    required this.factor,
    required this.unit,
    required this.description,
  });
}
