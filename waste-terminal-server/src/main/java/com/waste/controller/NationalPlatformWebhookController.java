package com.waste.controller;

import cn.hutool.core.util.StrUtil;
import cn.hutool.crypto.SecureUtil;
import com.waste.common.Result;
import com.waste.dto.NationalPlatformWebhookDTO;
import com.waste.entity.WasteTransferOrder;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.service.TransferOrderTimelineService;
import com.waste.statemachine.TransferOrderStateMachine;
import com.waste.utils.JsonUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Slf4j
@RestController
@RequestMapping("/webhook/national-platform")
public class NationalPlatformWebhookController {

    @Autowired
    private WasteTransferOrderMapper transferOrderMapper;

    @Autowired
    private TransferOrderStateMachine stateMachine;

    @Autowired
    private TransferOrderTimelineService timelineService;

    @Value("${waste.national-platform.app-secret:default_secret}")
    private String appSecret;

    @PostMapping("/transfer-order-status")
    public Result<Void> receiveTransferOrderStatus(@RequestBody NationalPlatformWebhookDTO dto) {
        log.info("接收到国家平台Webhook通知: {}", JsonUtils.toJson(dto));

        try {
            if (!verifySignature(dto)) {
                log.warn("Webhook签名验证失败, nationalOrderNo={}", dto.getNationalOrderNo());
                return Result.fail("签名验证失败");
            }

            WasteTransferOrder order = findOrder(dto);
            if (order == null) {
                log.warn("未找到对应联单, nationalOrderNo={}, orderNo={}", dto.getNationalOrderNo(), dto.getOrderNo());
                return Result.fail("未找到对应联单");
            }

            TransferOrderEventTypeEnum eventType = convertEventType(dto.getEventType());
            if (eventType == null) {
                log.warn("未知的事件类型: {}, nationalOrderNo={}", dto.getEventType(), dto.getNationalOrderNo());
                eventType = TransferOrderEventTypeEnum.WEBHOOK_NOTIFY;
            }

            if (dto.getStatus() != null && !dto.getStatus().equals(order.getStatus())) {
                TransferOrderStatusEnum targetStatus = TransferOrderStatusEnum.getByCode(dto.getStatus());
                if (targetStatus != null) {
                    TransferOrderStatusEnum currentStatus = TransferOrderStatusEnum.getByCode(order.getStatus());
                    if (currentStatus != null && currentStatus.canTransitionTo(targetStatus)) {
                        order.setStatus(targetStatus.getCode());
                        updateOrderByStatus(order, targetStatus, dto);
                        transferOrderMapper.updateById(order);

                        timelineService.addTimeline(
                                order.getId(),
                                order.getOrderNo(),
                                order.getNationalOrderNo(),
                                eventType,
                                currentStatus,
                                targetStatus,
                                dto.getOperator(),
                                null,
                                dto.getLocation(),
                                dto.getRemark(),
                                JsonUtils.toJson(dto),
                                order.getEnterpriseId()
                        );

                        log.info("Webhook处理成功, orderNo={}, status: {} -> {}",
                                order.getOrderNo(), currentStatus.getName(), targetStatus.getName());
                    } else {
                        log.warn("状态流转不合法, orderNo={}, currentStatus={}, targetStatus={}",
                                order.getOrderNo(), order.getStatus(), dto.getStatus());
                        timelineService.addTimeline(
                                order.getId(),
                                order.getOrderNo(),
                                order.getNationalOrderNo(),
                                eventType,
                                currentStatus,
                                null,
                                dto.getOperator(),
                                null,
                                dto.getLocation(),
                                "Webhook通知: " + dto.getRemark() + " (状态未变更)",
                                JsonUtils.toJson(dto),
                                order.getEnterpriseId()
                        );
                    }
                }
            } else {
                timelineService.addTimeline(
                        order.getId(),
                        order.getOrderNo(),
                        order.getNationalOrderNo(),
                        eventType,
                        TransferOrderStatusEnum.getByCode(order.getStatus()),
                        null,
                        dto.getOperator(),
                        null,
                        dto.getLocation(),
                        dto.getRemark(),
                        JsonUtils.toJson(dto),
                        order.getEnterpriseId()
                );
            }

            return Result.success();
        } catch (Exception e) {
            log.error("处理Webhook通知异常", e);
            return Result.fail("处理失败: " + e.getMessage());
        }
    }

