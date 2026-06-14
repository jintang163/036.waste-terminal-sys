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
@TableName("sync_record")
public class SyncRecord extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String syncNo;

    private String syncType;

    private String syncDirection;

    private String deviceId;

    private Integer totalCount;

    private Integer successCount;

    private Integer failCount;

    private LocalDateTime syncTime;

    private Integer syncDuration;

    private Integer status;

    private String failReason;

    private Long operatorId;

    private Long enterpriseId;
}
