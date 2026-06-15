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
@TableName("waste_in_record")
public class WasteInRecord extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String inNo;

    private Long containerId;

    private String containerCode;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String hazardCode;

    private BigDecimal weight;

    private String weightSource;

    private String scaleDevice;

    private LocalDate produceDate;

    private String produceDepartment;

    private String storageLocation;

    private Long operatorId;

    private String operatorName;

    private String photos;

    private String remark;

    private Integer status;

    private Integer syncStatus;

    private LocalDateTime syncTime;

    private String syncFailReason;

    private String offlineId;

    private Long enterpriseId;

    private String faceAuthId;

    private String faceId;

    private String operatorFaceImage;
}
