package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("waste_packaging_rule")
public class WastePackagingRule extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String ruleCode;

    private String ruleName;

    private String wasteCategory;

    private String hazardCode;

    private String physicalState;

    private String recommendedContainerType;

    private String recommendedContainerSpec;

    private String recommendedMaterial;

    private BigDecimal recommendedCapacity;

    private BigDecimal maxWeightPerPackage;

    private String sealRequirement;

    private String labelRequirement;

    private String precaution;

    private Integer priority;

    private Integer status;
}
