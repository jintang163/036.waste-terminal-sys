package com.waste.vo;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class TransferOrderVO {

    private Long id;

    private String orderNo;

    private String nationalOrderNo;

    private String orderType;

    private String orderTypeName;

    private Long generatorUnitId;

    private String generatorUnitName;

    private String generatorUnitCode;

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

    private List<WasteItemVO> wasteDetails;

    private LocalDateTime startTime;

    private LocalDateTime estimateArriveTime;

    private LocalDateTime actualArriveTime;

    private String route;

    private String emergencyContact;

    private String emergencyPhone;

    private Integer status;

    private String statusName;

    private Integer reportStatus;

    private String reportStatusName;

    private LocalDateTime reportTime;

    private String qrCode;

    private String qrCodeBase64;

    private String signPhoto;

    private String receiptPhoto;

    private String remark;

    private Long operatorId;

    private String operatorName;

    private Long enterpriseId;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;

    @Data
    public static class WasteItemVO {
        private Long id;
        private Long wasteId;
        private String wasteCode;
        private String wasteName;
        private String wasteCategory;
        private String hazardCode;
        private BigDecimal weight;
        private Long containerId;
        private String containerCode;
        private String containerType;
    }
}
