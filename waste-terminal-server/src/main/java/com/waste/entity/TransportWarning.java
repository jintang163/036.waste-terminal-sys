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
@TableName("transport_warning")
public class TransportWarning extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
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
}
