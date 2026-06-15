package com.waste.task;

import com.waste.service.WasteLedgerService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class WasteLedgerTask {

    @Autowired
    private WasteLedgerService wasteLedgerService;

    @Scheduled(cron = "0 0 2 1 * ?")
    public void generateMonthlyLedger() {
        log.info("========== 开始执行月度台账自动生成任务 ==========");
        try {
            wasteLedgerService.autoGenerateMonthlyLedger();
            log.info("========== 月度台账自动生成任务执行完成 ==========");
        } catch (Exception e) {
            log.error("月度台账自动生成任务执行失败", e);
        }
    }

    @Scheduled(cron = "0 0 3 1 1 ?")
    public void generateYearlyLedger() {
        log.info("========== 开始执行年度台账自动生成任务 ==========");
        try {
            wasteLedgerService.autoGenerateYearlyLedger();
            log.info("========== 年度台账自动生成任务执行完成 ==========");
        } catch (Exception e) {
            log.error("年度台账自动生成任务执行失败", e);
        }
    }

    @Scheduled(cron = "0 0 4 * * ?")
    public void reportLedger() {
        log.info("========== 开始执行台账自动上报任务 ==========");
        try {
            wasteLedgerService.autoReportLedger();
            log.info("========== 台账自动上报任务执行完成 ==========");
        } catch (Exception e) {
            log.error("台账自动上报任务执行失败", e);
        }
    }

    @Scheduled(cron = "0 0 */6 * * ?")
    public void retryFailedReport() {
        log.info("========== 开始执行台账上报失败重试任务 ==========");
        try {
            wasteLedgerService.autoReportLedger();
            log.info("========== 台账上报失败重试任务执行完成 ==========");
        } catch (Exception e) {
            log.error("台账上报失败重试任务执行失败", e);
        }
    }
}
