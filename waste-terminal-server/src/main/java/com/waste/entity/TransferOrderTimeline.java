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
@TableName("transfer_order_timeline")
public class TransferOrderTimeline extends BaseEntity {

    private static final long serialVersionUID = 1L;

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long orderId;

    private String orderNo;

    private String nationalOrderNo;

    private Integer eventType;

    private String eventName;

    private Integer fromStatus;

    private String fromStatusName;

    private Integer toStatus;

    private String toStatusName;

    private String operatorName;

    private Long operatorId;

    private LocalDateTime eventTime;

    private String location;

    private String remark;

    private String extraData;

    private Long enterpriseId;
}
