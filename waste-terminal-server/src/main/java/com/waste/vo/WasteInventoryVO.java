package com.waste.vo;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class WasteInventoryVO {

    private Long id;

    private Long containerId;

    private String containerCode;

    private String containerType;

    private String containerSpec;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String hazardCode;

    private BigDecimal weight;

    private BigDecimal inWeight;

    private BigDecimal outWeight;

    private Integer storageDays;

    private Integer storageLimit;

    private LocalDate produceDate;

    private LocalDate inDate;

    private String storageLocation;

    private Integer warnStatus;

    private String warnStatusName;

    private Integer status;

    private String statusName;

    private Long enterpriseId;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;
}
