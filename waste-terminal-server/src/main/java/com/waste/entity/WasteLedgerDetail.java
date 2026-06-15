package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("waste_ledger_detail")
public class WasteLedgerDetail {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long ledgerId;

    private String ledgerNo;

    private String detailType;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String hazardCode;

    private Long containerId;

    private String containerCode;

    private String recordNo;

    private BigDecimal weight;

    private String changeType;

    private LocalDateTime operateTime;

    private String operatorName;

    private String remark;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;
}
