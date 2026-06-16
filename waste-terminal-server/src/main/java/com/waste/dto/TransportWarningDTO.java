package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class TransportWarningDTO {

    private Long id;

    private String warningNo;

    private String warningType;

    private Integer warningLevel;

    private Long transferOrderId;

    private String transferOrderNo;

    private Long vehicleId;

    private String vehicleNo;

    private Long driverId;

    private String driverName;

    private Long trackId;

    private String warningContent;

    private LocalDateTime triggerTime;

    private BigDecimal triggerValue;

    private BigDecimal thresholdValue;

    private Integer handleStatus;

    private Long handleUserId;

    private String handleUserName;

    private LocalDateTime handleTime;

    private String handleRemark;

    private Integer pushStatus;

    private LocalDateTime pushTime;

    private String pushFailReason;

    private Integer warningCount;

    private LocalDateTime lastWarningTime;

    private Long enterpriseId;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;
}
