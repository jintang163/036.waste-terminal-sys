package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.dto.PlatformReportDashboardDTO;
import com.waste.entity.*;
import com.waste.mapper.PlatformReportRecordMapper;
import com.waste.mapper.WasteInRecordMapper;
import com.waste.mapper.WasteOutRecordMapper;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.mq.WasteMqProducer;
import com.waste.service.NationalPlatformService;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.JsonUtils;
import com.waste.utils.SmUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Slf4j
@Service
public class NationalPlatformServiceImpl implements NationalPlatformService {

    @Value("${waste.national-platform.url:https://api.ep.gov.cn/waste}")
    private String platformUrl;

    @Value("${waste.national-platform.app-id:}")
    private String appId;

    @Value("${waste.national-platform.app-secret:}")
    private String appSecret;

    @Value("${waste.national-platform.mock-enabled:true}")
    private boolean mockEnabled;

    @Value("${waste.national-platform.connection-timeout:10000}")
    private int connectionTimeout;

    @Value("${waste.national-platform.read-timeout:30000}")
    private int readTimeout;

    @Value("${waste.national-platform.retry-times:3}")
    private int retryTimes;

    @Value("${sm.sm4.key:0123456789abcdeffedcba9876543210}")
    private String sm4Key;

    @Value("${sm.sm2.public-key:}")
    private String sm2PublicKey;

    @Value("${sm.sm2.private-key:}")
    private String sm2PrivateKey;

    @Autowired
    private PlatformReportRecordMapper platformReportRecordMapper;

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @Autowired
    private WasteTransferOrderMapper wasteTransferOrderMapper;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
    private static final int HTTP_SUCCESS = 200;
    private static final String RESP_CODE_SUCCESS = "0";
    private static final String RESP_CODE_DUPLICATE = "1001";

    public static final String BIZ_TYPE_WASTE_IN = "WASTE_IN";
    public static final String BIZ_TYPE_WASTE_OUT = "WASTE_OUT";
    public static final String BIZ_TYPE_TRANSFER_ORDER = "TRANSFER_ORDER";
    public static final String BIZ_TYPE_TRANSFER_COMPLETE = "TRANSFER_COMPLETE";

    public static final int REPORT_STATUS_PENDING = 0;
    public static final int REPORT_STATUS_SUCCESS = 1;
    public static final int REPORT_STATUS_FAILED = 2;
    public static final int REPORT_STATUS_RETRYING = 3;

