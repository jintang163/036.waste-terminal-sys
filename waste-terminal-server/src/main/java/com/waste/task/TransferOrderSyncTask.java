package com.waste.task;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.entity.WasteTransferOrder;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.service.NationalPlatformService;
import com.waste.service.TransferOrderTimelineService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
public class TransferOrderSyncTask {

    @Autowired
    private WasteTransferOrderMapper transferOrderMapper;

    @Autowired
    private NationalPlatformService nationalPlatformService;

    @Autowired
    private TransferOrderTimelineService timelineService;

    @Scheduled(cron = "0 */5 * * * ?")
    @Transactional(rollbackFor = Exception.class)
    public void syncPendingReportOrders() {
        log.info("开始执行待上报联单定时任务");
        try {
            LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteTransferOrder::getStatus, TransferOrderStatusEnum.PENDING_REPORT.getCode());
            wrapper.ne(WasteTransferOrder::getReportStatus, 1);
            wrapper.orderByAsc(WasteTransferOrder::getCreateTime);
            wrapper.last("LIMIT 50");
            List<WasteTransferOrder> orders = transferOrderMapper.selectList(wrapper);

            if (CollUtil.isEmpty(orders)) {
                log.info("没有需要上报的联单");
                return;
            }

            log.info("找到 {} 个待上报联单", orders.size());
            for (WasteTransferOrder order : orders) {
                try {
                    reportOrderToNationalPlatform(order);
                } catch (Exception e) {
                    log.error("上报联单失败, orderNo={}", order.getOrderNo(), e);
                }
            }
        } catch (Exception e) {
            log.error("待上报联单定时任务执行异常", e);
        }
    }

    @Scheduled(cron = "0 */10 * * * ?")
    @Transactional(rollbackFor = Exception.class)
    public void syncTransferOrderStatus() {
        log.info("开始执行联单状态同步定时任务");
        try {
            LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
            wrapper.in(WasteTransferOrder::getStatus, Arrays.asList(
                    TransferOrderStatusEnum.PENDING_TRANSPORT.getCode(),
                    TransferOrderStatusEnum.IN_TRANSIT.getCode(),
                    TransferOrderStatusEnum.ARRIVED.getCode(),
                    TransferOrderStatusEnum.SIGNED.getCode()
            ));
            wrapper.isNotNull(WasteTransferOrder::getNationalOrderNo);
            wrapper.orderByAsc(WasteTransferOrder::getUpdateTime);
            wrapper.last("LIMIT 100");
            List<WasteTransferOrder> orders = transferOrderMapper.selectList(wrapper);

            if (CollUtil.isEmpty(orders)) {
                log.info("没有需要同步状态的联单");
                return;
            }

            log.info("找到 {} 个需要同步状态的联单", orders.size());
            for (WasteTransferOrder order : orders) {
                try {
                    syncOrderStatusFromNationalPlatform(order);
                } catch (Exception e) {
                    log.error("同步联单状态失败, orderNo={}", order.getOrderNo(), e);
                }
            }
        } catch (Exception e) {
            log.error("联单状态同步定时任务执行异常", e);
        }
    }

    @Scheduled(cron = "0 */30 * * * ?")
    @Transactional(rollbackFor = Exception.class)
    public void syncFailedReportOrders() {
        log.info("开始执行上报失败联单重试定时任务");
        try {
            LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteTransferOrder::getStatus, TransferOrderStatusEnum.PENDING_REPORT.getCode());
            wrapper.eq(WasteTransferOrder::getReportStatus, 3);
            wrapper.orderByAsc(WasteTransferOrder::getUpdateTime);
            wrapper.last("LIMIT 20");
            List<WasteTransferOrder> orders = transferOrderMapper.selectList(wrapper);

            if (CollUtil.isEmpty(orders)) {
                log.info("没有需要重试上报的联单");
                return;
            }

            log.info("找到 {} 个需要重试上报的联单", orders.size());
            for (WasteTransferOrder order : orders) {
                try {
                    reportOrderToNationalPlatform(order);
                } catch (Exception e) {
                    log.error("重试上报联单失败, orderNo={}", order.getOrderNo(), e);
                }
            }
        } catch (Exception e) {
            log.error("上报失败联单重试定时任务执行异常", e);
        }
    }

    private void reportOrderToNationalPlatform(WasteTransferOrder order) {
        log.info("开始上报联单到国家平台, orderNo={}", order.getOrderNo());
        TransferOrderStatusEnum fromStatus = TransferOrderStatusEnum.getByCode(order.getStatus());

        order.setReportStatus(2);
        order.setReportTime(LocalDateTime.now());
        transferOrderMapper.updateById(order);

        boolean success = nationalPlatformService.reportTransferOrder(order);
        if (success) {
            String nationalOrderNo = order.getNationalOrderNo();
            if (StrUtil.isBlank(nationalOrderNo)) {
                nationalOrderNo = "GJ" + System.currentTimeMillis();
            }
            order.setNationalOrderNo(nationalOrderNo);
            order.setStatus(TransferOrderStatusEnum.PENDING_TRANSPORT.getCode());
            order.setReportStatus(1);
            order.setReportTime(LocalDateTime.now());
            transferOrderMapper.updateById(order);

            timelineService.addTimeline(
                    order.getId(),
                    order.getOrderNo(),
                    order.getNationalOrderNo(),
                    TransferOrderEventTypeEnum.REPORT_SUCCESS,
                    fromStatus,
                    TransferOrderStatusEnum.PENDING_TRANSPORT,
                    "system",
                    null,
                    null,
                    "联单成功上报国家平台",
                    null,
                    order.getEnterpriseId()
            );
            log.info("联单上报成功, orderNo={}, nationalOrderNo={}", order.getOrderNo(), nationalOrderNo);
        } else {
            order.setReportStatus(3);
            transferOrderMapper.updateById(order);

            timelineService.addTimeline(
                    order.getId(),
                    order.getOrderNo(),
                    order.getNationalOrderNo(),
                    TransferOrderEventTypeEnum.REPORT_FAIL,
                    fromStatus,
                    null,
                    "system",
                    null,
                    null,
                    "联单上报国家平台失败",
                    null,
                    order.getEnterpriseId()
            );
            log.warn("联单上报失败, orderNo={}", order.getOrderNo());
        }
    }

    private void syncOrderStatusFromNationalPlatform(WasteTransferOrder order) {
        log.debug("开始从国家平台同步联单状态, orderNo={}, nationalOrderNo={}",
                order.getOrderNo(), order.getNationalOrderNo());

        Map<String, Object> statusInfo = nationalPlatformService.queryReportStatus(
                "TRANSFER_ORDER", order.getNationalOrderNo());

        if (statusInfo == null || !statusInfo.containsKey("status")) {
            log.debug("未获取到联单状态信息, orderNo={}", order.getOrderNo());
            return;
        }

        Integer remoteStatus = (Integer) statusInfo.get("status");
        if (remoteStatus == null || remoteStatus.equals(order.getStatus())) {
            return;
        }

        TransferOrderStatusEnum currentStatus = TransferOrderStatusEnum.getByCode(order.getStatus());
        TransferOrderStatusEnum targetStatus = TransferOrderStatusEnum.getByCode(remoteStatus);

        if (targetStatus == null || currentStatus == null) {
            return;
        }

        if (!currentStatus.canTransitionTo(targetStatus)) {
            log.warn("联单状态流转不合法, orderNo={}, currentStatus={}, targetStatus={}",
                    order.getOrderNo(), currentStatus.getName(), targetStatus.getName());
            return;
        }

        order.setStatus(targetStatus.getCode());
        updateOrderTimeByStatus(order, targetStatus, statusInfo);
        transferOrderMapper.updateById(order);

        timelineService.addTimeline(
                order.getId(),
                order.getOrderNo(),
                order.getNationalOrderNo(),
                TransferOrderEventTypeEnum.STATUS_SYNC,
                currentStatus,
                targetStatus,
                "system",
                null,
                statusInfo.containsKey("location") ? (String) statusInfo.get("location") : null,
                "定时同步: 状态从 " + currentStatus.getName() + " 变更为 " + targetStatus.getName(),
                com.waste.utils.JsonUtils.toJson(statusInfo),
                order.getEnterpriseId()
        );

        log.info("联单状态同步成功, orderNo={}, {} -> {}",
                order.getOrderNo(), currentStatus.getName(), targetStatus.getName());
    }

    private void updateOrderTimeByStatus(WasteTransferOrder order, TransferOrderStatusEnum status, Map<String, Object> statusInfo) {
        switch (status) {
            case IN_TRANSIT:
                if (order.getStartTime() == null) {
                    order.setStartTime(LocalDateTime.now());
                }
                break;
            case ARRIVED:
                if (order.getActualArriveTime() == null) {
                    order.setActualArriveTime(LocalDateTime.now());
                }
                break;
            case SIGNED:
                order.setSignStatus(1);
                if (order.getSignTime() == null) {
                    order.setSignTime(LocalDateTime.now());
                }
                if (statusInfo.containsKey("signPhoto") && StrUtil.isBlank(order.getSignPhoto())) {
                    order.setSignPhoto((String) statusInfo.get("signPhoto"));
                }
                break;
            case COMPLETED:
                if (order.getCompleteTime() == null) {
                    order.setCompleteTime(LocalDateTime.now());
                }
                if (statusInfo.containsKey("receiptPhoto") && StrUtil.isBlank(order.getReceiptPhoto())) {
                    order.setReceiptPhoto((String) statusInfo.get("receiptPhoto"));
                }
                break;
            default:
                break;
        }
    }
}
