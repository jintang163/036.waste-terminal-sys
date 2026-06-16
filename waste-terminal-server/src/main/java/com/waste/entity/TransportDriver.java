package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("transport_driver")
public class TransportDriver extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
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
}
