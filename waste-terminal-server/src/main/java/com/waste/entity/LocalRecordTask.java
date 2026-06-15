package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("local_record_task")
public class LocalRecordTask extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String taskId;

    private Long cameraId;

    private String cameraCode;

    private String cameraName;

    private String triggerType;

    private String triggerId;

    private LocalDateTime startTime;

    private LocalDateTime endTime;

    private Integer durationSeconds;

    private String preSeconds;

    private String postSeconds;

    private String filePath;

    private Long fileSize;

    private Integer status;

    private Integer syncStatus;

    private LocalDateTime syncTime;

    private String deviceId;

    private Long enterpriseId;
}
