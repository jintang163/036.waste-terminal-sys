package com.waste.dto;

import lombok.Data;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class TransferOrderDTO {

    private Long id;

    private String orderNo;

    private String nationalOrderNo;

    private String orderType;

    @NotNull(message = "产生单位ID不能为空")
    private Long generatorUnitId;

    private String generatorUnitName;

    private String generatorUnitCode;

    @NotNull(message = "接收单位ID不能为空")
    private Long receiverUnitId;

    private String receiverUnitName;

    private String receiverUnitCode;

    private String receiverLicenseNo;

    private Long transporterId;

    private String transporterName;

    private String transporterLicenseNo;

    private String vehicleNo;

    private String driverName;

    private String driverLicense;

    private String escortName;

    private BigDecimal totalWeight;

    private Integer totalContainers;

    private List<WasteItemDTO> wasteDetails;

    private LocalDateTime startTime;

    private LocalDateTime estimateArriveTime;

    private LocalDateTime actualArriveTime;

    private String route;

    private String emergencyContact;

    private String emergencyPhone;

    private Integer status;

    private Integer reportStatus;

    private String qrCode;

    private String signPhoto;

    private String receiptPhoto;

    private String remark;

    private String offlineId;

    private Long operatorId;

    private String operatorName;

    private Long enterpriseId;

    @Data
    public static class WasteItemDTO {
        private Long wasteId;
        private String wasteCode;
        private String wasteName;
        private String wasteCategory;
        private String hazardCode;
        private BigDecimal weight;
        private Long containerId;
        private String containerCode;
    }
}
