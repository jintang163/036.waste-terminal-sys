package com.waste.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class SyncDataDTO {

    private String syncNo;

    private String syncType;

    private String syncDirection;

    private String deviceId;

    private LocalDateTime syncTime;

    private Long enterpriseId;

    private List<WasteInRecordDTO> wasteInRecords;

    private List<WasteOutRecordDTO> wasteOutRecords;

    private List<TransferOrderDTO> transferOrders;

    private List<InventoryCheckDTO> inventoryChecks;

    private List<WasteContainerDTO> wasteContainers;

    private List<WasteCatalogDTO> wasteCatalogs;

    @Data
    public static class WasteContainerDTO {
        private Long id;
        private String containerCode;
        private String containerType;
        private String containerSpec;
        private String material;
        private java.math.BigDecimal capacity;
        private Integer status;
        private String location;
        private String rfidCode;
        private String offlineId;
    }

    @Data
    public static class WasteCatalogDTO {
        private Long id;
        private String wasteCode;
        private String wasteName;
        private String wasteCategory;
        private String wasteType;
        private String hazardCode;
        private String disposalMethod;
        private String storageRequirement;
        private String safetyMeasures;
        private String description;
        private Integer sortOrder;
        private Integer status;
    }
}
