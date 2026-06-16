class TransportDriver {
  final int? id;
  final String? driverId;
  final String? driverName;
  final String? gender;
  final String? phone;
  final String? idCard;
  final String? driverLicense;
  final String? driverLicenseType;
  final String? qualificationCert;
  final String? hazardousCert;
  final int? workYears;
  final String? vehicleId;
  final String? vehicleNo;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? photoUrl;
  final int? status;
  final String? remark;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? isDeleted;

  TransportDriver({
    this.id,
    this.driverId,
    this.driverName,
    this.gender,
    this.phone,
    this.idCard,
    this.driverLicense,
    this.driverLicenseType,
    this.qualificationCert,
    this.hazardousCert,
    this.workYears,
    this.vehicleId,
    this.vehicleNo,
    this.emergencyContact,
    this.emergencyPhone,
    this.photoUrl,
    this.status,
    this.remark,
    this.createTime,
    this.updateTime,
    this.isDeleted,
  });

  factory TransportDriver.fromJson(Map<String, dynamic> json) {
    return TransportDriver(
      id: json['id'] as int?,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      gender: json['gender'] as String?,
      phone: json['phone'] as String?,
      idCard: json['idCard'] as String?,
      driverLicense: json['driverLicense'] as String?,
      driverLicenseType: json['driverLicenseType'] as String?,
      qualificationCert: json['qualificationCert'] as String?,
      hazardousCert: json['hazardousCert'] as String?,
      workYears: json['workYears'] as int?,
      vehicleId: json['vehicleId'] as String?,
      vehicleNo: json['vehicleNo'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      emergencyPhone: json['emergencyPhone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: json['status'] as int?,
      remark: json['remark'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      isDeleted: json['isDeleted'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'driverName': driverName,
      'gender': gender,
      'phone': phone,
      'idCard': idCard,
      'driverLicense': driverLicense,
      'driverLicenseType': driverLicenseType,
      'qualificationCert': qualificationCert,
      'hazardousCert': hazardousCert,
      'workYears': workYears,
      'vehicleId': vehicleId,
      'vehicleNo': vehicleNo,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'photoUrl': photoUrl,
      'status': status,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory TransportDriver.fromDbMap(Map<String, dynamic> map) {
    return TransportDriver(
      id: map['id'] as int?,
      driverId: map['driver_id'] as String?,
      driverName: map['driver_name'] as String?,
      gender: map['gender'] as String?,
      phone: map['phone'] as String?,
      idCard: map['id_card'] as String?,
      driverLicense: map['driver_license'] as String?,
      driverLicenseType: map['driver_license_type'] as String?,
      qualificationCert: map['qualification_cert'] as String?,
      hazardousCert: map['hazardous_cert'] as String?,
      workYears: map['work_years'] as int?,
      vehicleId: map['vehicle_id'] as String?,
      vehicleNo: map['vehicle_no'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      emergencyPhone: map['emergency_phone'] as String?,
      photoUrl: map['photo_url'] as String?,
      status: map['status'] as int?,
      remark: map['remark'] as String?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
      updateTime: map['update_time'] != null
          ? DateTime.tryParse(map['update_time'] as String)
          : null,
      isDeleted: map['is_deleted'] as int?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'driver_name': driverName,
      'gender': gender,
      'phone': phone,
      'id_card': idCard,
      'driver_license': driverLicense,
      'driver_license_type': driverLicenseType,
      'qualification_cert': qualificationCert,
      'hazardous_cert': hazardousCert,
      'work_years': workYears,
      'vehicle_id': vehicleId,
      'vehicle_no': vehicleNo,
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'photo_url': photoUrl,
      'status': status,
      'remark': remark,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  TransportDriver copyWith({
    int? id,
    String? driverId,
    String? driverName,
    String? gender,
    String? phone,
    String? idCard,
    String? driverLicense,
    String? driverLicenseType,
    String? qualificationCert,
    String? hazardousCert,
    int? workYears,
    String? vehicleId,
    String? vehicleNo,
    String? emergencyContact,
    String? emergencyPhone,
    String? photoUrl,
    int? status,
    String? remark,
    DateTime? createTime,
    DateTime? updateTime,
    int? isDeleted,
  }) {
    return TransportDriver(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      idCard: idCard ?? this.idCard,
      driverLicense: driverLicense ?? this.driverLicense,
      driverLicenseType: driverLicenseType ?? this.driverLicenseType,
      qualificationCert: qualificationCert ?? this.qualificationCert,
      hazardousCert: hazardousCert ?? this.hazardousCert,
      workYears: workYears ?? this.workYears,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
