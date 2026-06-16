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
@TableName(value = "operation_log", autoResultMap = true)
public class OperationLog extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String logId;

    private String deviceId;

    private String deviceName;

    private Long userId;

    private String username;

    private Long enterpriseId;

    private String level;

    private String category;

    private String module;

    private String action;

    private String message;

    @TableField(typeHandler = JacksonTypeHandler.class)
    private Map<String, Object> extra;

    private Integer isOffline;

    private Integer syncStatus;

    private LocalDateTime operationTime;

    private LocalDateTime uploadTime;

    private String ipAddress;
}
