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
@TableName("platform_report_record")
public class PlatformReportRecord extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String reportNo;

    private String bizType;

    private String bizId;

    private String bizNo;

    private String apiPath;

    private Integer reportStatus;

    private Integer retryCount;

    private Integer maxRetryCount;

    private LocalDateTime firstReportTime;

    private LocalDateTime lastReportTime;

    private LocalDateTime nextRetryTime;

    private String requestPayload;

    private String responsePayload;

    private String failReason;

    private String nationalBizNo;

    private Long enterpriseId;

    private String deviceId;

    private Long durationMs;
}
