package com.waste.mq;

import cn.hutool.core.util.StrUtil;
import com.waste.entity.SyncRecord;
import com.waste.mapper.SyncRecordMapper;
import com.waste.utils.JsonUtils;
import lombok.extern.slf4j.Slf4j;
import org.apache.rocketmq.spring.annotation.RocketMQMessageListener;
import org.apache.rocketmq.spring.core.RocketMQListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.Map;

@Slf4j
@Component
public class DeadLetterQueueHandler {

    @Autowired
    private SyncRecordMapper syncRecordMapper;

    public void handleDeadLetter(String topic, String tag, String msgId, String bizKey, 
                                  String bizType, Object payload, String failReason) {
        log.error("【死信队列】处理死信消息, topic={}, tag={}, msgId={}, bizKey={}, bizType={}", 
                topic, tag, msgId, bizKey, bizType);
        
        try {
            SyncRecord syncRecord = new SyncRecord();
            syncRecord.setSyncNo("DLQ_" + System.currentTimeMillis());
            syncRecord.setSyncType(bizType);
            syncRecord.setSyncDirection("OUT");
            syncRecord.setTotalCount(1);
            syncRecord.setSuccessCount(0);
            syncRecord.setFailCount(1);
            syncRecord.setSyncTime(LocalDateTime.now());
            syncRecord.setStatus(2);
            syncRecord.setFailReason(failReason);
            
            if (payload != null) {
                String payloadJson = JsonUtils.toJson(payload);
                if (payloadJson.length() > 500) {
                    payloadJson = payloadJson.substring(0, 500) + "...";
                }
                syncRecord.setRemark(payloadJson);
            }
            
            syncRecordMapper.insert(syncRecord);
            log.info("【死信队列】死信消息已记录到数据库, syncNo={}", syncRecord.getSyncNo());
            
        } catch (Exception e) {
            log.error("【死信队列】记录死信消息到数据库失败, topic={}, bizKey={}", topic, bizKey, e);
        }
        
        alertDeadLetter(topic, tag, msgId, bizKey, bizType, failReason);
    }

    private void alertDeadLetter(String topic, String tag, String msgId, String bizKey, 
                                  String bizType, String failReason) {
        log.error("【死信队列告警】请及时处理死信消息! topic={}, tag={}, msgId={}, bizKey={}, bizType={}, reason={}",
                topic, tag, msgId, bizKey, bizType, failReason);
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.DLQ_TOPIC_PREFIX + WasteMqProducer.WASTE_IN_TOPIC,
            consumerGroup = "dlq-waste-in-consumer-group"
    )
    public class DlqWasteInConsumer implements RocketMQListener<String> {
        @Override
        public void onMessage(String message) {
            handleDlqMessage(WasteMqProducer.WASTE_IN_TOPIC, message);
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.DLQ_TOPIC_PREFIX + WasteMqProducer.WASTE_OUT_TOPIC,
            consumerGroup = "dlq-waste-out-consumer-group"
    )
    public class DlqWasteOutConsumer implements RocketMQListener<String> {
        @Override
        public void onMessage(String message) {
            handleDlqMessage(WasteMqProducer.WASTE_OUT_TOPIC, message);
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.DLQ_TOPIC_PREFIX + WasteMqProducer.TRANSFER_ORDER_TOPIC,
            consumerGroup = "dlq-transfer-order-consumer-group"
    )
    public class DlqTransferOrderConsumer implements RocketMQListener<String> {
        @Override
        public void onMessage(String message) {
            handleDlqMessage(WasteMqProducer.TRANSFER_ORDER_TOPIC, message);
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.DLQ_TOPIC_PREFIX + WasteMqProducer.WARNING_TOPIC,
            consumerGroup = "dlq-warning-consumer-group"
    )
    public class DlqWarningConsumer implements RocketMQListener<String> {
        @Override
        public void onMessage(String message) {
            handleDlqMessage(WasteMqProducer.WARNING_TOPIC, message);
        }
    }

    @Component
    @RocketMQMessageListener(
            topic = WasteMqProducer.DLQ_TOPIC_PREFIX + WasteMqProducer.SCALE_DATA_TOPIC,
            consumerGroup = "dlq-scale-data-consumer-group"
    )
    public class DlqScaleDataConsumer implements RocketMQListener<String> {
        @Override
        public void onMessage(String message) {
            handleDlqMessage(WasteMqProducer.SCALE_DATA_TOPIC, message);
        }
    }

    private void handleDlqMessage(String topic, String message) {
        log.error("【死信队列】接收到死信消息, topic={}, message={}", topic, message);
        try {
            Map<String, Object> msgData = JsonUtils.parseMap(message);
            String bizKey = getValueFromMap(msgData, WasteMqProducer.HEADER_BIZ_KEY);
            String bizType = getValueFromMap(msgData, WasteMqProducer.HEADER_BIZ_TYPE);
            String msgId = getValueFromMap(msgData, WasteMqProducer.HEADER_MSG_ID);
            
            handleDeadLetter(topic, null, msgId, bizKey, bizType, message, 
                    "消息消费失败达到最大重试次数，进入死信队列");
                    
        } catch (Exception e) {
            log.error("【死信队列】解析死信消息失败, topic={}", topic, e);
            handleDeadLetter(topic, null, null, null, "UNKNOWN", message, e.getMessage());
        }
    }

    private String getValueFromMap(Map<String, Object> map, String key) {
        if (map == null || StrUtil.isBlank(key)) {
            return null;
        }
        Object value = map.get(key);
        if (value == null) {
            Map<String, Object> headers = (Map<String, Object>) map.get("headers");
            if (headers != null) {
                value = headers.get(key);
            }
        }
        return value != null ? value.toString() : null;
    }
}
