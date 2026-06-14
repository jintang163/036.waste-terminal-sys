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
@TableName("inventory_check_detail")
public class InventoryCheckDetail extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long checkId;

    private String checkOfflineId;

    private Long containerId;

    private String containerCode;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private BigDecimal inventoryWeight;

    private BigDecimal checkWeight;

    private BigDecimal diffWeight;

    private String diffType;

    private Integer isFound;

    private LocalDateTime checkTime;

    private String remark;
}
