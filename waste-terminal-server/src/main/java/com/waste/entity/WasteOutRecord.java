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
@TableName("waste_out_record")
public class WasteOutRecord extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String outNo;

    private Long transferOrderId;

    private Long containerId;

    private String containerCode;

    private Long wasteId;

    private String wasteCode;

    private String wasteName;

    private BigDecimal weight;

    private Long receiverUnitId;

    private String receiverUnitName;

    private Long transporterId;

    private String transporterName;

    private String vehicleNo;

    private String driverName;

    private String driverPhone;

    private LocalDateTime outTime;

    private Long operatorId;

    private String operatorName;

    private String remark;

    private Integer status;

    private Integer signStatus;

    private LocalDateTime signTime;

    private String signPhoto;

    private String receiptPhoto;

    private Integer syncStatus;

    private LocalDateTime syncTime;

    private String offlineId;

    private Long enterpriseId;

    private String faceAuthId;

    private String faceId;

    private String operatorFaceImage;
}