    @Override
    public boolean reportWasteIn(WasteInRecord record) {
        log.info("开始上报入库记录到国家环保平台(标准接口), inNo={}", record.getInNo());
        try {
            Map<String, Object> bizData = buildWasteInData(record);
            String requestJson = JsonUtils.toJson(buildRequestBody(bizData, generateRequestId(), LocalDateTime.now().format(FORMATTER)));
            PlatformReportRecord reportRecord = createReportRecord(BIZ_TYPE_WASTE_IN,
                    record.getId().toString(), record.getInNo(), "/wasteIn/report", requestJson, record.getEnterpriseId());
            boolean success = doReport("/wasteIn/report", bizData, record.getInNo());
            if (success) {
                updateReportRecordSuccess(reportRecord, null, getNationalPlatformBizNo(record.getInNo()), 0L);
            } else {
                updateReportRecordFailed(reportRecord, "国家平台上报失败", 0L);
            }
            return success;
        } catch (Exception e) {
            log.error("上报入库记录异常, inNo={}", record.getInNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportWasteInIot(WasteInRecord record) {
        log.info("开始上报入库通知到全国固废系统IoT接口(/Account/saveRktz), inNo={}", record.getInNo());
        try {
            Map<String, Object> bizData = buildIotRktzData(record);
            String requestJson = JsonUtils.toJson(buildRequestBody(bizData, generateRequestId(), LocalDateTime.now().format(FORMATTER)));
            PlatformReportRecord reportRecord = createReportRecord(BIZ_TYPE_WASTE_IN,
                    record.getId().toString(), record.getInNo(), "/Account/saveRktz", requestJson, record.getEnterpriseId());

            long startTime = System.currentTimeMillis();
            boolean success = doReport("/Account/saveRktz", bizData, record.getInNo());
            long durationMs = System.currentTimeMillis() - startTime;

            if (success) {
                String nationalBizNo = getNationalPlatformBizNo(record.getInNo());
                updateReportRecordSuccess(reportRecord, null, nationalBizNo, durationMs);
            } else {
                updateReportRecordFailed(reportRecord, "IoT接口上报失败", durationMs);
                scheduleRetry(reportRecord, record, BIZ_TYPE_WASTE_IN);
            }
            return success;
        } catch (Exception e) {
            log.error("IoT入库通知上报异常, inNo={}", record.getInNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportElectronicManifest(WasteTransferOrder order) {
        log.info("开始上报电子联单到国家环保平台, orderNo={}", order.getOrderNo());
        try {
            Map<String, Object> bizData = buildElectronicManifestData(order);
            String requestJson = JsonUtils.toJson(buildRequestBody(bizData, generateRequestId(), LocalDateTime.now().format(FORMATTER)));
            PlatformReportRecord reportRecord = createReportRecord(BIZ_TYPE_TRANSFER_ORDER,
                    order.getId().toString(), order.getOrderNo(), "/manifest/report", requestJson, order.getEnterpriseId());

            long startTime = System.currentTimeMillis();
            boolean success = doReport("/manifest/report", bizData, order.getOrderNo());
            long durationMs = System.currentTimeMillis() - startTime;

            if (success) {
                String nationalBizNo = getNationalPlatformBizNo(order.getOrderNo());
                updateReportRecordSuccess(reportRecord, null, nationalBizNo, durationMs);
            } else {
                updateReportRecordFailed(reportRecord, "电子联单上报失败", durationMs);
                scheduleRetry(reportRecord, order, BIZ_TYPE_TRANSFER_ORDER);
            }
            return success;
        } catch (Exception e) {
            log.error("电子联单上报异常, orderNo={}", order.getOrderNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportWasteOutIot(WasteOutRecord record) {
        log.info("开始上报出库记录到全国固废系统IoT接口, outNo={}", record.getOutNo());
        try {
            Map<String, Object> bizData = buildIotCktzData(record);
            String requestJson = JsonUtils.toJson(buildRequestBody(bizData, generateRequestId(), LocalDateTime.now().format(FORMATTER)));
            PlatformReportRecord reportRecord = createReportRecord(BIZ_TYPE_WASTE_OUT,
                    record.getId().toString(), record.getOutNo(), "/Account/saveCktz", requestJson, record.getEnterpriseId());

            long startTime = System.currentTimeMillis();
            boolean success = doReport("/Account/saveCktz", bizData, record.getOutNo());
            long durationMs = System.currentTimeMillis() - startTime;

            if (success) {
                String nationalBizNo = getNationalPlatformBizNo(record.getOutNo());
                updateReportRecordSuccess(reportRecord, null, nationalBizNo, durationMs);
            } else {
                updateReportRecordFailed(reportRecord, "IoT出库接口上报失败", durationMs);
                scheduleRetry(reportRecord, record, BIZ_TYPE_WASTE_OUT);
            }
            return success;
        } catch (Exception e) {
            log.error("IoT出库通知上报异常, outNo={}", record.getOutNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportTransferOrder(WasteTransferOrder order) {
        log.info("开始上报转移联单到国家环保平台, orderNo={}", order.getOrderNo());
        try {
            Map<String, Object> bizData = buildTransferOrderData(order);
            return doReport("/transfer/report", bizData, order.getOrderNo());
        } catch (Exception e) {
            log.error("上报转移联单异常, orderNo={}", order.getOrderNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportWasteOut(WasteOutRecord record) {
        log.info("开始上报出库记录到国家环保平台, outNo={}", record.getOutNo());
        try {
            Map<String, Object> bizData = buildWasteOutData(record);
            String requestJson = JsonUtils.toJson(buildRequestBody(bizData, generateRequestId(), LocalDateTime.now().format(FORMATTER)));
            PlatformReportRecord reportRecord = createReportRecord(BIZ_TYPE_WASTE_OUT,
                    record.getId().toString(), record.getOutNo(), "/wasteOut/report", requestJson, record.getEnterpriseId());
            boolean success = doReport("/wasteOut/report", bizData, record.getOutNo());
            if (success) {
                updateReportRecordSuccess(reportRecord, null, getNationalPlatformBizNo(record.getOutNo()), 0L);
            } else {
                updateReportRecordFailed(reportRecord, "出库上报失败", 0L);
            }
            return success;
        } catch (Exception e) {
            log.error("上报出库记录异常, outNo={}", record.getOutNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportTransferOrderCompletion(WasteTransferOrder order) {
        log.info("开始上报转移联单完成信息到国家环保平台, orderNo={}", order.getOrderNo());
        try {
            Map<String, Object> bizData = buildTransferOrderCompletionData(order);
            return doReport("/transfer/complete", bizData, order.getOrderNo());
        } catch (Exception e) {
            log.error("上报转移联单完成信息异常, orderNo={}", order.getOrderNo(), e);
            return false;
        }
    }

    @Override
    public Map<String, Object> queryReportStatus(String bizType, String bizNo) {
        log.info("查询上报状态, bizType={}, bizNo={}", bizType, bizNo);
        Map<String, Object> result = new HashMap<>();
        try {
            Map<String, Object> bizData = new LinkedHashMap<>();
            bizData.put("bizType", bizType);
            bizData.put("bizNo", bizNo);
            boolean success = doReport("/report/query", bizData, bizNo);
            result.put("success", success);
            result.put("bizNo", bizNo);
            result.put("queryTime", LocalDateTime.now());
        } catch (Exception e) {
            log.error("查询上报状态异常, bizType={}, bizNo={}", bizType, bizNo, e);
            result.put("success", false);
            result.put("error", e.getMessage());
        }
        return result;
    }

    @Override
    public String getNationalPlatformBizNo(String localBizNo) {
        return "GJ" + System.currentTimeMillis();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public PlatformReportRecord createReportRecord(String bizType, String bizId, String bizNo, String apiPath, String requestPayload, Long enterpriseId) {
        LambdaQueryWrapper<PlatformReportRecord> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(PlatformReportRecord::getBizType, bizType);
        existWrapper.eq(PlatformReportRecord::getBizId, bizId);
        if (enterpriseId != null) {
            existWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        existWrapper.orderByDesc(PlatformReportRecord::getId);
        existWrapper.last("LIMIT 1");
        PlatformReportRecord existing = platformReportRecordMapper.selectOne(existWrapper);

        if (existing != null) {
            existing.setApiPath(apiPath);
            existing.setLastReportTime(LocalDateTime.now());
            if (existing.getReportStatus() == null || existing.getReportStatus() != REPORT_STATUS_SUCCESS) {
                existing.setReportStatus(REPORT_STATUS_PENDING);
            }
            if (requestPayload != null && requestPayload.length() > 4000) {
                existing.setRequestPayload(requestPayload.substring(0, 4000));
            } else {
                existing.setRequestPayload(requestPayload);
            }
            platformReportRecordMapper.updateById(existing);
            log.info("复用已有上报记录(幂等), id={}, bizType={}, bizId={}, retryCount={}",
                    existing.getId(), bizType, bizId, existing.getRetryCount());
            return existing;
        }

        PlatformReportRecord record = new PlatformReportRecord();
        record.setReportNo(IdGeneratorUtils.generateSyncNo());
        record.setBizType(bizType);
        record.setBizId(bizId);
        record.setBizNo(bizNo);
        record.setApiPath(apiPath);
        record.setReportStatus(REPORT_STATUS_PENDING);
        record.setRetryCount(0);
        record.setMaxRetryCount(retryTimes);
        record.setFirstReportTime(LocalDateTime.now());
        record.setLastReportTime(LocalDateTime.now());
        record.setEnterpriseId(enterpriseId);
        if (requestPayload != null && requestPayload.length() > 4000) {
            record.setRequestPayload(requestPayload.substring(0, 4000));
        } else {
            record.setRequestPayload(requestPayload);
        }
        platformReportRecordMapper.insert(record);
        return record;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateReportRecordSuccess(PlatformReportRecord record, String responsePayload, String nationalBizNo, long durationMs) {
        record.setReportStatus(REPORT_STATUS_SUCCESS);
        record.setLastReportTime(LocalDateTime.now());
        record.setNationalBizNo(nationalBizNo);
        record.setDurationMs(durationMs);
        record.setFailReason(null);
        if (responsePayload != null && responsePayload.length() > 4000) {
            record.setResponsePayload(responsePayload.substring(0, 4000));
        } else {
            record.setResponsePayload(responsePayload);
        }
        platformReportRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateReportRecordFailed(PlatformReportRecord record, String failReason, long durationMs) {
        record.setReportStatus(REPORT_STATUS_FAILED);
        record.setLastReportTime(LocalDateTime.now());
        record.setFailReason(failReason);
        record.setDurationMs(durationMs);
        platformReportRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateReportRecordRetrying(PlatformReportRecord record, String failReason) {
        record.setReportStatus(REPORT_STATUS_RETRYING);
        record.setRetryCount(record.getRetryCount() != null ? record.getRetryCount() + 1 : 1);
        record.setFailReason(failReason);
        record.setNextRetryTime(calculateNextRetryTime(record.getRetryCount()));
        platformReportRecordMapper.updateById(record);
    }

    @Override
    public PlatformReportDashboardDTO.ReportStatistics getReportStatistics(Long enterpriseId) {
        PlatformReportDashboardDTO.ReportStatistics stats = new PlatformReportDashboardDTO.ReportStatistics();

        LambdaQueryWrapper<PlatformReportRecord> baseWrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            baseWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }

        Long total = platformReportRecordMapper.selectCount(baseWrapper);
        stats.setTotalReports(total != null ? total : 0L);

        LambdaQueryWrapper<PlatformReportRecord> successWrapper = new LambdaQueryWrapper<>();
        successWrapper.eq(PlatformReportRecord::getReportStatus, REPORT_STATUS_SUCCESS);
        if (enterpriseId != null) {
            successWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        Long successCount = platformReportRecordMapper.selectCount(successWrapper);
        stats.setSuccessCount(successCount != null ? successCount : 0L);

        LambdaQueryWrapper<PlatformReportRecord> failWrapper = new LambdaQueryWrapper<>();
        failWrapper.eq(PlatformReportRecord::getReportStatus, REPORT_STATUS_FAILED);
        if (enterpriseId != null) {
            failWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        Long failCount = platformReportRecordMapper.selectCount(failWrapper);
        stats.setFailCount(failCount != null ? failCount : 0L);

        LambdaQueryWrapper<PlatformReportRecord> pendingWrapper = new LambdaQueryWrapper<>();
        pendingWrapper.eq(PlatformReportRecord::getReportStatus, REPORT_STATUS_PENDING);
        if (enterpriseId != null) {
            pendingWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        Long pendingCount = platformReportRecordMapper.selectCount(pendingWrapper);
        stats.setPendingCount(pendingCount != null ? pendingCount : 0L);

        LambdaQueryWrapper<PlatformReportRecord> retryingWrapper = new LambdaQueryWrapper<>();
        retryingWrapper.eq(PlatformReportRecord::getReportStatus, REPORT_STATUS_RETRYING);
        if (enterpriseId != null) {
            retryingWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        Long retryingCount = platformReportRecordMapper.selectCount(retryingWrapper);
        stats.setRetryingCount(retryingCount != null ? retryingCount : 0L);

        if (total != null && total > 0) {
            stats.setSuccessRate(BigDecimal.valueOf(stats.getSuccessCount())
                    .divide(BigDecimal.valueOf(total), 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100)));
        } else {
            stats.setSuccessRate(BigDecimal.ZERO);
        }

        LambdaQueryWrapper<PlatformReportRecord> lastSuccessWrapper = new LambdaQueryWrapper<>();
        lastSuccessWrapper.eq(PlatformReportRecord::getReportStatus, REPORT_STATUS_SUCCESS);
        if (enterpriseId != null) {
            lastSuccessWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        lastSuccessWrapper.orderByDesc(PlatformReportRecord::getLastReportTime);
        lastSuccessWrapper.last("LIMIT 1");
        PlatformReportRecord lastSuccess = platformReportRecordMapper.selectOne(lastSuccessWrapper);
        stats.setLastSuccessTime(lastSuccess != null ? lastSuccess.getLastReportTime() : null);

        LambdaQueryWrapper<PlatformReportRecord> lastReportWrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            lastReportWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        lastReportWrapper.orderByDesc(PlatformReportRecord::getLastReportTime);
        lastReportWrapper.last("LIMIT 1");
        PlatformReportRecord lastReport = platformReportRecordMapper.selectOne(lastReportWrapper);
        stats.setLastReportTime(lastReport != null ? lastReport.getLastReportTime() : null);

        return stats;
    }

    @Override
    public List<PlatformReportDashboardDTO.FailedReportItem> getFailedReports(Long enterpriseId, Integer limit) {
        if (limit == null || limit <= 0) {
            limit = 50;
        }

        LambdaQueryWrapper<PlatformReportRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(PlatformReportRecord::getReportStatus, REPORT_STATUS_FAILED, REPORT_STATUS_RETRYING);
        if (enterpriseId != null) {
            wrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(PlatformReportRecord::getLastReportTime);
        wrapper.last("LIMIT " + limit);
        List<PlatformReportRecord> records = platformReportRecordMapper.selectList(wrapper);

        List<PlatformReportDashboardDTO.FailedReportItem> result = new ArrayList<>();
        for (PlatformReportRecord r : records) {
            PlatformReportDashboardDTO.FailedReportItem item = new PlatformReportDashboardDTO.FailedReportItem();
            item.setId(r.getId());
            item.setReportNo(r.getReportNo());
            item.setBizType(r.getBizType());
            item.setBizNo(r.getBizNo());
            item.setRetryCount(r.getRetryCount());
            item.setMaxRetryCount(r.getMaxRetryCount());
            item.setLastReportTime(r.getLastReportTime());
            item.setFailReason(r.getFailReason());
            item.setRequestPayload(r.getRequestPayload());
            item.setCanManualRetry(r.getRetryCount() == null || r.getRetryCount() < r.getMaxRetryCount());
            result.add(item);
        }
        return result;
    }

    @Override
    public List<PlatformReportDashboardDTO.RetryQueueItem> getRetryQueue(Long enterpriseId) {
        LambdaQueryWrapper<PlatformReportRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(PlatformReportRecord::getReportStatus, REPORT_STATUS_RETRYING);
        if (enterpriseId != null) {
            wrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(PlatformReportRecord::getNextRetryTime);
        List<PlatformReportRecord> records = platformReportRecordMapper.selectList(wrapper);

        List<PlatformReportDashboardDTO.RetryQueueItem> result = new ArrayList<>();
        for (PlatformReportRecord r : records) {
            PlatformReportDashboardDTO.RetryQueueItem item = new PlatformReportDashboardDTO.RetryQueueItem();
            item.setId(r.getId());
            item.setReportNo(r.getReportNo());
            item.setBizType(r.getBizType());
            item.setBizNo(r.getBizNo());
            item.setRetryCount(r.getRetryCount());
            item.setMaxRetryCount(r.getMaxRetryCount());
            item.setNextRetryTime(r.getNextRetryTime());
            item.setFailReason(r.getFailReason());
            result.add(item);
        }
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public PlatformReportDashboardDTO.ManualRetryResult manualRetry(Long recordId, boolean forceResend) {
        PlatformReportDashboardDTO.ManualRetryResult retryResult = new PlatformReportDashboardDTO.ManualRetryResult();
        retryResult.setId(recordId);

        PlatformReportRecord record = platformReportRecordMapper.selectById(recordId);
        if (record == null) {
            retryResult.setSuccess(false);
            retryResult.setMessage("上报记录不存在");
            return retryResult;
        }

        if (record.getReportStatus() == REPORT_STATUS_SUCCESS && !forceResend) {
            retryResult.setSuccess(false);
            retryResult.setMessage("该记录已上报成功，无需补报。如需强制重发，请使用forceResend参数");
            return retryResult;
        }

        boolean success = false;
        String bizType = record.getBizType();
        String bizId = record.getBizId();

        record.setReportStatus(REPORT_STATUS_PENDING);
        record.setLastReportTime(LocalDateTime.now());
        record.setRetryCount(record.getRetryCount() != null ? record.getRetryCount() + 1 : 1);
        platformReportRecordMapper.updateById(record);

        try {
            if (BIZ_TYPE_WASTE_IN.equals(bizType)) {
                WasteInRecord wasteIn = wasteInRecordMapper.selectById(Long.parseLong(bizId));
                if (wasteIn != null) {
                    Map<String, Object> bizData = buildIotRktzData(wasteIn);
                    long startTime = System.currentTimeMillis();
                    success = doReport("/Account/saveRktz", bizData, wasteIn.getInNo());
                    long durationMs = System.currentTimeMillis() - startTime;
                    if (success) {
                        record.setNationalBizNo(getNationalPlatformBizNo(wasteIn.getInNo()));
                        updateReportRecordSuccess(record, null, record.getNationalBizNo(), durationMs);
                    } else {
                        updateReportRecordFailed(record, "手工补报IoT入库接口失败", durationMs);
                    }
                }
            } else if (BIZ_TYPE_WASTE_OUT.equals(bizType)) {
                WasteOutRecord wasteOut = wasteOutRecordMapper.selectById(Long.parseLong(bizId));
                if (wasteOut != null) {
                    Map<String, Object> bizData = buildIotCktzData(wasteOut);
                    long startTime = System.currentTimeMillis();
                    success = doReport("/Account/saveCktz", bizData, wasteOut.getOutNo());
                    long durationMs = System.currentTimeMillis() - startTime;
                    if (success) {
                        record.setNationalBizNo(getNationalPlatformBizNo(wasteOut.getOutNo()));
                        updateReportRecordSuccess(record, null, record.getNationalBizNo(), durationMs);
                    } else {
                        updateReportRecordFailed(record, "手工补报IoT出库接口失败", durationMs);
                    }
                }
            } else if (BIZ_TYPE_TRANSFER_ORDER.equals(bizType)) {
                WasteTransferOrder order = wasteTransferOrderMapper.selectById(Long.parseLong(bizId));
                if (order != null) {
                    Map<String, Object> bizData = buildElectronicManifestData(order);
                    long startTime = System.currentTimeMillis();
                    success = doReport("/manifest/report", bizData, order.getOrderNo());
                    long durationMs = System.currentTimeMillis() - startTime;
                    if (success) {
                        record.setNationalBizNo(getNationalPlatformBizNo(order.getOrderNo()));
                        updateReportRecordSuccess(record, null, record.getNationalBizNo(), durationMs);
                    } else {
                        updateReportRecordFailed(record, "手工补报电子联单失败", durationMs);
                    }
                }
            } else if (BIZ_TYPE_TRANSFER_COMPLETE.equals(bizType)) {
                WasteTransferOrder order = wasteTransferOrderMapper.selectById(Long.parseLong(bizId));
                if (order != null) {
                    Map<String, Object> bizData = buildTransferOrderCompletionData(order);
                    long startTime = System.currentTimeMillis();
                    success = doReport("/transfer/complete", bizData, order.getOrderNo());
                    long durationMs = System.currentTimeMillis() - startTime;
                    if (success) {
                        updateReportRecordSuccess(record, null, record.getNationalBizNo(), durationMs);
                    } else {
                        updateReportRecordFailed(record, "手工补报联单完成失败", durationMs);
                    }
                }
            }

            if (success) {
                retryResult.setSuccess(true);
                retryResult.setMessage("手工补报成功");
                retryResult.setNationalBizNo(record.getNationalBizNo());
            } else {
                retryResult.setSuccess(false);
                retryResult.setMessage("手工补报失败，请检查网络连接或联系管理员");
            }
        } catch (Exception e) {
            log.error("手工补报异常, recordId={}", recordId, e);
            record.setReportStatus(REPORT_STATUS_FAILED);
            record.setFailReason("手工补报异常: " + e.getMessage());
            platformReportRecordMapper.updateById(record);
            retryResult.setSuccess(false);
            retryResult.setMessage("手工补报异常: " + e.getMessage());
        }

        return retryResult;
    }

    private void scheduleRetry(PlatformReportRecord record, Object bizEntity, String bizType) {
        int currentRetryCount = record.getRetryCount() != null ? record.getRetryCount() : 0;
        if (currentRetryCount >= record.getMaxRetryCount()) {
            log.warn("上报已达最大重试次数, recordId={}, retryCount={}", record.getId(), currentRetryCount);
            updateReportRecordFailed(record, "已达最大重试次数(" + record.getMaxRetryCount() + "次)", 0L);
            return;
        }

        updateReportRecordRetrying(record, "准备进入重试队列");

        try {
            if (bizEntity instanceof WasteInRecord) {
                WasteInRecord wasteIn = (WasteInRecord) bizEntity;
                wasteMqProducer.sendWasteInReport(wasteIn);
            } else if (bizEntity instanceof WasteOutRecord) {
                WasteOutRecord wasteOut = (WasteOutRecord) bizEntity;
                wasteMqProducer.sendWasteOutReport(wasteOut);
            } else if (bizEntity instanceof WasteTransferOrder) {
                WasteTransferOrder order = (WasteTransferOrder) bizEntity;
                wasteMqProducer.sendTransferOrderReport(order);
            }
            log.info("已将上报失败数据加入RocketMQ重试队列, recordId={}, bizType={}, retryCount={}",
                    record.getId(), bizType, record.getRetryCount());
        } catch (Exception e) {
            log.error("加入重试队列失败, recordId={}", record.getId(), e);
        }
    }

    private LocalDateTime calculateNextRetryTime(int retryCount) {
        long[] delaySeconds = {10, 30, 60};
        long delay = retryCount <= delaySeconds.length ? delaySeconds[retryCount - 1] : delaySeconds[delaySeconds.length - 1];
        return LocalDateTime.now().plusSeconds(delay);
    }

    private Map<String, Object> buildIotRktzData(WasteInRecord record) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("rktzId", record.getOfflineId() != null ? record.getOfflineId() : record.getInNo());
        data.put("rktzCode", record.getInNo());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("wasteCategory", record.getWasteCategory());
        data.put("hazardCode", record.getHazardCode());
        data.put("weight", record.getWeight());
        data.put("weightUnit", "kg");
        data.put("containerCode", record.getContainerCode());
        data.put("storageLocation", record.getStorageLocation());
        data.put("weightSource", record.getWeightSource());
        data.put("scaleDevice", record.getScaleDevice());
        if (record.getProduceDate() != null) {
            data.put("produceDate", record.getProduceDate().format(DateTimeFormatter.ofPattern("yyyyMMdd")));
        }
        data.put("produceDepartment", record.getProduceDepartment());
        data.put("operatorName", record.getOperatorName());
        data.put("rkrq", LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss")));
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("remark", record.getRemark());
        return data;
    }

    private Map<String, Object> buildIotCktzData(WasteOutRecord record) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("cktzId", record.getOfflineId() != null ? record.getOfflineId() : record.getOutNo());
        data.put("cktzCode", record.getOutNo());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("weight", record.getWeight());
        data.put("weightUnit", "kg");
        data.put("containerCode", record.getContainerCode());
        data.put("receiverUnitId", record.getReceiverUnitId());
        data.put("receiverUnitName", record.getReceiverUnitName());
        data.put("transporterId", record.getTransporterId());
        data.put("transporterName", record.getTransporterName());
        data.put("vehicleNo", record.getVehicleNo());
        data.put("driverName", record.getDriverName());
        data.put("driverPhone", record.getDriverPhone());
        if (record.getOutTime() != null) {
            data.put("ckrq", record.getOutTime().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss")));
        }
        data.put("operatorName", record.getOperatorName());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("remark", record.getRemark());
        return data;
    }

    private Map<String, Object> buildElectronicManifestData(WasteTransferOrder order) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("ldId", order.getOfflineId() != null ? order.getOfflineId() : order.getOrderNo());
        data.put("ldCode", order.getOrderNo());
        data.put("ldType", order.getOrderType());
        data.put("generatorUnitCode", order.getGeneratorUnitCode());
        data.put("generatorUnitName", order.getGeneratorUnitName());
        data.put("receiverUnitCode", order.getReceiverUnitCode());
        data.put("receiverUnitName", order.getReceiverUnitName());
        data.put("receiverLicenseNo", order.getReceiverLicenseNo());
        data.put("transporterName", order.getTransporterName());
        data.put("transporterLicenseNo", order.getTransporterLicenseNo());
        data.put("vehicleNo", order.getVehicleNo());
        data.put("driverName", order.getDriverName());
        data.put("driverLicense", order.getDriverLicense());
        data.put("escortName", order.getEscortName());
        data.put("totalWeight", order.getTotalWeight());
        data.put("totalContainers", order.getTotalContainers());
        data.put("wasteDetails", order.getWasteDetails());
        data.put("route", order.getRoute());
        data.put("emergencyContact", order.getEmergencyContact());
        data.put("emergencyPhone", order.getEmergencyPhone());
        if (order.getStartTime() != null) {
            data.put("startTime", order.getStartTime().format(FORMATTER));
        }
        if (order.getEstimateArriveTime() != null) {
            data.put("estimateArriveTime", order.getEstimateArriveTime().format(FORMATTER));
        }
        data.put("status", order.getStatus());
        data.put("enterpriseId", order.getEnterpriseId());
        data.put("remark", order.getRemark());
        return data;
    }

    private boolean doReport(String apiPath, Map<String, Object> bizData, String bizNo) {
        String requestId = generateRequestId();
        String timestamp = LocalDateTime.now().format(FORMATTER);

        Map<String, Object> requestBody = buildRequestBody(bizData, requestId, timestamp);
        String requestJson = JsonUtils.toJson(requestBody);
        String fullUrl = platformUrl + apiPath;

        log.info("上报国家平台请求, url={}, bizNo={}", fullUrl, bizNo);
        log.debug("上报请求报文, bizNo={}, data={}", bizNo, requestJson);

        if (mockEnabled || StrUtil.isBlank(appId) || StrUtil.isBlank(appSecret)) {
            log.info("使用模拟模式上报国家平台, bizNo={}", bizNo);
            return mockPlatformCall(fullUrl, requestJson, bizNo);
        }

        return doRealHttpCall(fullUrl, requestJson, bizNo);
    }

    private Map<String, Object> buildRequestBody(Map<String, Object> bizData, String requestId, String timestamp) {
        Map<String, Object> requestBody = new LinkedHashMap<>();
        requestBody.put("appId", appId);
        requestBody.put("requestId", requestId);
        requestBody.put("timestamp", timestamp);
        requestBody.put("version", "1.0");

        String bizJson = JsonUtils.toJson(bizData);
        log.debug("上报业务明文数据, requestId={}, data={}", requestId, bizJson);

        String encryptedData = SmUtils.sm4Encrypt(sm4Key, bizJson);
        requestBody.put("data", encryptedData);

        TreeMap<String, String> signParams = new TreeMap<>();
        signParams.put("appId", appId);
        signParams.put("requestId", requestId);
        signParams.put("timestamp", timestamp);
        signParams.put("version", "1.0");
        signParams.put("data", encryptedData);
        String signContent = buildSignContent(signParams);

        String signature;
        if (StrUtil.isNotBlank(sm2PrivateKey)) {
            signature = SmUtils.sm2Sign(sm2PrivateKey, signContent);
            requestBody.put("signType", "SM2");
        } else {
            signature = SmUtils.sm3(signContent);
            requestBody.put("signType", "SM3");
        }
        requestBody.put("sign", signature);

        return requestBody;
    }

    private boolean doRealHttpCall(String url, String requestJson, String bizNo) {
        int retryCount = 0;
        Exception lastException = null;

        while (retryCount < retryTimes) {
            try {
                log.info("调用国家环保平台接口, 第{}次尝试, bizNo={}", retryCount + 1, bizNo);

                cn.hutool.http.HttpResponse response = cn.hutool.http.HttpRequest.post(url)
                        .header("Content-Type", "application/json;charset=UTF-8")
                        .header("Accept", "application/json")
                        .header("appId", appId)
                        .timeout(connectionTimeout)
                        .setConnectionTimeout(connectionTimeout)
                        .body(requestJson)
                        .execute();

                int httpStatus = response.getStatus();
                String responseBody = response.body();

                log.info("国家平台响应, httpStatus={}, bizNo={}, response={}", httpStatus, bizNo, responseBody);

                if (httpStatus == HTTP_SUCCESS) {
                    return parseResponse(responseBody, bizNo);
                } else {
                    log.warn("国家平台返回非200状态码, httpStatus={}, bizNo={}", httpStatus, bizNo);
                }

            } catch (Exception e) {
                lastException = e;
                log.error("调用国家平台接口失败, 第{}次尝试, bizNo={}", retryCount + 1, bizNo, e);
            }

            retryCount++;
            if (retryCount < retryTimes) {
                try {
                    long delay = (long) Math.pow(2, retryCount) * 1000;
                    log.info("等待{}ms后进行第{}次重试, bizNo={}", delay, retryCount + 1, bizNo);
                    Thread.sleep(delay);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }

        log.error("调用国家平台接口最终失败, 已重试{}次, bizNo={}", retryTimes, bizNo, lastException);
        return false;
    }

    private boolean parseResponse(String responseBody, String bizNo) {
        try {
            Map<String, Object> responseMap = JsonUtils.parseMap(responseBody);
            String code = responseMap.get("code") != null ? responseMap.get("code").toString() : null;
            String message = responseMap.get("message") != null ? responseMap.get("message").toString() : null;

            if (RESP_CODE_SUCCESS.equals(code)) {
                log.info("国家平台上报成功, bizNo={}, message={}", bizNo, message);
                return true;
            } else if (RESP_CODE_DUPLICATE.equals(code)) {
                log.warn("国家平台返回重复上报, bizNo={}, message={}", bizNo, message);
                return true;
            } else {
                log.error("国家平台返回错误, bizNo={}, code={}, message={}", bizNo, code, message);
                return false;
            }
        } catch (Exception e) {
            log.error("解析国家平台响应失败, bizNo={}, response={}", bizNo, responseBody, e);
            return false;
        }
    }

    private boolean mockPlatformCall(String url, String requestJson, String bizNo) {
        log.info("【模拟对接】调用国家环保平台API, url={}, request={}", url, requestJson);

        try {
            Thread.sleep(200L);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        boolean success = true;
        Map<String, Object> response = new HashMap<>();
        response.put("code", success ? "0" : "9999");
        response.put("message", success ? "success" : "系统繁忙");
        response.put("requestId", StrUtil.uuid().replace("-", ""));
        response.put("timestamp", LocalDateTime.now().format(FORMATTER));

        if (success) {
            Map<String, Object> data = new HashMap<>();
            data.put("bizNo", bizNo);
            data.put("platformBizNo", "GJ" + System.currentTimeMillis());
            data.put("reportTime", LocalDateTime.now().format(FORMATTER));
            response.put("data", data);
        }

        String responseJson = JsonUtils.toJson(response);
        log.info("【模拟对接】国家环保平台响应, bizNo={}, response={}", bizNo, responseJson);

        return success;
    }

    private Map<String, Object> buildTransferOrderData(WasteTransferOrder order) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("orderNo", order.getOrderNo());
        data.put("orderType", order.getOrderType());
        data.put("generatorUnitCode", order.getGeneratorUnitCode());
        data.put("generatorUnitName", order.getGeneratorUnitName());
        data.put("receiverUnitCode", order.getReceiverUnitCode());
        data.put("receiverUnitName", order.getReceiverUnitName());
        data.put("receiverLicenseNo", order.getReceiverLicenseNo());
        data.put("transporterName", order.getTransporterName());
        data.put("transporterLicenseNo", order.getTransporterLicenseNo());
        data.put("vehicleNo", order.getVehicleNo());
        data.put("driverName", order.getDriverName());
        data.put("driverLicense", order.getDriverLicense());
        data.put("escortName", order.getEscortName());
        data.put("totalWeight", order.getTotalWeight());
        data.put("totalContainers", order.getTotalContainers());
        data.put("wasteDetails", order.getWasteDetails());
        data.put("route", order.getRoute());
        data.put("emergencyContact", order.getEmergencyContact());
        data.put("emergencyPhone", order.getEmergencyPhone());
        if (order.getStartTime() != null) {
            data.put("startTime", order.getStartTime().format(FORMATTER));
        }
        if (order.getEstimateArriveTime() != null) {
            data.put("estimateArriveTime", order.getEstimateArriveTime().format(FORMATTER));
        }
        data.put("status", order.getStatus());
        data.put("remark", order.getRemark());
        return data;
    }

    private Map<String, Object> buildWasteInData(WasteInRecord record) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("inNo", record.getInNo());
        data.put("containerCode", record.getContainerCode());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("wasteCategory", record.getWasteCategory());
        data.put("hazardCode", record.getHazardCode());
        data.put("weight", record.getWeight());
        data.put("weightSource", record.getWeightSource());
        data.put("scaleDevice", record.getScaleDevice());
        if (record.getProduceDate() != null) {
            data.put("produceDate", record.getProduceDate().format(DateTimeFormatter.ofPattern("yyyyMMdd")));
        }
        data.put("produceDepartment", record.getProduceDepartment());
        data.put("storageLocation", record.getStorageLocation());
        data.put("operatorId", record.getOperatorId());
        data.put("operatorName", record.getOperatorName());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("remark", record.getRemark());
        return data;
    }

    private Map<String, Object> buildWasteOutData(WasteOutRecord record) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("outNo", record.getOutNo());
        data.put("transferOrderId", record.getTransferOrderId());
        data.put("containerCode", record.getContainerCode());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("weight", record.getWeight());
        data.put("receiverUnitId", record.getReceiverUnitId());
        data.put("receiverUnitName", record.getReceiverUnitName());
        data.put("transporterId", record.getTransporterId());
        data.put("transporterName", record.getTransporterName());
        data.put("vehicleNo", record.getVehicleNo());
        data.put("driverName", record.getDriverName());
        data.put("driverPhone", record.getDriverPhone());
        if (record.getOutTime() != null) {
            data.put("outTime", record.getOutTime().format(FORMATTER));
        }
        data.put("operatorId", record.getOperatorId());
        data.put("operatorName", record.getOperatorName());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("remark", record.getRemark());
        return data;
    }

    private Map<String, Object> buildTransferOrderCompletionData(WasteTransferOrder order) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("orderNo", order.getOrderNo());
        data.put("nationalOrderNo", order.getNationalOrderNo());
        data.put("status", order.getStatus());
        data.put("signStatus", order.getSignStatus());
        if (order.getSignTime() != null) {
            data.put("signTime", order.getSignTime().format(FORMATTER));
        }
        data.put("signPhoto", order.getSignPhoto());
        data.put("receiptPhoto", order.getReceiptPhoto());
        if (order.getCompleteTime() != null) {
            data.put("completeTime", order.getCompleteTime().format(FORMATTER));
        }
        if (order.getActualArriveTime() != null) {
            data.put("actualArriveTime", order.getActualArriveTime().format(FORMATTER));
        }
        data.put("totalWeight", order.getTotalWeight());
        data.put("totalContainers", order.getTotalContainers());
        data.put("wasteDetails", order.getWasteDetails());
        data.put("receiverUnitCode", order.getReceiverUnitCode());
        data.put("receiverUnitName", order.getReceiverUnitName());
        data.put("remark", order.getRemark());
        return data;
    }

    private String buildSignContent(TreeMap<String, String> params) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> entry : params.entrySet()) {
            if (sb.length() > 0) {
                sb.append("&");
            }
            sb.append(entry.getKey()).append("=").append(entry.getValue() == null ? "" : entry.getValue());
        }
        if (StrUtil.isNotBlank(appSecret)) {
            sb.append("&appSecret=").append(appSecret);
        }
        return sb.toString();
    }

    private String generateRequestId() {
        return StrUtil.uuid().replace("-", "");
    }
}
