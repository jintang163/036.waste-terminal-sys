package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("camera")
public class Camera extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String cameraCode;

    private String cameraName;

    private String cameraType;

    private String brand;

    private String rtspUrl;

    private String httpUrl;

    private String location;

    private String warehouseCode;

    private Integer status;

    private Boolean aiEnabled;

    private String aiTaskId;

    private String snapshotUrl;

    private String resolution;

    private Integer streamType;

    private String username;

    private String password;

    private Long enterpriseId;
}
