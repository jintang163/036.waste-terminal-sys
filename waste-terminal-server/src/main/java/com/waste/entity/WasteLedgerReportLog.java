package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("waste_ledger_report_log")
public class WasteLedgerReportLog {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String logNo;

    private Long ledgerId;

    private String ledgerNo;

    private String reportType;

    private Integer reportStatus;

    private LocalDateTime reportTime;

    private String requestPayload;

    private String responsePayload;

    private String failReason;

    private String platformLedgerNo;

    private Long durationMs;

    private Long operatorId;

    private String operatorName;

    private Long enterpriseId;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;
}
