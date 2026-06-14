package com.waste.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.waste.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("sys_file")
public class SysFile extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String fileName;

    private String fileUrl;

    private Long fileSize;

    private String fileType;

    private String fileExt;

    private String storageType;

    private String bucketName;

    private String objectKey;

    private String md5;

    private String bizType;

    private String bizId;

    private Long uploadUserId;

    private Long enterpriseId;
}
