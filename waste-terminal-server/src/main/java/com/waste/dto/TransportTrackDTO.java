package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class TransportTrackDTO {

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

    private Integer pointCount;

    private String trackData;

    private String sourceType;

    private Integer status;

    private Integer offlinePoints;

    private Integer syncedToAmap;

    private Long enterpriseId;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;

    private List<TrackPointDTO> trackPoints;

    @Data
    public static class TrackPointDTO {
        private Long id;
        private String pointNo;
        private Long trackId;
        private String trackNo;
        private Long transferOrderId;
        private Long vehicleId;
        private String vehicleNo;
        private Long driverId;
        private BigDecimal lng;
        private BigDecimal lat;
        private String location;
        private BigDecimal speed;
        private Integer direction;
        private BigDecimal altitude;
        private BigDecimal accuracy;
        private LocalDateTime gpsTime;
        private String sourceType;
        private Integer isOffline;
        private Integer synced;
        private Integer syncedToAmap;
        private String extraData;
        private Long enterpriseId;
        private LocalDateTime createTime;
    }
}
