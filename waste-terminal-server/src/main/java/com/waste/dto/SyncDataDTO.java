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

    private List<VehicleDTO> vehicles;

    private List<DriverDTO> drivers;

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

    @Data
    public static class VehicleDTO {
        private Long id;
        private String vehicleNo;
        private String vehicleType;
        private String vehicleModel;
        private java.math.BigDecimal loadWeight;
        private java.math.BigDecimal loadVolume;
        private String ownerUnit;
        private Long ownerUnitId;
        private Long driverId;
        private String driverName;
        private String licensePlateColor;
        private String roadTransportLicense;
        private LocalDateTime roadTransportLicenseExpire;
        private LocalDateTime vehicleLicenseExpire;
        private LocalDateTime insuranceExpire;
        private LocalDateTime inspectionExpire;
        private String gpsTerminalId;
        private String gpsSimNo;
        private Integer isTrackEnabled;
        private String amapServiceId;
        private String amapTerminalId;
        private String amapTrackName;
        private Integer status;
        private String remark;
        private Long enterpriseId;
    }

    @Data
    public static class DriverDTO {
        private Long id;
        private String driverName;
        private String gender;
        private String phone;
        private String idCard;
        private String driverLicense;
        private String driverLicenseType;
        private LocalDateTime driverLicenseExpire;
        private String qualificationCert;
        private LocalDateTime qualificationCertExpire;
        private String hazardousCert;
        private LocalDateTime hazardousCertExpire;
        private String escortCert;
        private LocalDateTime escortCertExpire;
        private Integer workYears;
        private Long vehicleId;
        private String vehicleNo;
        private String emergencyContact;
        private String emergencyPhone;
        private String photoUrl;
        private Integer status;
        private String remark;
        private Long enterpriseId;
    }
}
