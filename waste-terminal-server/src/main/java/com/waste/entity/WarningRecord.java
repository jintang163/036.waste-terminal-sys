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
@TableName("warning_record")
public class WarningRecord extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String warningNo;

    private String warningType;

    private Integer warningLevel;

    private String wasteCode;

    private String wasteName;

    private Long containerId;

    private String containerCode;

    private String warningContent;

    private LocalDateTime triggerTime;

    private Integer handleStatus;

    private Long handleUserId;

    private LocalDateTime handleTime;

    private String handleRemark;

    private Integer pushStatus;

    private LocalDateTime pushTime;

    private String pushFailReason;

    private Long enterpriseId;
}
