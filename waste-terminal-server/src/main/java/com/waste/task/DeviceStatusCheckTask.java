package com.waste.task;

import com.waste.service.DeviceInfoService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class DeviceStatusCheckTask {

    @Autowired
    private DeviceInfoService deviceInfoService;

    private static final int DEFAULT_ABNORMAL_THRESHOLD_HOURS = 24;

    @Scheduled(cron = "0 0 * * * ?")
    public void checkDeviceStatus() {
        log.info("========== 设备异常检测定时任务开始 ==========");
        try {
            int abnormalCount = deviceInfoService.markAbnormalDevices(DEFAULT_ABNORMAL_THRESHOLD_HOURS);
            log.info("设备异常检测完成，共标记{}台设备为故障状态", abnormalCount);
        } catch (Exception e) {
            log.error("设备异常检测任务执行失败", e);
        }
        log.info("========== 设备异常检测定时任务结束 ==========");
    }
}
