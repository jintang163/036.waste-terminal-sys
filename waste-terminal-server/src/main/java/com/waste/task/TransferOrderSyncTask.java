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

    @Autowired
    private com.waste.service.WasteTransferOrderService wasteTransferOrderService;

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
        log.info("开始上报联单到国家平台(含真实联单编号解析), orderNo={}", order.getOrderNo());

        order.setReportStatus(2);
        order.setReportTime(LocalDateTime.now());
        transferOrderMapper.updateById(order);

        Map<String, Object> reportResult = nationalPlatformService.reportElectronicManifestWithResult(order);
        if (reportResult != null && Boolean.TRUE.equals(reportResult.get("success"))) {
            String nationalOrderNo = reportResult.get("nationalOrderNo") != null
                    ? reportResult.get("nationalOrderNo").toString()
                    : order.getNationalOrderNo();
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
                    TransferOrderStatusEnum.PENDING_REPORT,
                    TransferOrderStatusEnum.PENDING_TRANSPORT,
                    "system",
                    null,
                    null,
                    "定时任务上报成功，国家联单号: " + nationalOrderNo,
                    null,
                    order.getEnterpriseId()
            );
            log.info("联单上报成功, orderNo={}, nationalOrderNo={}", order.getOrderNo(), nationalOrderNo);
        } else {
            order.setReportStatus(3);
            transferOrderMapper.updateById(order);

            String failReason = reportResult != null && reportResult.get("message") != null
                    ? reportResult.get("message").toString()
                    : "联单上报国家平台失败";
            timelineService.addTimeline(
                    order.getId(),
                    order.getOrderNo(),
                    order.getNationalOrderNo(),
                    TransferOrderEventTypeEnum.REPORT_FAIL,
                    TransferOrderStatusEnum.PENDING_REPORT,
                    null,
                    "system",
                    null,
                    null,
                    failReason,
                    null,
                    order.getEnterpriseId()
            );
            log.warn("联单上报失败, orderNo={}, reason={}", order.getOrderNo(), failReason);
        }
    }

    private void syncOrderStatusFromNationalPlatform(WasteTransferOrder order) {
        log.debug("开始从国家平台同步联单状态(驱动状态机), orderNo={}, nationalOrderNo={}",
                order.getOrderNo(), order.getNationalOrderNo());

        try {
            boolean synced = wasteTransferOrderService.syncStatusFromRemote(order.getId());
            if (synced) {
                log.info("联单状态同步成功, orderNo={}", order.getOrderNo());
            }
        } catch (Exception e) {
            log.error("同步联单状态异常, orderNo={}", order.getOrderNo(), e);
        }
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
