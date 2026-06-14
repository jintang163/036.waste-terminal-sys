package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("waste_transfer_order")
public class WasteTransferOrder extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String orderNo;

    private String nationalOrderNo;

    private String orderType;

    private Long generatorUnitId;

    private String generatorUnitName;

    private String generatorUnitCode;

    private Long receiverUnitId;

    private String receiverUnitName;

    private String receiverUnitCode;

    private String receiverLicenseNo;

    private Long transporterId;

    private String transporterName;

    private String transporterLicenseNo;

    private String vehicleNo;

    private String driverName;

    private String driverLicense;

    private String escortName;

    private BigDecimal totalWeight;

    private Integer totalContainers;

    private String wasteDetails;

    private LocalDateTime startTime;

    private LocalDateTime estimateArriveTime;

    private LocalDateTime actualArriveTime;

    private String route;

    private String emergencyContact;

    private String emergencyPhone;

    private Integer status;

    private Integer reportStatus;

    private LocalDateTime reportTime;

    private String qrCode;

    private String signPhoto;

    private Integer signStatus;

    private LocalDateTime signTime;

    private String receiptPhoto;

    private LocalDateTime completeTime;

    private String remark;

    private String offlineId;

    private Long operatorId;

    private String operatorName;

    private Integer syncStatus;

    private String syncFailReason;

    private LocalDateTime syncTime;

    private Long enterpriseId;
}
