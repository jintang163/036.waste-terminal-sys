package com.waste.dto;

import lombok.Data;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class WasteOutRecordDTO {

    private Long id;

    private String outNo;

    private Long transferOrderId;

    @NotNull(message = "容器ID不能为空")
    private Long containerId;

    private String containerCode;

    @NotNull(message = "废物ID不能为空")
    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    @NotNull(message = "重量不能为空")
    private BigDecimal weight;

    private Long receiverUnitId;

    private String receiverUnitName;

    private Long transporterId;

    private String transporterName;

    private String vehicleNo;

    private String driverName;

    private String driverPhone;

    private LocalDateTime outTime;

    private Long operatorId;

    private String operatorName;

    private String remark;

    private Integer status;

    private Integer signStatus;

    private String signPhoto;

    private String receiptPhoto;

    private List<String> receiptPhotoUrls;

    private String offlineId;

    private Long enterpriseId;
}
