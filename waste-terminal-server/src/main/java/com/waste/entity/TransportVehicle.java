package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("transport_vehicle")
public class TransportVehicle extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
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
}
