package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class TransportVehicleDTO {

    private Long id;

    private String vehicleNo;

    private String vehicleType;

    private String vehicleModel;

    private BigDecimal loadWeight;

    private BigDecimal loadVolume;

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

    private LocalDateTime createTime;

    private LocalDateTime updateTime;
}
