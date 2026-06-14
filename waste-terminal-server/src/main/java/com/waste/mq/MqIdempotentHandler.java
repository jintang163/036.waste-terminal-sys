package com.waste.mq;

import cn.hutool.core.util.StrUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

@Slf4j
@Component
public class MqIdempotentHandler {

    private static final String IDEMPOTENT_KEY_PREFIX = "mq:idempotent:";
    private static final String CONSUMING_KEY_PREFIX = "mq:consuming:";
    private static final long IDEMPOTENT_EXPIRE_HOURS = 24;
    private static final long CONSUMING_EXPIRE_MINUTES = 5;

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    public boolean isConsumed(String bizKey) {
        if (StrUtil.isBlank(bizKey)) {
            return false;
        }
        String key = IDEMPOTENT_KEY_PREFIX + bizKey;
        Boolean exists = stringRedisTemplate.hasKey(key);
        if (Boolean.TRUE.equals(exists)) {
            log.warn("消息已被消费, bizKey={}", bizKey);
            return true;
        }
        return false;
    }

    public boolean markConsuming(String bizKey) {
        if (StrUtil.isBlank(bizKey)) {
            return false;
        }
        String key = CONSUMING_KEY_PREFIX + bizKey;
        Boolean success = stringRedisTemplate.opsForValue()
                .setIfAbsent(key, String.valueOf(System.currentTimeMillis()), 
                        CONSUMING_EXPIRE_MINUTES, TimeUnit.MINUTES);
        if (Boolean.TRUE.equals(success)) {
            log.debug("标记消息消费中, bizKey={}", bizKey);
            return true;
        } else {
            log.warn("消息正在消费中, 跳过重复消费, bizKey={}", bizKey);
            return false;
        }
    }

    public void markConsumed(String bizKey) {
        if (StrUtil.isBlank(bizKey)) {
            return;
        }
        String key = IDEMPOTENT_KEY_PREFIX + bizKey;
        stringRedisTemplate.opsForValue().set(key, String.valueOf(System.currentTimeMillis()), 
                IDEMPOTENT_EXPIRE_HOURS, TimeUnit.HOURS);
        log.info("标记消息已消费, bizKey={}", bizKey);
        releaseConsumingLock(bizKey);
    }

    public void markConsumedFailed(String bizKey) {
        if (StrUtil.isBlank(bizKey)) {
            return;
        }
        log.warn("消息消费失败, 清除消费标记以便重试, bizKey={}", bizKey);
        releaseConsumingLock(bizKey);
    }

    public void releaseConsumingLock(String bizKey) {
        if (StrUtil.isBlank(bizKey)) {
            return;
        }
        String key = CONSUMING_KEY_PREFIX + bizKey;
        stringRedisTemplate.delete(key);
        log.debug("释放消息消费锁, bizKey={}", bizKey);
    }

    public boolean checkAndMarkConsuming(String bizKey) {
        if (isConsumed(bizKey)) {
            return false;
        }
        return markConsuming(bizKey);
    }
}
