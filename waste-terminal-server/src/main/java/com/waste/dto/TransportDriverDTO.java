package com.waste.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class TransportDriverDTO {

    private Long id;

    private String driverName;

    private String gender;

    private String phone;

    private String idCard;

    private String driverLicense;

    private String driverLicenseType;

    private LocalDateTime driverLicenseExpire;

    private String qualificationCert;

    private LocalDateTime qualificationCertExpire;

    private String hazardousCert;

    private LocalDateTime hazardousCertExpire;

    private String escortCert;

    private LocalDateTime escortCertExpire;

    private Integer workYears;

    private Long vehicleId;

    private String vehicleNo;

    private String emergencyContact;

    private String emergencyPhone;

    private String photoUrl;

    private Integer status;

    private String remark;

    private Long enterpriseId;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;
}
