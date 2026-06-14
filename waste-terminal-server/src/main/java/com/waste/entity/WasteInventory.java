package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("waste_inventory")
public class WasteInventory extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long containerId;

    private String containerCode;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String hazardCode;

    private BigDecimal weight;

    private BigDecimal inWeight;

    private BigDecimal outWeight;

    private Integer storageDays;

    private Integer storageLimit;

    private LocalDate produceDate;

    private LocalDate inDate;

    private String storageLocation;

    private Integer warnStatus;

    private Integer status;

    private Long enterpriseId;
}
