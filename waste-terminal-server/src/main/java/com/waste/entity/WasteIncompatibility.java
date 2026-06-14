package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("waste_incompatibility")
public class WasteIncompatibility extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String wasteCodeA;

    private String wasteNameA;

    private String wasteCategoryA;

    private String wasteCodeB;

    private String wasteNameB;

    private String wasteCategoryB;

    private Integer incompatibilityLevel;

    private String reactionType;

    private String hazardDescription;

    private String emergencyMeasure;

    private String separationRequirement;

    private Integer status;
}
