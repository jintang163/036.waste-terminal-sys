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
@TableName("transport_track")
public class TransportTrack extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String trackNo;

    private Long transferOrderId;

    private String transferOrderNo;

    private Long vehicleId;

    private String vehicleNo;

    private Long driverId;

    private String driverName;

    private String amapServiceId;

    private String amapTerminalId;

    private String amapTrackId;

    private LocalDateTime startTime;

    private LocalDateTime endTime;

    private String startLocation;

    private BigDecimal startLng;

    private BigDecimal startLat;

    private String endLocation;

    private BigDecimal endLng;

    private BigDecimal endLat;

    private String currentLocation;

    private BigDecimal currentLng;

    private BigDecimal currentLat;

    private LocalDateTime lastGpsTime;

    private String lastUpdateSource;

    private BigDecimal totalDistance;

    private Integer totalDuration;

    private BigDecimal expectedDurationHours;

    private LocalDateTime expectedArrivalTime;

    private Integer pointCount;

    private String trackData;

    private String sourceType;

    private Integer status;

    private Integer offlinePoints;

    private Integer syncedToAmap;

    private Long enterpriseId;
}
