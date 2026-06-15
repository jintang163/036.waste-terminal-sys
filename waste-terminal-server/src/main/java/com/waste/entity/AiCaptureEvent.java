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
@TableName("ai_capture_event")
public class AiCaptureEvent extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String eventNo;

    private Long cameraId;

    private String cameraCode;

    private String cameraName;

    private String eventType;

    private String eventCategory;

    private Integer confidence;

    private String snapshotPath;

    private String videoClipPath;

    private String detail;

    private LocalDateTime captureTime;

    private Integer handleStatus;

    private Long handleUserId;

    private LocalDateTime handleTime;

    private String handleRemark;

    private Integer pushStatus;

    private LocalDateTime pushTime;

    private String pushFailReason;

    private Long enterpriseId;
}