    private boolean verifySignature(NationalPlatformWebhookDTO dto) {
        if (StrUtil.isBlank(dto.getSignature())) {
            return false;
        }
        String signStr = appSecret + dto.getTimestamp() + dto.getNonce() + dto.getNationalOrderNo() + dto.getEventType();
        String calculatedSign = SecureUtil.sha256(signStr);
        return calculatedSign.equalsIgnoreCase(dto.getSignature());
    }

    private WasteTransferOrder findOrder(NationalPlatformWebhookDTO dto) {
        if (StrUtil.isNotBlank(dto.getNationalOrderNo())) {
            return transferOrderMapper.selectOne(
                    new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<WasteTransferOrder>()
                            .eq(WasteTransferOrder::getNationalOrderNo, dto.getNationalOrderNo())
            );
        }
        if (StrUtil.isNotBlank(dto.getOrderNo())) {
            return transferOrderMapper.selectOne(
                    new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<WasteTransferOrder>()
                            .eq(WasteTransferOrder::getOrderNo, dto.getOrderNo())
            );
        }
        return null;
    }

    private TransferOrderEventTypeEnum convertEventType(String eventType) {
        if (StrUtil.isBlank(eventType)) {
            return null;
        }
        switch (eventType.toUpperCase()) {
            case "SUBMIT":
            case "REPORT":
                return TransferOrderEventTypeEnum.SUBMIT;
            case "REPORT_SUCCESS":
                return TransferOrderEventTypeEnum.REPORT_SUCCESS;
            case "REPORT_FAIL":
                return TransferOrderEventTypeEnum.REPORT_FAIL;
            case "START_TRANSPORT":
            case "TRANSPORT_START":
                return TransferOrderEventTypeEnum.START_TRANSPORT;
            case "ARRIVE":
            case "TRANSPORT_ARRIVE":
                return TransferOrderEventTypeEnum.ARRIVE;
            case "SIGN":
            case "RECEIVE":
                return TransferOrderEventTypeEnum.SIGN;
            case "COMPLETE":
            case "FINISH":
                return TransferOrderEventTypeEnum.COMPLETE;
            case "CANCEL":
                return TransferOrderEventTypeEnum.CANCEL;
            default:
                return null;
        }
    }

    private void updateOrderByStatus(WasteTransferOrder order, TransferOrderStatusEnum status, NationalPlatformWebhookDTO dto) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
        switch (status) {
            case IN_TRANSIT:
                if (StrUtil.isNotBlank(dto.getEventTime())) {
                    try {
                        order.setStartTime(LocalDateTime.parse(dto.getEventTime(), formatter));
                    } catch (Exception ignored) {
                        order.setStartTime(LocalDateTime.now());
                    }
                } else {
                    order.setStartTime(LocalDateTime.now());
                }
                break;
            case ARRIVED:
                if (StrUtil.isNotBlank(dto.getEventTime())) {
                    try {
                        order.setActualArriveTime(LocalDateTime.parse(dto.getEventTime(), formatter));
                    } catch (Exception ignored) {
                        order.setActualArriveTime(LocalDateTime.now());
                    }
                } else {
                    order.setActualArriveTime(LocalDateTime.now());
                }
                break;
            case SIGNED:
                order.setSignStatus(1);
                if (StrUtil.isNotBlank(dto.getEventTime())) {
                    try {
                        order.setSignTime(LocalDateTime.parse(dto.getEventTime(), formatter));
                    } catch (Exception ignored) {
                        order.setSignTime(LocalDateTime.now());
                    }
                } else {
                    order.setSignTime(LocalDateTime.now());
                }
                if (StrUtil.isNotBlank(dto.getSignPhoto())) {
                    order.setSignPhoto(dto.getSignPhoto());
                }
                break;
            case COMPLETED:
                order.setCompleteTime(LocalDateTime.now());
                if (StrUtil.isNotBlank(dto.getReceiptPhoto())) {
                    order.setReceiptPhoto(dto.getReceiptPhoto());
                }
                break;
            default:
                break;
        }
    }
}
