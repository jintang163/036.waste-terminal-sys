class TransferOrderItem {
  final int? id;
  final int? orderId;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final String? hazardCode;
  final String? containerCode;
  final double? weight;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;

  TransferOrderItem({
    this.id,
    this.orderId,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.hazardCode,
    this.containerCode,
    this.weight,
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory TransferOrderItem.fromJson(Map<String, dynamic> json) {
    return TransferOrderItem(
      id: json['id'] as int?,
      orderId: json['orderId'] as int?,
      wasteId: json['wasteId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      wasteCategory: json['wasteCategory'] as String?,
      hazardCode: json['hazardCode'] as String?,
      containerCode: json['containerCode'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
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
      'orderId': orderId,
      'wasteId': wasteId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'wasteCategory': wasteCategory,
      'hazardCode': hazardCode,
      'containerCode': containerCode,
      'weight': weight,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }
}

class TransferOrder {
  final int? id;
  final String? orderNo;
  final String? nationalOrderNo;
  final String? orderType;
  final int? generatorUnitId;
  final String? generatorUnitName;
  final String? generatorUnitCode;
  final int? receiverUnitId;
  final String? receiverUnitName;
  final String? receiverUnitCode;
  final String? receiverLicenseNo;
  final int? transporterId;
  final String? transporterName;
  final String? transporterLicenseNo;
  final String? vehicleNo;
  final String? driverName;
  final String? driverLicense;
  final String? escortName;
  final double? totalWeight;
  final int? totalContainers;
  final String? wasteDetails;
  final List<TransferOrderItem>? items;
  final DateTime? startTime;
  final DateTime? estimateArriveTime;
  final DateTime? actualArriveTime;
  final String? route;
  final String? emergencyContact;
  final String? emergencyPhone;
  final int? status;
  final int? reportStatus;
  final DateTime? reportTime;
  final String? qrCode;
  final String? signPhoto;
  final String? receiptPhoto;
  final String? remark;
  final String? offlineId;
  final int? operatorId;
  final String? operatorName;
  final int? enterpriseId;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  TransferOrder({
    this.id,
    this.orderNo,
    this.nationalOrderNo,
    this.orderType,
    this.generatorUnitId,
    this.generatorUnitName,
    this.generatorUnitCode,
    this.receiverUnitId,
    this.receiverUnitName,
    this.receiverUnitCode,
    this.receiverLicenseNo,
    this.transporterId,
    this.transporterName,
    this.transporterLicenseNo,
    this.vehicleNo,
    this.driverName,
    this.driverLicense,
    this.escortName,
    this.totalWeight,
    this.totalContainers,
    this.wasteDetails,
    this.items,
    this.startTime,
    this.estimateArriveTime,
    this.actualArriveTime,
    this.route,
    this.emergencyContact,
    this.emergencyPhone,
    this.status,
    this.reportStatus,
    this.reportTime,
    this.qrCode,
    this.signPhoto,
    this.receiptPhoto,
    this.remark,
    this.offlineId,
    this.operatorId,
    this.operatorName,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory TransferOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>?;
    return TransferOrder(
      id: json['id'] as int?,
      orderNo: json['orderNo'] as String?,
      nationalOrderNo: json['nationalOrderNo'] as String?,
      orderType: json['orderType'] as String?,
      generatorUnitId: json['generatorUnitId'] as int?,
      generatorUnitName: json['generatorUnitName'] as String?,
      generatorUnitCode: json['generatorUnitCode'] as String?,
      receiverUnitId: json['receiverUnitId'] as int?,
      receiverUnitName: json['receiverUnitName'] as String?,
      receiverUnitCode: json['receiverUnitCode'] as String?,
      receiverLicenseNo: json['receiverLicenseNo'] as String?,
      transporterId: json['transporterId'] as int?,
      transporterName: json['transporterName'] as String?,
      transporterLicenseNo: json['transporterLicenseNo'] as String?,
      vehicleNo: json['vehicleNo'] as String?,
      driverName: json['driverName'] as String?,
      driverLicense: json['driverLicense'] as String?,
      escortName: json['escortName'] as String?,
      totalWeight: (json['totalWeight'] as num?)?.toDouble(),
      totalContainers: json['totalContainers'] as int?,
      wasteDetails: json['wasteDetails'] as String?,
      items: itemsJson
          ?.map((e) => TransferOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      estimateArriveTime: json['estimateArriveTime'] != null
          ? DateTime.tryParse(json['estimateArriveTime'] as String)
          : null,
      actualArriveTime: json['actualArriveTime'] != null
          ? DateTime.tryParse(json['actualArriveTime'] as String)
          : null,
      route: json['route'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      emergencyPhone: json['emergencyPhone'] as String?,
      status: json['status'] as int?,
      reportStatus: json['reportStatus'] as int?,
      reportTime: json['reportTime'] != null
          ? DateTime.tryParse(json['reportTime'] as String)
          : null,
      qrCode: json['qrCode'] as String?,
      signPhoto: json['signPhoto'] as String?,
      receiptPhoto: json['receiptPhoto'] as String?,
      remark: json['remark'] as String?,
      offlineId: json['offlineId'] as String?,
      operatorId: json['operatorId'] as int?,
      operatorName: json['operatorName'] as String?,
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
      'orderNo': orderNo,
      'nationalOrderNo': nationalOrderNo,
      'orderType': orderType,
      'generatorUnitId': generatorUnitId,
      'generatorUnitName': generatorUnitName,
      'generatorUnitCode': generatorUnitCode,
      'receiverUnitId': receiverUnitId,
      'receiverUnitName': receiverUnitName,
      'receiverUnitCode': receiverUnitCode,
      'receiverLicenseNo': receiverLicenseNo,
      'transporterId': transporterId,
      'transporterName': transporterName,
      'transporterLicenseNo': transporterLicenseNo,
      'vehicleNo': vehicleNo,
      'driverName': driverName,
      'driverLicense': driverLicense,
      'escortName': escortName,
      'totalWeight': totalWeight,
      'totalContainers': totalContainers,
      'wasteDetails': wasteDetails,
      'items': items?.map((e) => e.toJson()).toList(),
      'startTime': startTime?.toIso8601String(),
      'estimateArriveTime': estimateArriveTime?.toIso8601String(),
      'actualArriveTime': actualArriveTime?.toIso8601String(),
      'route': route,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'status': status,
      'reportStatus': reportStatus,
      'reportTime': reportTime?.toIso8601String(),
      'qrCode': qrCode,
      'signPhoto': signPhoto,
      'receiptPhoto': receiptPhoto,
      'remark': remark,
      'offlineId': offlineId,
      'operatorId': operatorId,
      'operatorName': operatorName,
      'enterpriseId': enterpriseId,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  TransferOrder copyWith({
    int? id,
    String? orderNo,
    String? nationalOrderNo,
    String? orderType,
    int? generatorUnitId,
    String? generatorUnitName,
    String? generatorUnitCode,
    int? receiverUnitId,
    String? receiverUnitName,
    String? receiverUnitCode,
    String? receiverLicenseNo,
    int? transporterId,
    String? transporterName,
    String? transporterLicenseNo,
    String? vehicleNo,
    String? driverName,
    String? driverLicense,
    String? escortName,
    double? totalWeight,
    int? totalContainers,
    String? wasteDetails,
    List<TransferOrderItem>? items,
    DateTime? startTime,
    DateTime? estimateArriveTime,
    DateTime? actualArriveTime,
    String? route,
    String? emergencyContact,
    String? emergencyPhone,
    int? status,
    int? reportStatus,
    DateTime? reportTime,
    String? qrCode,
    String? signPhoto,
    String? receiptPhoto,
    String? remark,
    String? offlineId,
    int? operatorId,
    String? operatorName,
    int? enterpriseId,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return TransferOrder(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      nationalOrderNo: nationalOrderNo ?? this.nationalOrderNo,
      orderType: orderType ?? this.orderType,
      generatorUnitId: generatorUnitId ?? this.generatorUnitId,
      generatorUnitName: generatorUnitName ?? this.generatorUnitName,
      generatorUnitCode: generatorUnitCode ?? this.generatorUnitCode,
      receiverUnitId: receiverUnitId ?? this.receiverUnitId,
      receiverUnitName: receiverUnitName ?? this.receiverUnitName,
      receiverUnitCode: receiverUnitCode ?? this.receiverUnitCode,
      receiverLicenseNo: receiverLicenseNo ?? this.receiverLicenseNo,
      transporterId: transporterId ?? this.transporterId,
      transporterName: transporterName ?? this.transporterName,
      transporterLicenseNo: transporterLicenseNo ?? this.transporterLicenseNo,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      driverName: driverName ?? this.driverName,
      driverLicense: driverLicense ?? this.driverLicense,
      escortName: escortName ?? this.escortName,
      totalWeight: totalWeight ?? this.totalWeight,
      totalContainers: totalContainers ?? this.totalContainers,
      wasteDetails: wasteDetails ?? this.wasteDetails,
      items: items ?? this.items,
      startTime: startTime ?? this.startTime,
      estimateArriveTime: estimateArriveTime ?? this.estimateArriveTime,
      actualArriveTime: actualArriveTime ?? this.actualArriveTime,
      route: route ?? this.route,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      status: status ?? this.status,
      reportStatus: reportStatus ?? this.reportStatus,
      reportTime: reportTime ?? this.reportTime,
      qrCode: qrCode ?? this.qrCode,
      signPhoto: signPhoto ?? this.signPhoto,
      receiptPhoto: receiptPhoto ?? this.receiptPhoto,
      remark: remark ?? this.remark,
      offlineId: offlineId ?? this.offlineId,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
