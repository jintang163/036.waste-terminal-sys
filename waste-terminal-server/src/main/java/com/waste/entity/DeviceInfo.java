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
@TableName("device_info")
public class DeviceInfo extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private String deviceNo;

    private String deviceName;

    private String deviceType;

    private String deviceModel;

    private String manufacturer;

    private String connectType;

    private String macAddress;

    private String serialPort;

    private Integer baudRate;

    private Integer status;

    private LocalDateTime lastConnectTime;

    private Long enterpriseId;

    private String remark;
}
