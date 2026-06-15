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
@TableName("face_auth_record")
public class FaceAuthRecord extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String authId;

    private Long userId;

    private String username;

    private String realName;

    private String faceId;

    private Double similarity;

    private Integer authStatus;

    private String authType;

    private String businessType;

    private String businessId;

    private String businessNo;

    private String deviceId;

    private String ip;

    private LocalDateTime authTime;

    private Long enterpriseId;

    private String remark;
}
