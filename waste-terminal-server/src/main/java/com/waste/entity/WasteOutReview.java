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
@TableName("waste_out_review")
public class WasteOutReview extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String reviewNo;

    private Long outRecordId;

    private String outNo;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private BigDecimal weight;

    private String containerCode;

    private Long operatorId;

    private String operatorName;

    private Long reviewerId;

    private String reviewerName;

    private String reviewType;

    private Integer reviewResult;

    private LocalDateTime reviewTime;

    private String reviewRemark;

    private String reviewerFaceAuthId;

    private String reviewerFaceId;

    private String reviewerFaceImage;

    private String reviewQrCode;

    private Integer syncStatus;

    private LocalDateTime syncTime;

    private String offlineId;

    private Long enterpriseId;
}
