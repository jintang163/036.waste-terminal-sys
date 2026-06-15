package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("waste_ledger")
public class WasteLedger extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String ledgerNo;

    private String ledgerType;

    private Integer periodYear;

    private Integer periodMonth;

    private LocalDate startDate;

    private LocalDate endDate;

    private Long enterpriseId;

    private String enterpriseName;

    private String enterpriseCode;

    private Integer totalInCount;

    private BigDecimal totalInWeight;

    private Integer totalOutCount;

    private BigDecimal totalOutWeight;

    private BigDecimal beginInventoryWeight;

    private BigDecimal endInventoryWeight;

    private Long fileId;

    private String fileUrl;

    private String fileName;

    private Integer generateStatus;

    private LocalDateTime generateTime;

    private String generateFailReason;

    private Integer reportStatus;

    private LocalDateTime reportTime;

    private String reportFailReason;

    private String platformLedgerNo;

    private Integer retryCount;

    private Long operatorId;

    private String operatorName;

    private String remark;
}
