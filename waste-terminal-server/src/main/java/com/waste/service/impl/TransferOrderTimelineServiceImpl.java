package com.waste.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.entity.TransferOrderTimeline;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;
import com.waste.mapper.TransferOrderTimelineMapper;
import com.waste.service.TransferOrderTimelineService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
public class TransferOrderTimelineServiceImpl implements TransferOrderTimelineService {

    @Autowired
    private TransferOrderTimelineMapper timelineMapper;

    @Override
    public void addTimeline(Long orderId, String orderNo, String nationalOrderNo,
                            TransferOrderEventTypeEnum eventType,
                            TransferOrderStatusEnum fromStatus, TransferOrderStatusEnum toStatus,
                            String operatorName, Long operatorId,
                            String location, String remark, String extraData, Long enterpriseId) {
        try {
            TransferOrderTimeline timeline = new TransferOrderTimeline();
            timeline.setOrderId(orderId);
            timeline.setOrderNo(orderNo);
            timeline.setNationalOrderNo(nationalOrderNo);
            timeline.setEventType(eventType != null ? eventType.getCode() : null);
            timeline.setEventName(eventType != null ? eventType.getName() : null);
            timeline.setFromStatus(fromStatus != null ? fromStatus.getCode() : null);
            timeline.setFromStatusName(fromStatus != null ? fromStatus.getName() : null);
            timeline.setToStatus(toStatus != null ? toStatus.getCode() : null);
            timeline.setToStatusName(toStatus != null ? toStatus.getName() : null);
            timeline.setOperatorName(operatorName);
            timeline.setOperatorId(operatorId);
            timeline.setEventTime(LocalDateTime.now());
            timeline.setLocation(location);
            timeline.setRemark(remark);
            timeline.setExtraData(extraData);
            timeline.setEnterpriseId(enterpriseId);
            timelineMapper.insert(timeline);
            log.info("联单轨迹记录成功, orderNo={}, eventType={}", orderNo, eventType);
        } catch (Exception e) {
            log.error("联单轨迹记录失败, orderNo={}, eventType={}", orderNo, eventType, e);
        }
    }

    @Override
    public List<TransferOrderTimeline> getTimelineByOrderId(Long orderId) {
        LambdaQueryWrapper<TransferOrderTimeline> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransferOrderTimeline::getOrderId, orderId);
        wrapper.orderByAsc(TransferOrderTimeline::getEventTime);
        return timelineMapper.selectList(wrapper);
    }

    @Override
    public List<TransferOrderTimeline> getTimelineByOrderNo(String orderNo) {
        LambdaQueryWrapper<TransferOrderTimeline> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransferOrderTimeline::getOrderNo, orderNo);
        wrapper.orderByAsc(TransferOrderTimeline::getEventTime);
        return timelineMapper.selectList(wrapper);
    }

    @Override
    public List<TransferOrderTimeline> getTimelineByNationalOrderNo(String nationalOrderNo) {
        LambdaQueryWrapper<TransferOrderTimeline> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransferOrderTimeline::getNationalOrderNo, nationalOrderNo);
        wrapper.orderByAsc(TransferOrderTimeline::getEventTime);
        return timelineMapper.selectList(wrapper);
    }
}
