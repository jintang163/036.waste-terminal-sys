package com.waste.mq;

import cn.hutool.core.util.StrUtil;
import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteTransferOrder;
import com.waste.entity.WarningRecord;
import com.waste.entity.WasteInventory;
import com.waste.entity.EnterpriseInfo;
import com.waste.mapper.WasteInRecordMapper;
import com.waste.mapper.WasteOutRecordMapper;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.mapper.WarningRecordMapper;
import com.waste.mapper.WasteInventoryMapper;
import com.waste.mapper.EnterpriseInfoMapper;
import com.waste.service.NationalPlatformService;
import com.waste.service.PushNotificationService;
import com.waste.service.WasteInRecordService;
import com.waste.utils.JsonUtils;
import lombok.extern.slf4j.Slf4j;
import org.apache.rocketmq.spring.annotation.RocketMQMessageListener;
import org.apache.rocketmq.spring.core.RocketMQListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
public class WasteMqConsumer {

    private static final int MAX_CONSUME_RETRY_TIMES = 3;

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @Autowired
    private WasteTransferOrderMapper wasteTransferOrderMapper;

    @Autowired
    private WarningRecordMapper warningRecordMapper;

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private EnterpriseInfoMapper enterpriseInfoMapper;

    @Autowired
    private NationalPlatformService nationalPlatformService;

    @Autowired
    private MqIdempotentHandler mqIdempotentHandler;

    @Autowired
    private DeadLetterQueueHandler deadLetterQueueHandler;

    @Autowired(required = false)
    private WasteInRecordService wasteInRecordService;

