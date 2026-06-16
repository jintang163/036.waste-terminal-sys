package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.extension.handlers.JacksonTypeHandler;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;
import java.util.Map;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName(value = "device_heartbeat_log", autoResultMap = true)
public class DeviceHeartbeatLog extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String deviceId;

    private String deviceName;

    private String deviceModel;

    private String platform;

    private String osVersion;

    private Long userId;

    private String username;

    private Long enterpriseId;

    private String networkType;

    private Integer batteryLevel;

    @TableField(typeHandler = JacksonTypeHandler.class)
    private Map<String, Object> storageInfo;

    @TableField(typeHandler = JacksonTypeHandler.class)
    private Map<String, Object> bluetoothInfo;

    private String appVersion;

    private String buildNumber;

    private LocalDateTime heartbeatTime;
}
