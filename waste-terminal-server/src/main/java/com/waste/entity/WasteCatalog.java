package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("waste_catalog")
public class WasteCatalog extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String wasteType;

    private String hazardCode;

    private String disposalMethod;

    private String storageRequirement;

    private String safetyMeasures;

    private String description;

    private Integer sortOrder;

    private Integer status;
}
