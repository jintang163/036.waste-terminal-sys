package com.waste.mq;

import cn.hutool.core.util.StrUtil;
import com.waste.entity.WarningRecord;
import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteTransferOrder;
import com.waste.utils.JsonUtils;
import lombok.extern.slf4j.Slf4j;
import org.apache.rocketmq.client.producer.SendCallback;
import org.apache.rocketmq.client.producer.SendResult;
import org.apache.rocketmq.client.producer.SendStatus;
import org.apache.rocketmq.spring.core.RocketMQTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.Message;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

@Slf4j
@Component
public class WasteMqProducer {

    public static final String WASTE_IN_TOPIC = "WASTE_IN_TOPIC";
    public static final String WASTE_OUT_TOPIC = "WASTE_OUT_TOPIC";
    public static final String TRANSFER_ORDER_TOPIC = "TRANSFER_ORDER_TOPIC";
    public static final String WARNING_TOPIC = "WARNING_TOPIC";
    public static final String SCALE_DATA_TOPIC = "SCALE_DATA_TOPIC";
    public static final String DLQ_TOPIC_PREFIX = "%DLQ%";

    public static final String TAG_REPORT = "report";
    public static final String TAG_SYNC = "sync";
    public static final String TAG_CREATE = "create";
    public static final String TAG_UPDATE = "update";
    public static final String TAG_PUSH = "push";

    public static final String HEADER_MSG_ID = "msgId";
    public static final String HEADER_CREATE_TIME = "createTime";
    public static final String HEADER_DATA_TYPE = "dataType";
    public static final String HEADER_RETRY_COUNT = "retryCount";
    public static final String HEADER_BIZ_KEY = "bizKey";
    public static final String HEADER_BIZ_TYPE = "bizType";
    public static final String HEADER_TRACE_ID = "traceId";

    public static final int MAX_RETRY_TIMES = 3;
    public static final long RETRY_DELAY_LEVEL = 3;

    @Autowired
    private RocketMQTemplate rocketMQTemplate;

    @Value("${rocketmq.producer.retry-times-when-send-failed:2}")
    private int retryTimesWhenSendFailed;

    @PostConstruct
    public void init() {
        log.info("WasteMqProducer初始化完成, 重试次数配置: {}", retryTimesWhenSendFailed);
    }

    public void sendWasteInReport(WasteInRecord record) {
        Map<String, Object> data = buildWasteInData(record);
        sendMessageWithRetry(WASTE_IN_TOPIC, TAG_REPORT, data, 
                "waste_in_" + record.getId(), "WASTE_IN_REPORT");
    }

    public void sendWasteInSync(WasteInRecord record) {
        Map<String, Object> data = buildWasteInData(record);
        sendMessageWithRetry(WASTE_IN_TOPIC, TAG_SYNC, data, 
                "waste_in_sync_" + record.getId(), "WASTE_IN_SYNC");
    }

    public void sendWasteInReport(Long recordId) {
        sendIdMessageWithRetry(WASTE_IN_TOPIC, TAG_REPORT, recordId, 
                "waste_in_" + recordId, "WASTE_IN_REPORT");
    }

    public void sendWasteInSync(Long recordId) {
        sendIdMessageWithRetry(WASTE_IN_TOPIC, TAG_SYNC, recordId, 
                "waste_in_sync_" + recordId, "WASTE_IN_SYNC");
    }

    public void sendWasteOutReport(WasteOutRecord record) {
        Map<String, Object> data = buildWasteOutData(record);
        sendMessageWithRetry(WASTE_OUT_TOPIC, TAG_REPORT, data, 
                "waste_out_" + record.getId(), "WASTE_OUT_REPORT");
    }

    public void sendWasteOutSync(WasteOutRecord record) {
        Map<String, Object> data = buildWasteOutData(record);
        sendMessageWithRetry(WASTE_OUT_TOPIC, TAG_SYNC, data, 
                "waste_out_sync_" + record.getId(), "WASTE_OUT_SYNC");
    }

