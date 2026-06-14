package com.waste.dto;

import lombok.Data;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class WasteInRecordDTO {

    private Long id;

    @NotNull(message = "容器ID不能为空")
    private Long containerId;

    private String containerCode;

    @NotNull(message = "废物ID不能为空")
    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String hazardCode;

    @NotNull(message = "重量不能为空")
    private BigDecimal weight;

    private String weightSource;

    private String scaleDevice;

    private LocalDate produceDate;

    private String produceDepartment;

    private String storageLocation;

    private Long operatorId;

    private String operatorName;

    private List<String> photoUrls;

    private String photos;

    private String remark;

    private Integer status;

    private String offlineId;

    private Long enterpriseId;
}
