package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class WasteOutReviewDTO {

    private Long id;

    private String reviewNo;

    private Long outRecordId;

    private String outNo;

    private String outOfflineId;

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