    public void sendWasteOutReport(Long recordId) {
        sendIdMessageWithRetry(WASTE_OUT_TOPIC, TAG_REPORT, recordId, 
                "waste_out_" + recordId, "WASTE_OUT_REPORT");
    }

    public void sendWasteOutSync(Long recordId) {
        sendIdMessageWithRetry(WASTE_OUT_TOPIC, TAG_SYNC, recordId, 
                "waste_out_sync_" + recordId, "WASTE_OUT_SYNC");
    }

    public void sendTransferOrderReport(WasteTransferOrder order) {
        Map<String, Object> data = buildTransferOrderData(order);
        sendMessageWithRetry(TRANSFER_ORDER_TOPIC, TAG_REPORT, data, 
                "transfer_order_" + order.getId(), "TRANSFER_ORDER_REPORT");
    }

    public void sendTransferOrderSync(WasteTransferOrder order) {
        Map<String, Object> data = buildTransferOrderData(order);
        sendMessageWithRetry(TRANSFER_ORDER_TOPIC, TAG_SYNC, data, 
                "transfer_order_sync_" + order.getId(), "TRANSFER_ORDER_SYNC");
    }

    public void sendTransferOrderReport(Long orderId) {
        sendIdMessageWithRetry(TRANSFER_ORDER_TOPIC, TAG_REPORT, orderId, 
                "transfer_order_" + orderId, "TRANSFER_ORDER_REPORT");
    }

    public void sendTransferOrderSync(Long orderId) {
        sendIdMessageWithRetry(TRANSFER_ORDER_TOPIC, TAG_SYNC, orderId, 
                "transfer_order_sync_" + orderId, "TRANSFER_ORDER_SYNC");
    }

    public void sendWarningPush(WarningRecord warningRecord) {
        sendWarningPush(warningRecord, TAG_PUSH);
    }

    public void sendWarningPush(WarningRecord warningRecord, String tag) {
        log.info("准备发送预警推送消息, warningNo={}, warningType={}", 
                warningRecord.getWarningNo(), warningRecord.getWarningType());
        Map<String, Object> data = buildWarningData(warningRecord);
        sendMessageWithRetry(WARNING_TOPIC, tag, data, 
                "warning_" + warningRecord.getId(), "WARNING_PUSH");
    }

    public void sendWarningPushBatch(java.util.List<WarningRecord> warningRecords) {
        if (warningRecords == null || warningRecords.isEmpty()) {
            return;
        }
        log.info("准备批量发送预警推送消息, 数量={}", warningRecords.size());
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failCount = new AtomicInteger(0);
        for (WarningRecord record : warningRecords) {
            try {
                sendWarningPush(record);
                successCount.incrementAndGet();
            } catch (Exception e) {
                failCount.incrementAndGet();
                log.error("批量发送预警消息失败, warningId={}", record.getId(), e);
            }
        }
        log.info("批量发送预警推送消息完成, 成功={}, 失败={}", successCount.get(), failCount.get());
    }

    public void sendScaleData(Object scaleData) {
        String bizKey = "scale_" + System.currentTimeMillis();
        sendMessageWithRetry(SCALE_DATA_TOPIC, null, scaleData, bizKey, "SCALE_DATA");
    }

