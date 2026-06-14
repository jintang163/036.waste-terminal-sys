package com.waste.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class WarningRecordDTO {

    private Long id;

    private String warningNo;

    private String warningType;

    private Integer warningLevel;

    private String wasteCode;

    private String wasteName;

    private Long containerId;

    private String containerCode;

    private String warningContent;

    private LocalDateTime triggerTime;

    private Integer handleStatus;

    private Long handleUserId;

    private String handleUserName;

    private LocalDateTime handleTime;

    private String handleRemark;

    private Integer pushStatus;

    private LocalDateTime pushTime;

    private Long enterpriseId;
}
