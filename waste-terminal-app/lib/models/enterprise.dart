class Enterprise {
  final int? id;
  final String? enterpriseName;
  final String? enterpriseCode;
  final String? legalPerson;
  final String? contactPerson;
  final String? contactPhone;
  final String? address;
  final String? province;
  final String? city;
  final String? district;
  final String? businessLicense;
  final String? wasteLicense;
  final DateTime? licenseExpireDate;
  final double? storageCapacity;
  final double? storageUsed;
  final int? status;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? deleted;

  Enterprise({
    this.id,
    this.enterpriseName,
    this.enterpriseCode,
    this.legalPerson,
    this.contactPerson,
    this.contactPhone,
    this.address,
    this.province,
    this.city,
    this.district,
    this.businessLicense,
    this.wasteLicense,
    this.licenseExpireDate,
    this.storageCapacity,
    this.storageUsed,
    this.status,
    this.createTime,
    this.updateTime,
    this.deleted,
  });

  factory Enterprise.fromJson(Map<String, dynamic> json) {
    return Enterprise(
      id: json['id'] as int?,
      enterpriseName: json['enterpriseName'] as String?,
      enterpriseCode: json['enterpriseCode'] as String?,
      legalPerson: json['legalPerson'] as String?,
      contactPerson: json['contactPerson'] as String?,
      contactPhone: json['contactPhone'] as String?,
      address: json['address'] as String?,
      province: json['province'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      businessLicense: json['businessLicense'] as String?,
      wasteLicense: json['wasteLicense'] as String?,
      licenseExpireDate: json['licenseExpireDate'] != null
          ? DateTime.tryParse(json['licenseExpireDate'] as String)
          : null,
      storageCapacity: (json['storageCapacity'] as num?)?.toDouble(),
      storageUsed: (json['storageUsed'] as num?)?.toDouble(),
      status: json['status'] as int?,
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
      'enterpriseName': enterpriseName,
      'enterpriseCode': enterpriseCode,
      'legalPerson': legalPerson,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'address': address,
      'province': province,
      'city': city,
      'district': district,
      'businessLicense': businessLicense,
      'wasteLicense': wasteLicense,
      'licenseExpireDate': licenseExpireDate?.toIso8601String(),
      'storageCapacity': storageCapacity,
      'storageUsed': storageUsed,
      'status': status,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'deleted': deleted,
    };
  }

  Enterprise copyWith({
    int? id,
    String? enterpriseName,
    String? enterpriseCode,
    String? legalPerson,
    String? contactPerson,
    String? contactPhone,
    String? address,
    String? province,
    String? city,
    String? district,
    String? businessLicense,
    String? wasteLicense,
    DateTime? licenseExpireDate,
    double? storageCapacity,
    double? storageUsed,
    int? status,
    DateTime? createTime,
    DateTime? updateTime,
    int? deleted,
  }) {
    return Enterprise(
      id: id ?? this.id,
      enterpriseName: enterpriseName ?? this.enterpriseName,
      enterpriseCode: enterpriseCode ?? this.enterpriseCode,
      legalPerson: legalPerson ?? this.legalPerson,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      businessLicense: businessLicense ?? this.businessLicense,
      wasteLicense: wasteLicense ?? this.wasteLicense,
      licenseExpireDate: licenseExpireDate ?? this.licenseExpireDate,
      storageCapacity: storageCapacity ?? this.storageCapacity,
      storageUsed: storageUsed ?? this.storageUsed,
      status: status ?? this.status,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
