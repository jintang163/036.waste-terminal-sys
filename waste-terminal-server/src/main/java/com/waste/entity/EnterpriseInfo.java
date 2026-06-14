package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("enterprise_info")
public class EnterpriseInfo extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String enterpriseName;

    private String enterpriseCode;

    private String legalPerson;

    private String contactPerson;

    private String contactPhone;

    private String address;

    private String province;

    private String city;

    private String district;

    private String businessLicense;

    private String wasteLicense;

    private LocalDate licenseExpireDate;

    private BigDecimal storageCapacity;

    private BigDecimal storageUsed;

    private Integer status;
}
