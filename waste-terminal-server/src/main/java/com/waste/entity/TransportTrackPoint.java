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
@TableName("transport_track_point")
public class TransportTrackPoint extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
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