    private void sendIdMessageWithRetry(String topic, String tag, Long id, String bizKey, String bizType) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("id", id);
        payload.put("timestamp", System.currentTimeMillis());
        sendMessageWithRetry(topic, tag, payload, bizKey, bizType);
    }

    private void sendMessageWithRetry(String topic, String tag, Object data, String bizKey, String bizType) {
        String destination = buildDestination(topic, tag);
        String msgId = StrUtil.uuid();
        int retryCount = 0;
        boolean success = false;
        Exception lastException = null;

        while (retryCount <= MAX_RETRY_TIMES && !success) {
            try {
                String jsonData = JsonUtils.toJson(data);
                Message<String> message = MessageBuilder.withPayload(jsonData)
                        .setHeader(HEADER_MSG_ID, msgId)
                        .setHeader(HEADER_CREATE_TIME, System.currentTimeMillis())
                        .setHeader(HEADER_DATA_TYPE, data != null ? data.getClass().getSimpleName() : "Unknown")
                        .setHeader(HEADER_RETRY_COUNT, retryCount)
                        .setHeader(HEADER_BIZ_KEY, bizKey)
                        .setHeader(HEADER_BIZ_TYPE, bizType)
                        .setHeader(HEADER_TRACE_ID, StrUtil.uuid())
                        .build();

                if (retryCount == 0) {
                    sendAsync(destination, message, topic, tag, bizKey, bizType, msgId, retryCount);
                    success = true;
                } else {
                    success = sendSyncWithDelay(destination, message, topic, tag, bizKey, bizType, msgId, retryCount);
                }
            } catch (Exception e) {
                lastException = e;
                retryCount++;
                log.warn("RocketMQ消息发送失败, 进行第{}次重试, topic={}, tag={}, bizKey={}", 
                        retryCount, topic, tag, bizKey, e);
                try {
                    Thread.sleep(getDelayMillis(retryCount));
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }

        if (!success && lastException != null) {
            log.error("RocketMQ消息发送最终失败, 已达到最大重试次数{}, topic={}, tag={}, bizKey={}", 
                    MAX_RETRY_TIMES, topic, tag, bizKey, lastException);
            handleSendFailure(topic, tag, data, bizKey, bizType, lastException);
        }
    }

    private void sendAsync(String destination, Message<String> message, String topic, String tag, 
                           String bizKey, String bizType, String msgId, int retryCount) {
        rocketMQTemplate.asyncSend(destination, message, new SendCallback() {
            @Override
            public void onSuccess(SendResult sendResult) {
                if (sendResult.getSendStatus() == SendStatus.SEND_OK) {
                    log.info("RocketMQ异步消息发送成功, topic={}, tag={}, bizKey={}, msgId={}, retryCount={}, sendResult={}", 
                            topic, tag, bizKey, msgId, retryCount, sendResult.getMsgId());
                } else {
                    log.warn("RocketMQ异步消息发送状态异常, topic={}, tag={}, status={}, bizKey={}", 
                            topic, tag, sendResult.getSendStatus(), bizKey);
                }
            }

            @Override
            public void onException(Throwable throwable) {
                log.error("RocketMQ异步消息发送异常, topic={}, tag={}, bizKey={}, msgId={}", 
                        topic, tag, bizKey, msgId, throwable);
            }
        });
    }

    private boolean sendSyncWithDelay(String destination, Message<String> message, String topic, String tag, 
                                      String bizKey, String bizType, String msgId, int retryCount) {
        try {
            SendResult sendResult = rocketMQTemplate.syncSend(destination, message, 3000, RETRY_DELAY_LEVEL);
            if (sendResult.getSendStatus() == SendStatus.SEND_OK) {
                log.info("RocketMQ同步重试消息发送成功, topic={}, tag={}, bizKey={}, msgId={}, retryCount={}", 
                        topic, tag, bizKey, msgId, retryCount);
                return true;
            }
        } catch (Exception e) {
            log.error("RocketMQ同步重试消息发送异常, topic={}, tag={}, bizKey={}, retryCount={}", 
                    topic, tag, bizKey, retryCount, e);
        }
        return false;
    }

    private long getDelayMillis(int retryCount) {
        long[] delays = {1000, 3000, 5000};
        return retryCount <= delays.length ? delays[retryCount - 1] : delays[delays.length - 1];
    }

    private void handleSendFailure(String topic, String tag, Object data, String bizKey, 
                                   String bizType, Exception exception) {
        log.error("记录消息发送失败日志, topic={}, tag={}, bizKey={}, bizType={}, error={}", 
                topic, tag, bizKey, bizType, exception.getMessage());
    }

    private Map<String, Object> buildWasteInData(WasteInRecord record) {
        Map<String, Object> data = new HashMap<>();
        data.put("id", record.getId());
        data.put("inNo", record.getInNo());
        data.put("containerId", record.getContainerId());
        data.put("containerCode", record.getContainerCode());
        data.put("wasteId", record.getWasteId());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("wasteCategory", record.getWasteCategory());
        data.put("hazardCode", record.getHazardCode());
        data.put("weight", record.getWeight());
        data.put("produceDate", record.getProduceDate());
        data.put("storageLocation", record.getStorageLocation());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("syncStatus", record.getSyncStatus());
        data.put("status", record.getStatus());
        data.put("timestamp", System.currentTimeMillis());
        return data;
    }

    private Map<String, Object> buildWasteOutData(WasteOutRecord record) {
        Map<String, Object> data = new HashMap<>();
        data.put("id", record.getId());
        data.put("outNo", record.getOutNo());
        data.put("transferOrderId", record.getTransferOrderId());
        data.put("containerId", record.getContainerId());
        data.put("containerCode", record.getContainerCode());
        data.put("wasteId", record.getWasteId());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("weight", record.getWeight());
        data.put("receiverUnitId", record.getReceiverUnitId());
        data.put("receiverUnitName", record.getReceiverUnitName());
        data.put("transporterId", record.getTransporterId());
        data.put("transporterName", record.getTransporterName());
        data.put("vehicleNo", record.getVehicleNo());
        data.put("driverName", record.getDriverName());
        data.put("outTime", record.getOutTime());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("syncStatus", record.getSyncStatus());
        data.put("status", record.getStatus());
        data.put("signStatus", record.getSignStatus());
        data.put("timestamp", System.currentTimeMillis());
        return data;
    }

    private Map<String, Object> buildTransferOrderData(WasteTransferOrder order) {
        Map<String, Object> data = new HashMap<>();
        data.put("id", order.getId());
        data.put("orderNo", order.getOrderNo());
        data.put("nationalOrderNo", order.getNationalOrderNo());
        data.put("orderType", order.getOrderType());
        data.put("generatorUnitId", order.getGeneratorUnitId());
        data.put("generatorUnitName", order.getGeneratorUnitName());
        data.put("generatorUnitCode", order.getGeneratorUnitCode());
        data.put("receiverUnitId", order.getReceiverUnitId());
        data.put("receiverUnitName", order.getReceiverUnitName());
        data.put("receiverUnitCode", order.getReceiverUnitCode());
        data.put("transporterId", order.getTransporterId());
        data.put("transporterName", order.getTransporterName());
        data.put("vehicleNo", order.getVehicleNo());
        data.put("driverName", order.getDriverName());
        data.put("totalWeight", order.getTotalWeight());
        data.put("totalContainers", order.getTotalContainers());
        data.put("wasteDetails", order.getWasteDetails());
        data.put("startTime", order.getStartTime());
        data.put("estimateArriveTime", order.getEstimateArriveTime());
        data.put("reportStatus", order.getReportStatus());
        data.put("status", order.getStatus());
        data.put("enterpriseId", order.getEnterpriseId());
        data.put("timestamp", System.currentTimeMillis());
        return data;
    }

    private Map<String, Object> buildWarningData(WarningRecord warningRecord) {
        Map<String, Object> data = new HashMap<>();
        data.put("id", warningRecord.getId());
        data.put("warningNo", warningRecord.getWarningNo());
        data.put("warningType", warningRecord.getWarningType());
        data.put("warningLevel", warningRecord.getWarningLevel());
        data.put("warningContent", warningRecord.getWarningContent());
        data.put("pushStatus", warningRecord.getPushStatus());
        data.put("enterpriseId", warningRecord.getEnterpriseId());
        data.put("timestamp", System.currentTimeMillis());
        return data;
    }

    private String buildDestination(String topic, String tag) {
        if (StrUtil.isBlank(tag)) {
            return topic;
        }
        return topic + ":" + tag;
    }
}
