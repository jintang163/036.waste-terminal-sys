package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("inventory_check")
public class InventoryCheck extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String checkNo;

    private String checkName;

    private String checkType;

    private LocalDate checkDate;

    private Integer totalContainers;

    private Integer checkedContainers;

    private Integer missingContainers;

    private Integer extraContainers;

    private BigDecimal diffWeight;

    private Integer status;

    private Integer auditStatus;

    private Long auditUserId;

    private LocalDateTime auditTime;

    private String auditRemark;

    private Long operatorId;

    private String operatorName;

    private String remark;

    private Integer syncStatus;

    private String offlineId;

    private Long enterpriseId;
}
