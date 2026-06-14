package com.waste.service;

import com.waste.entity.TransferOrderTimeline;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;

import java.util.List;

public interface TransferOrderTimelineService {

    void addTimeline(Long orderId, String orderNo, String nationalOrderNo,
                     TransferOrderEventTypeEnum eventType,
                     TransferOrderStatusEnum fromStatus, TransferOrderStatusEnum toStatus,
                     String operatorName, Long operatorId,
                     String location, String remark, String extraData, Long enterpriseId);

    List<TransferOrderTimeline> getTimelineByOrderId(Long orderId);

    List<TransferOrderTimeline> getTimelineByOrderNo(String orderNo);

    List<TransferOrderTimeline> getTimelineByNationalOrderNo(String nationalOrderNo);
}
