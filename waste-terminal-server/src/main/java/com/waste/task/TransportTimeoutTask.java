package com.waste.task;

import com.waste.service.TransportWarningService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Component
public class TransportTimeoutTask {

    @Autowired
    private TransportWarningService transportWarningService;

    @Scheduled(cron = "0 */5 * * * ?")
    @Transactional(rollbackFor = Exception.class)
    public void checkTransportTimeout() {
        log.info("开始执行运输超时检测定时任务");
        try {
            transportWarningService.checkTransportTimeout();
        } catch (Exception e) {
            log.error("运输超时检测定时任务执行异常", e);
        }
        log.info("运输超时检测定时任务执行完成");
    }
}