    @Autowired
    private PushNotificationService pushNotificationService;

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.WASTE_IN_TOPIC,
            consumerGroup = "waste-in-consumer-group",
            selectorExpression = "*"
    )
    public class WasteInConsumer implements RocketMQListener<String> {

        @Override
        public void onMessage(String message) {
            processMessage(WasteMqProducer.WASTE_IN_TOPIC, message, this::processWasteInMessage);
        }

        private void processWasteInMessage(String topic, String tag, Map<String, Object> payload,
                                            String bizKey, String bizType, String msgId, int retryCount) {
            Long recordId = extractIdFromPayload(payload);
            log.info("消费入库记录消息, recordId={}, tag={}, retryCount={}", recordId, tag, retryCount);

            try {
                WasteInRecord record = getWasteInRecord(recordId);
                if (record == null) {
                    log.warn("入库记录不存在, recordId={}", recordId);
                    return;
                }

                if (WasteMqProducer.TAG_REPORT.equals(tag)) {
                    handleWasteInReport(record);
                } else if (WasteMqProducer.TAG_SYNC.equals(tag)) {
                    handleWasteInSync(record);
                } else if (WasteMqProducer.TAG_CREATE.equals(tag)) {
                    handleWasteInCreate(record);
                } else if (WasteMqProducer.TAG_UPDATE.equals(tag)) {
                    handleWasteInUpdate(record);
                }

            } catch (Exception e) {
                log.error("处理入库记录消息异常, recordId={}, retryCount={}", recordId, retryCount, e);
                throw new RuntimeException("处理入库记录消息失败: " + e.getMessage(), e);
            }
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.WASTE_OUT_TOPIC,
            consumerGroup = "waste-out-consumer-group",
            selectorExpression = "*"
    )
    public class WasteOutConsumer implements RocketMQListener<String> {

        @Override
        public void onMessage(String message) {
            processMessage(WasteMqProducer.WASTE_OUT_TOPIC, message, this::processWasteOutMessage);
        }

        private void processWasteOutMessage(String topic, String tag, Map<String, Object> payload,
                                             String bizKey, String bizType, String msgId, int retryCount) {
            Long recordId = extractIdFromPayload(payload);
            log.info("消费出库记录消息, recordId={}, tag={}, retryCount={}", recordId, tag, retryCount);

            try {
                WasteOutRecord record = getWasteOutRecord(recordId);
                if (record == null) {
                    log.warn("出库记录不存在, recordId={}", recordId);
                    return;
                }

                if (WasteMqProducer.TAG_REPORT.equals(tag)) {
                    handleWasteOutReport(record);
                } else if (WasteMqProducer.TAG_SYNC.equals(tag)) {
                    handleWasteOutSync(record);
                } else if (WasteMqProducer.TAG_CREATE.equals(tag)) {
                    handleWasteOutCreate(record);
                } else if (WasteMqProducer.TAG_UPDATE.equals(tag)) {
                    handleWasteOutUpdate(record);
                }

            } catch (Exception e) {
                log.error("处理出库记录消息异常, recordId={}, retryCount={}", recordId, retryCount, e);
                throw new RuntimeException("处理出库记录消息失败: " + e.getMessage(), e);
            }
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.TRANSFER_ORDER_TOPIC,
            consumerGroup = "waste-transfer-order-consumer-group",
            selectorExpression = "*"
    )
    public class TransferOrderConsumer implements RocketMQListener<String> {

        @Override
        public void onMessage(String message) {
            processMessage(WasteMqProducer.TRANSFER_ORDER_TOPIC, message, this::processTransferOrderMessage);
        }

        private void processTransferOrderMessage(String topic, String tag, Map<String, Object> payload,
                                                  String bizKey, String bizType, String msgId, int retryCount) {
            Long orderId = extractIdFromPayload(payload);
            log.info("消费转移联单消息, orderId={}, tag={}, retryCount={}", orderId, tag, retryCount);

            try {
                WasteTransferOrder order = getWasteTransferOrder(orderId);
                if (order == null) {
                    log.warn("转移联单不存在, orderId={}", orderId);
                    return;
                }

                if (WasteMqProducer.TAG_REPORT.equals(tag)) {
                    handleTransferOrderReport(order);
                } else if (WasteMqProducer.TAG_SYNC.equals(tag)) {
                    handleTransferOrderSync(order);
                } else if (WasteMqProducer.TAG_CREATE.equals(tag)) {
                    handleTransferOrderCreate(order);
                } else if (WasteMqProducer.TAG_UPDATE.equals(tag)) {
                    handleTransferOrderUpdate(order);
                }

            } catch (Exception e) {
                log.error("处理转移联单消息异常, orderId={}, retryCount={}", orderId, retryCount, e);
                throw new RuntimeException("处理转移联单消息失败: " + e.getMessage(), e);
            }
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.SCALE_DATA_TOPIC,
            consumerGroup = "scale-data-consumer-group"
    )
    public class ScaleDataConsumer implements RocketMQListener<String> {

        @Override
        public void onMessage(String message) {
            processMessage(WasteMqProducer.SCALE_DATA_TOPIC, message, this::processScaleDataMessage);
        }

        private void processScaleDataMessage(String topic, String tag, Map<String, Object> payload,
                                              String bizKey, String bizType, String msgId, int retryCount) {
            log.info("消费地磅重量数据消息, payload={}, retryCount={}", payload, retryCount);
            try {
                handleScaleData(payload);
            } catch (Exception e) {
                log.error("处理地磅数据消息异常, retryCount={}", retryCount, e);
                throw new RuntimeException("处理地磅数据消息失败: " + e.getMessage(), e);
            }
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.WARNING_TOPIC,
            consumerGroup = "warning-push-consumer-group",
            selectorExpression = "*"
    )
    public class WarningPushConsumer implements RocketMQListener<String> {

        @Override
        public void onMessage(String message) {
            processMessage(WasteMqProducer.WARNING_TOPIC, message, this::processWarningMessage);
        }

        private void processWarningMessage(String topic, String tag, Map<String, Object> payload,
                                            String bizKey, String bizType, String msgId, int retryCount) {
            log.info("消费预警推送消息, payload={}, retryCount={}", payload, retryCount);
            try {
                WarningRecord warningRecord = parseWarningRecord(payload);
                if (warningRecord == null) {
                    log.warn("预警消息解析失败, payload={}", payload);
                    return;
                }

                log.info("开始处理预警推送, warningNo={}, warningType={}",
                        warningRecord.getWarningNo(), warningRecord.getWarningType());

                handleWarningPush(warningRecord);

            } catch (Exception e) {
                log.error("处理预警推送消息异常, retryCount={}", retryCount, e);
                throw new RuntimeException("处理预警推送消息失败: " + e.getMessage(), e);
            }
        }
    }

    @FunctionalInterface
    private interface MessageProcessor {
        void process(String topic, String tag, Map<String, Object> payload,
                      String bizKey, String bizType, String msgId, int retryCount);
    }

    private void processMessage(String topic, String message, MessageProcessor processor) {
        String msgId = null;
        String bizKey = null;
        String bizType = null;
        String tag = null;
        int retryCount = 0;
        Map<String, Object> payload = null;

        try {
            payload = JsonUtils.parseMap(message);
            
            msgId = getHeader(payload, WasteMqProducer.HEADER_MSG_ID);
            bizKey = getHeader(payload, WasteMqProducer.HEADER_BIZ_KEY);
            bizType = getHeader(payload, WasteMqProducer.HEADER_BIZ_TYPE);
            tag = getHeader(payload, "rocketmq_TAGS");
            String retryCountStr = getHeader(payload, WasteMqProducer.HEADER_RETRY_COUNT);
            if (StrUtil.isNotBlank(retryCountStr)) {
                retryCount = Integer.parseInt(retryCountStr);
            }

            log.info("接收到RocketMQ消息, topic={}, tag={}, msgId={}, bizKey={}, bizType={}, retryCount={}",
                    topic, tag, msgId, bizKey, bizType, retryCount);

            if (StrUtil.isBlank(bizKey)) {
                bizKey = msgId;
            }

            if (!mqIdempotentHandler.checkAndMarkConsuming(bizKey)) {
                log.warn("消息幂等性校验不通过，跳过消费, topic={}, bizKey={}", topic, bizKey);
                return;
            }

            processor.process(topic, tag, payload, bizKey, bizType, msgId, retryCount);

            mqIdempotentHandler.markConsumed(bizKey);
            log.info("消息消费成功, topic={}, tag={}, bizKey={}", topic, tag, bizKey);

        } catch (Exception e) {
            log.error("消息消费失败, topic={}, tag={}, msgId={}, bizKey={}, retryCount={}",
                    topic, tag, msgId, bizKey, retryCount, e);

            if (bizKey != null) {
                mqIdempotentHandler.markConsumedFailed(bizKey);
            }

            if (retryCount >= MAX_CONSUME_RETRY_TIMES) {
                log.error("消息消费达到最大重试次数{}, 进入死信队列, topic={}, bizKey={}",
                        MAX_CONSUME_RETRY_TIMES, topic, bizKey);
                deadLetterQueueHandler.handleDeadLetter(topic, tag, msgId, bizKey, bizType,
                        message, e.getMessage());
            } else {
                log.warn("消息消费失败, 将进行第{}次重试, topic={}, bizKey={}",
                        retryCount + 1, topic, bizKey);
                throw new RuntimeException("消息消费失败，等待重试", e);
            }
        }
    }

    private String getHeader(Map<String, Object> payload, String key) {
        if (payload == null) {
            return null;
        }
        Object headersObj = payload.get("headers");
        if (headersObj instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> headers = (Map<String, Object>) headersObj;
            Object value = headers.get(key);
            if (value != null) {
                return value.toString();
            }
        }
        Object value = payload.get(key);
        return value != null ? value.toString() : null;
    }

    private Long extractIdFromPayload(Map<String, Object> payload) {
        if (payload == null) {
            return null;
        }
        Object idObj = payload.get("id");
        if (idObj != null) {
            if (idObj instanceof Number) {
                return ((Number) idObj).longValue();
            }
            try {
                return Long.parseLong(idObj.toString());
            } catch (NumberFormatException e) {
                log.warn("解析ID失败, id={}", idObj);
            }
        }
        return null;
    }

    private WasteInRecord getWasteInRecord(Long id) {
        if (id == null) {
            return null;
        }
        return wasteInRecordMapper.selectById(id);
    }

    private WasteOutRecord getWasteOutRecord(Long id) {
        if (id == null) {
            return null;
        }
        return wasteOutRecordMapper.selectById(id);
    }

    private WasteTransferOrder getWasteTransferOrder(Long id) {
        if (id == null) {
            return null;
        }
        return wasteTransferOrderMapper.selectById(id);
    }

    private WarningRecord parseWarningRecord(Map<String, Object> payload) {
        if (payload == null) {
            return null;
        }
        try {
            return JsonUtils.parse(JsonUtils.toJson(payload), WarningRecord.class);
        } catch (Exception e) {
            log.error("解析预警记录失败", e);
            return null;
        }
    }

    @Async
    private void handleWasteInReport(WasteInRecord record) {
        try {
            log.info("【异步上报】开始上报入库记录到国家环保平台, inNo={}", record.getInNo());
            
            if (record.getSyncStatus() != null && record.getSyncStatus() == 1) {
                log.info("【异步上报】入库记录已上报，跳过重复上报, inNo={}", record.getInNo());
                return;
            }

            record.setSyncStatus(3);
            record.setSyncTime(LocalDateTime.now());
            wasteInRecordMapper.updateById(record);

            boolean success = nationalPlatformService.reportWasteIn(record);
            if (success) {
                record.setSyncStatus(1);
                record.setSyncFailReason(null);
                log.info("【异步上报】入库记录上报成功, inNo={}", record.getInNo());
            } else {
                record.setSyncStatus(2);
                record.setSyncFailReason("国家平台上报失败");
                log.warn("【异步上报】入库记录上报失败, inNo={}", record.getInNo());
            }
            wasteInRecordMapper.updateById(record);
            log.info("【异步上报】入库记录上报处理完成, recordId={}, success={}", record.getId(), success);
        } catch (Exception e) {
            log.error("【异步上报】入库记录上报异常, recordId={}", record.getId(), e);
            record.setSyncStatus(2);
            record.setSyncFailReason(e.getMessage());
            wasteInRecordMapper.updateById(record);
            throw new RuntimeException("入库记录上报异常", e);
        }
    }

    private void handleWasteInSync(WasteInRecord record) {
        log.info("执行入库记录数据同步, recordId={}, inNo={}", record.getId(), record.getInNo());
        try {
            if (record.getStatus() == null || record.getStatus() == 0) {
                if (wasteInRecordService != null) {
                    wasteInRecordService.confirm(record.getId());
                    log.info("入库记录自动确认完成, recordId={}, inNo={}", record.getId(), record.getInNo());
                }
            }
        } catch (Exception e) {
            log.error("入库记录同步处理异常, recordId={}", record.getId(), e);
        }
    }

    private void handleWasteInCreate(WasteInRecord record) {
        log.info("执行入库记录创建后处理, recordId={}, inNo={}", record.getId(), record.getInNo());
        try {
            updateEnterpriseStorage(record.getEnterpriseId());
        } catch (Exception e) {
            log.error("入库记录创建后处理异常, recordId={}", record.getId(), e);
        }
    }

    private void handleWasteInUpdate(WasteInRecord record) {
        log.info("执行入库记录更新后处理, recordId={}, inNo={}", record.getId(), record.getInNo());
    }

    @Async
    private void handleWasteOutReport(WasteOutRecord record) {
        try {
            log.info("【异步上报】开始上报出库记录到国家环保平台, outNo={}", record.getOutNo());
            
            if (record.getSyncStatus() != null && record.getSyncStatus() == 1) {
                log.info("【异步上报】出库记录已上报，跳过重复上报, outNo={}", record.getOutNo());
                return;
            }

            record.setSyncStatus(3);
            record.setSyncTime(LocalDateTime.now());
            wasteOutRecordMapper.updateById(record);

            boolean success = nationalPlatformService.reportWasteOut(record);
            if (success) {
                record.setSyncStatus(1);
                record.setSyncFailReason(null);
                log.info("【异步上报】出库记录上报成功, outNo={}", record.getOutNo());
            } else {
                record.setSyncStatus(2);
                record.setSyncFailReason("国家平台上报失败");
                log.warn("【异步上报】出库记录上报失败, outNo={}", record.getOutNo());
            }
            wasteOutRecordMapper.updateById(record);
            log.info("【异步上报】出库记录上报处理完成, recordId={}, success={}", record.getId(), success);
        } catch (Exception e) {
            log.error("【异步上报】出库记录上报异常, recordId={}", record.getId(), e);
            record.setSyncStatus(2);
            record.setSyncFailReason(e.getMessage());
            wasteOutRecordMapper.updateById(record);
            throw new RuntimeException("出库记录上报异常", e);
        }
    }

    private void handleWasteOutSync(WasteOutRecord record) {
        log.info("执行出库记录数据同步, recordId={}, outNo={}", record.getId(), record.getOutNo());
        try {
            updateInventoryAfterOut(record);
            updateEnterpriseStorage(record.getEnterpriseId());
        } catch (Exception e) {
            log.error("出库记录同步处理异常, recordId={}", record.getId(), e);
        }
    }

    private void handleWasteOutCreate(WasteOutRecord record) {
        log.info("执行出库记录创建后处理, recordId={}, outNo={}", record.getId(), record.getOutNo());
        try {
            updateInventoryAfterOut(record);
            updateEnterpriseStorage(record.getEnterpriseId());
        } catch (Exception e) {
            log.error("出库记录创建后处理异常, recordId={}", record.getId(), e);
        }
    }

    private void handleWasteOutUpdate(WasteOutRecord record) {
        log.info("执行出库记录更新后处理, recordId={}, outNo={}", record.getId(), record.getOutNo());
    }

    @Async
    private void handleTransferOrderReport(WasteTransferOrder order) {
        try {
            log.info("【异步上报】开始上报转移联单到国家环保平台, orderNo={}", order.getOrderNo());
            
            if (order.getReportStatus() != null && order.getReportStatus() == 1) {
                log.info("【异步上报】转移联单已上报，跳过重复上报, orderNo={}", order.getOrderNo());
                return;
            }

            order.setReportStatus(3);
            order.setReportTime(LocalDateTime.now());
            wasteTransferOrderMapper.updateById(order);

            boolean success = nationalPlatformService.reportTransferOrder(order);
            if (success) {
                order.setReportStatus(1);
                order.setReportTime(LocalDateTime.now());
                if (StrUtil.isBlank(order.getNationalOrderNo())) {
                    order.setNationalOrderNo(nationalPlatformService.getNationalPlatformBizNo(order.getOrderNo()));
                }
                order.setSyncFailReason(null);
                log.info("【异步上报】转移联单上报成功, orderNo={}", order.getOrderNo());
            } else {
                order.setReportStatus(2);
                order.setSyncFailReason("国家平台上报失败");
                log.warn("【异步上报】转移联单上报失败, orderNo={}", order.getOrderNo());
            }
            wasteTransferOrderMapper.updateById(order);
            log.info("【异步上报】转移联单上报处理完成, orderId={}, success={}", order.getId(), success);
        } catch (Exception e) {
            log.error("【异步上报】转移联单上报异常, orderId={}", order.getId(), e);
            order.setReportStatus(2);
            order.setSyncFailReason(e.getMessage());
            wasteTransferOrderMapper.updateById(order);
            throw new RuntimeException("转移联单上报异常", e);
        }
    }

    private void handleTransferOrderSync(WasteTransferOrder order) {
        log.info("执行转移联单数据同步, orderId={}, orderNo={}", order.getId(), order.getOrderNo());
        try {
            if (order.getStatus() != null && order.getStatus() == 2) {
                boolean success = nationalPlatformService.reportTransferOrderCompletion(order);
                log.info("转移联单完成信息上报, orderId={}, success={}", order.getId(), success);
            }
        } catch (Exception e) {
            log.error("转移联单同步处理异常, orderId={}", order.getId(), e);
        }
    }

    private void handleTransferOrderCreate(WasteTransferOrder order) {
        log.info("执行转移联单创建后处理, orderId={}, orderNo={}", order.getId(), order.getOrderNo());
    }

    private void handleTransferOrderUpdate(WasteTransferOrder order) {
        log.info("执行转移联单更新后处理, orderId={}, orderNo={}", order.getId(), order.getOrderNo());
    }

    private void handleScaleData(Map<String, Object> scaleData) {
        log.info("处理地磅数据, scaleData={}", scaleData);
        try {
            String deviceId = scaleData.get("deviceId") != null ? scaleData.get("deviceId").toString() : null;
            BigDecimal weight = scaleData.get("weight") != null ? 
                new BigDecimal(scaleData.get("weight").toString()) : null;
            Boolean stable = scaleData.get("stable") != null ? 
                Boolean.parseBoolean(scaleData.get("stable").toString()) : false;

            if (deviceId != null && weight != null && stable) {
                log.info("地磅数据稳定, deviceId={}, weight={}kg, 可用于入库称重", deviceId, weight);
            }
        } catch (Exception e) {
            log.error("处理地磅数据异常", e);
        }
    }

    private void handleWarningPush(WarningRecord warningRecord) {
        try {
            log.info("执行预警推送逻辑, warningNo={}, type={}, level={}",
                    warningRecord.getWarningNo(), 
                    warningRecord.getWarningType(),
                    warningRecord.getWarningLevel());

            doPushWarning(warningRecord);

            warningRecord.setPushStatus(1);
            warningRecord.setPushTime(LocalDateTime.now());
            warningRecordMapper.updateById(warningRecord);

            log.info("预警推送成功, warningNo={}", warningRecord.getWarningNo());
        } catch (Exception e) {
            log.error("预警推送失败, warningNo={}", warningRecord.getWarningNo(), e);
            warningRecord.setPushStatus(2);
            warningRecord.setPushFailReason(e.getMessage());
            warningRecordMapper.updateById(warningRecord);
            throw new RuntimeException("预警推送失败", e);
        }
    }

    private void doPushWarning(WarningRecord warningRecord) {
        log.info("【预警推送】开始推送预警, type={}, level={}, content={}",
                warningRecord.getWarningType(),
                warningRecord.getWarningLevel(),
                warningRecord.getWarningContent());

        String title = buildWarningTitle(warningRecord);
        String content = warningRecord.getWarningContent();

        pushToApp(warningRecord, title, content);
        
        if (warningRecord.getWarningLevel() != null && warningRecord.getWarningLevel() >= 2) {
            pushSms(warningRecord, title, content);
        }

        log.info("【预警推送】完成, warningNo={}", warningRecord.getWarningNo());
    }

    private String buildWarningTitle(WarningRecord warningRecord) {
        String type = warningRecord.getWarningType();
        String level = "";
        if (warningRecord.getWarningLevel() != null) {
            switch (warningRecord.getWarningLevel()) {
                case 1: level = "【一般】"; break;
                case 2: level = "【较重】"; break;
                case 3: level = "【严重】"; break;
                default: level = "【预警】";
            }
        }
        String typeName = "";
        if ("NEAR_EXPIRY".equals(type)) {
            typeName = "危废即将超期";
        } else if ("OVERDUE".equals(type)) {
            typeName = "危废已超期";
        } else if ("OVERWEIGHT".equals(type)) {
            typeName = "库存超量";
        } else if ("OVER_CAPACITY".equals(type)) {
            typeName = "库容不足";
        } else {
            typeName = "库存预警";
        }
        return level + typeName;
    }

    private void pushToApp(WarningRecord warningRecord, String title, String content) {
        log.info("【APP推送】推送预警到移动端, warningNo={}, title={}", warningRecord.getWarningNo(), title);
        boolean success = pushNotificationService.pushToApp(warningRecord, title, content);
        if (!success) {
            throw new RuntimeException("APP推送失败");
        }
        log.info("【APP推送】推送成功, warningNo={}", warningRecord.getWarningNo());
    }

    private void pushSms(WarningRecord warningRecord, String title, String content) {
        log.info("【短信推送】发送预警短信, warningNo={}, title={}", warningRecord.getWarningNo(), title);
        boolean success = pushNotificationService.sendWarningSms(warningRecord, title, content);
        if (!success) {
            throw new RuntimeException("短信推送失败");
        }
        log.info("【短信推送】发送成功, warningNo={}", warningRecord.getWarningNo());
    }

    private void updateInventoryAfterOut(WasteOutRecord record) {
        if (record == null || record.getContainerId() == null) {
            return;
        }
        log.info("更新出库后的库存, containerId={}, weight={}", record.getContainerId(), record.getWeight());
        
        com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<WasteInventory> wrapper = 
            new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getContainerId, record.getContainerId());
        wrapper.eq(WasteInventory::getStatus, 1);
        
        WasteInventory inventory = wasteInventoryMapper.selectOne(wrapper);
        if (inventory != null) {
            BigDecimal newWeight = inventory.getWeight().subtract(record.getWeight());
            if (newWeight.compareTo(BigDecimal.ZERO) <= 0) {
                inventory.setWeight(BigDecimal.ZERO);
                inventory.setStatus(0);
                log.info("容器库存已清空, containerId={}", record.getContainerId());
            } else {
                inventory.setWeight(newWeight);
            }
            inventory.setOutWeight(inventory.getOutWeight().add(record.getWeight()));
            wasteInventoryMapper.updateById(inventory);
            log.info("库存更新完成, containerId={}, 剩余重量={}", record.getContainerId(), inventory.getWeight());
        }
    }

    private void updateEnterpriseStorage(Long enterpriseId) {
        if (enterpriseId == null) {
            return;
        }
        log.info("更新企业库容使用情况, enterpriseId={}", enterpriseId);
        
        com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<WasteInventory> invWrapper = 
            new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<>();
        invWrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        invWrapper.eq(WasteInventory::getStatus, 1);
        List<WasteInventory> inventories = wasteInventoryMapper.selectList(invWrapper);
        
        BigDecimal totalWeight = BigDecimal.ZERO;
        for (WasteInventory inv : inventories) {
            if (inv.getWeight() != null) {
                totalWeight = totalWeight.add(inv.getWeight());
            }
        }
        
        EnterpriseInfo enterprise = enterpriseInfoMapper.selectById(enterpriseId);
        if (enterprise != null) {
            enterprise.setStorageUsed(totalWeight.divide(new BigDecimal("1000"), 4, BigDecimal.ROUND_HALF_UP));
            enterpriseInfoMapper.updateById(enterprise);
            log.info("企业库容更新完成, enterpriseId={}, 已用容量={}吨", enterpriseId, enterprise.getStorageUsed());
        }
    }
}
