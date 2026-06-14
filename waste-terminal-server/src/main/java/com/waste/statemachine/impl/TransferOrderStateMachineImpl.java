package com.waste.statemachine.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.common.exception.BusinessException;
import com.waste.entity.WasteTransferOrder;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.service.TransferOrderTimelineService;
import com.waste.statemachine.TransferOrderStateMachine;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Slf4j
@Component
public class TransferOrderStateMachineImpl implements TransferOrderStateMachine {

    @Autowired
    private WasteTransferOrderMapper transferOrderMapper;

    @Autowired
    private TransferOrderTimelineService timelineService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public boolean transition(WasteTransferOrder order, TransferOrderEventTypeEnum event, String operatorName, Long operatorId) {
        if (order == null || event == null) {
            throw new BusinessException("参数不能为空");
        }

        TransferOrderStatusEnum currentStatus = TransferOrderStatusEnum.getByCode(order.getStatus());
        if (currentStatus == null) {
            throw new BusinessException("当前联单状态异常");
        }

        TransferOrderStatusEnum targetStatus = getTargetStatus(currentStatus, event);
        if (targetStatus == null) {
            throw new BusinessException("不支持的状态流转: " + currentStatus.getName() + " -> " + event.getName());
        }

        if (!currentStatus.canTransitionTo(targetStatus)) {
            throw new BusinessException("状态流转不合法: " + currentStatus.getName() + " 无法流转到 " + targetStatus.getName());
        }

        TransferOrderStatusEnum fromStatus = currentStatus;
        order.setStatus(targetStatus.getCode());

        switch (event) {
            case SUBMIT:
                order.setReportStatus(0);
                break;
            case REPORT_SUCCESS:
                order.setReportStatus(1);
                order.setReportTime(LocalDateTime.now());
                break;
            case REPORT_FAIL:
                order.setReportStatus(3);
                break;
            case START_TRANSPORT:
                order.setStartTime(LocalDateTime.now());
                break;
            case ARRIVE:
                order.setActualArriveTime(LocalDateTime.now());
                break;
            case SIGN:
                order.setSignStatus(1);
                order.setSignTime(LocalDateTime.now());
                break;
            case COMPLETE:
                order.setCompleteTime(LocalDateTime.now());
                break;
            default:
                break;
        }

        order.setUpdateTime(LocalDateTime.now());
        transferOrderMapper.updateById(order);

        timelineService.addTimeline(
                order.getId(),
                order.getOrderNo(),
                order.getNationalOrderNo(),
                event,
                fromStatus,
                targetStatus,
                operatorName,
                operatorId,
                null,
                event.getDescription(),
                null,
                order.getEnterpriseId()
        );

        log.info("联单状态流转成功, orderNo={}, {} -> {}, event={}",
                order.getOrderNo(), fromStatus.getName(), targetStatus.getName(), event.getName());

        return true;
    }

    @Override
    public boolean canTransition(WasteTransferOrder order, TransferOrderEventTypeEnum event) {
        if (order == null || event == null) {
            return false;
        }
        TransferOrderStatusEnum currentStatus = TransferOrderStatusEnum.getByCode(order.getStatus());
        if (currentStatus == null) {
            return false;
        }
        TransferOrderStatusEnum targetStatus = getTargetStatus(currentStatus, event);
        if (targetStatus == null) {
            return false;
        }
        return currentStatus.canTransitionTo(targetStatus);
    }

    @Override
    public TransferOrderStatusEnum getTargetStatus(TransferOrderStatusEnum currentStatus, TransferOrderEventTypeEnum event) {
        if (currentStatus == null || event == null) {
            return null;
        }
        switch (event) {
            case CREATE:
                return TransferOrderStatusEnum.DRAFT;
            case SUBMIT:
                if (currentStatus == TransferOrderStatusEnum.DRAFT) {
                    return TransferOrderStatusEnum.PENDING_REPORT;
                }
                return null;
            case REPORT_SUCCESS:
                if (currentStatus == TransferOrderStatusEnum.PENDING_REPORT) {
                    return TransferOrderStatusEnum.PENDING_TRANSPORT;
                }
                return null;
            case START_TRANSPORT:
                if (currentStatus == TransferOrderStatusEnum.PENDING_TRANSPORT) {
                    return TransferOrderStatusEnum.IN_TRANSIT;
                }
                return null;
            case ARRIVE:
                if (currentStatus == TransferOrderStatusEnum.IN_TRANSIT) {
                    return TransferOrderStatusEnum.ARRIVED;
                }
                return null;
            case SIGN:
                if (currentStatus == TransferOrderStatusEnum.ARRIVED) {
                    return TransferOrderStatusEnum.SIGNED;
                }
                return null;
            case COMPLETE:
                if (currentStatus == TransferOrderStatusEnum.SIGNED) {
                    return TransferOrderStatusEnum.COMPLETED;
                }
                return null;
            case CANCEL:
                if (currentStatus == TransferOrderStatusEnum.DRAFT
                        || currentStatus == TransferOrderStatusEnum.PENDING_REPORT
                        || currentStatus == TransferOrderStatusEnum.PENDING_TRANSPORT) {
                    return TransferOrderStatusEnum.CANCELLED;
                }
                return null;
            case STATUS_SYNC:
            case WEBHOOK_NOTIFY:
                return null;
            default:
                return null;
        }
    }

    public WasteTransferOrder getOrderByNationalOrderNo(String nationalOrderNo) {
        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteTransferOrder::getNationalOrderNo, nationalOrderNo);
        return transferOrderMapper.selectOne(wrapper);
    }
}
