package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.date.DateUtil;
import cn.hutool.core.io.FileUtil;
import cn.hutool.core.util.StrUtil;
import com.alibaba.excel.EasyExcel;
import com.alibaba.excel.ExcelWriter;
import com.alibaba.excel.write.metadata.WriteSheet;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.WasteLedgerDTO;
import com.waste.entity.*;
import com.waste.excel.WasteLedgerExcelData;
import com.waste.excel.WasteLedgerSummaryExcelData;
import com.waste.mapper.*;
import com.waste.service.FileService;
import com.waste.service.WasteLedgerService;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.JsonUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class WasteLedgerServiceImpl implements WasteLedgerService {

    @Autowired
    private WasteLedgerMapper wasteLedgerMapper;

    @Autowired
    private WasteLedgerDetailMapper wasteLedgerDetailMapper;

    @Autowired
    private WasteLedgerReportLogMapper wasteLedgerReportLogMapper;

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private EnterpriseInfoMapper enterpriseInfoMapper;

    @Autowired
    private FileService fileService;

    @Value("${waste.national-platform.url:https://api.ep.gov.cn/waste}")
    private String nationalPlatformUrl;

    @Value("${waste.national-platform.app-id:EP_APP_20240001}")
    private String nationalPlatformAppId;

    @Value("${waste.national-platform.app-secret:}")
    private String nationalPlatformAppSecret;

    @Value("${waste.national-platform.mock-enabled:false}")
    private boolean mockEnabled;

    @Value("${waste.national-platform.retry-times:3}")
    private int maxRetryTimes;

    private static final DateTimeFormatter DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMdd");

    @Override
    public IPage<WasteLedger> page(PageQuery pageQuery, WasteLedger wasteLedger, Long enterpriseId) {
        Page<WasteLedger> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteLedger> wrapper = buildQueryWrapper(wasteLedger, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteLedger::getCreateTime);
        }
        return wasteLedgerMapper.selectPage(page, wrapper);
    }

    @Override
    public WasteLedger getById(Long id) {
        WasteLedger ledger = wasteLedgerMapper.selectById(id);
        if (ledger == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return ledger;
    }

    @Override
    public List<WasteLedgerDetail> getDetailsByLedgerId(Long ledgerId) {
        LambdaQueryWrapper<WasteLedgerDetail> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteLedgerDetail::getLedgerId, ledgerId);
        wrapper.orderByAsc(WasteLedgerDetail::getId);
        return wasteLedgerDetailMapper.selectList(wrapper);
    }

    @Override
    public IPage<WasteLedgerReportLog> getReportLogs(PageQuery pageQuery, Long ledgerId, Long enterpriseId) {
        Page<WasteLedgerReportLog> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteLedgerReportLog> wrapper = new LambdaQueryWrapper<>();
        if (ledgerId != null) {
            wrapper.eq(WasteLedgerReportLog::getLedgerId, ledgerId);
        }
        if (enterpriseId != null) {
            wrapper.eq(WasteLedgerReportLog::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(WasteLedgerReportLog::getReportTime);
        return wasteLedgerReportLogMapper.selectPage(page, wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public WasteLedger generateLedger(WasteLedgerDTO dto, Long enterpriseId) {
        if (StrUtil.isBlank(dto.getLedgerType())) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "台账类型不能为空");
        }
        if (dto.getPeriodYear() == null) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "统计年份不能为空");
        }
        if ("MONTHLY".equals(dto.getLedgerType()) && dto.getPeriodMonth() == null) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "统计月份不能为空");
        }

        LocalDate startDate, endDate;
        if ("MONTHLY".equals(dto.getLedgerType())) {
            startDate = LocalDate.of(dto.getPeriodYear(), dto.getPeriodMonth(), 1);
            endDate = startDate.with(TemporalAdjusters.lastDayOfMonth());
        } else {
            startDate = LocalDate.of(dto.getPeriodYear(), 1, 1);
            endDate = LocalDate.of(dto.getPeriodYear(), 12, 31);
        }

        LambdaQueryWrapper<WasteLedger> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(WasteLedger::getEnterpriseId, enterpriseId);
        existWrapper.eq(WasteLedger::getLedgerType, dto.getLedgerType());
        existWrapper.eq(WasteLedger::getPeriodYear, dto.getPeriodYear());
        if ("MONTHLY".equals(dto.getLedgerType())) {
            existWrapper.eq(WasteLedger::getPeriodMonth, dto.getPeriodMonth());
        }
        WasteLedger existLedger = wasteLedgerMapper.selectOne(existWrapper);
        if (existLedger != null) {
            if (existLedger.getGenerateStatus() == 1) {
                throw new BusinessException(ResultCode.PARAM_ERROR, "该周期台账正在生成中，请稍后");
            }
            deleteLedgerAndDetails(existLedger.getId());
        }

        WasteLedger ledger = new WasteLedger();
        ledger.setLedgerNo(IdGeneratorUtils.generateLedgerNo());
        ledger.setLedgerType(dto.getLedgerType());
        ledger.setPeriodYear(dto.getPeriodYear());
        ledger.setPeriodMonth(dto.getPeriodMonth());
        ledger.setStartDate(startDate);
        ledger.setEndDate(endDate);
        ledger.setEnterpriseId(enterpriseId);
        ledger.setGenerateStatus(0);
        ledger.setReportStatus(0);
        ledger.setRemark(dto.getRemark());

        EnterpriseInfo enterprise = enterpriseInfoMapper.selectById(enterpriseId);
        if (enterprise != null) {
            ledger.setEnterpriseName(enterprise.getEnterpriseName());
            ledger.setEnterpriseCode(enterprise.getEnterpriseCode());
        }

        wasteLedgerMapper.insert(ledger);

        generateLedgerDataAsync(ledger.getId(), enterpriseId, startDate, endDate);

        return ledger;
    }

    @Async
    @Transactional(rollbackFor = Exception.class)
    public void generateLedgerDataAsync(Long ledgerId, Long enterpriseId, LocalDate startDate, LocalDate endDate) {
        try {
            WasteLedger ledger = wasteLedgerMapper.selectById(ledgerId);
            if (ledger == null) {
                return;
            }

            ledger.setGenerateStatus(1);
            wasteLedgerMapper.updateById(ledger);

            List<WasteLedgerDetail> details = new ArrayList<>();

            LocalDateTime startDateTime = startDate.atStartOfDay();
            LocalDateTime endDateTime = endDate.atTime(23, 59, 59);

            List<WasteInRecord> inRecords = queryInRecords(enterpriseId, startDateTime, endDateTime);
            List<WasteOutRecord> outRecords = queryOutRecords(enterpriseId, startDateTime, endDateTime);

            for (int i = 0; i < inRecords.size(); i++) {
                WasteInRecord record = inRecords.get(i);
                WasteLedgerDetail detail = new WasteLedgerDetail();
                detail.setLedgerId(ledgerId);
                detail.setLedgerNo(ledger.getLedgerNo());
                detail.setDetailType("IN");
                detail.setChangeType("IN");
                detail.setWasteId(record.getWasteId());
                detail.setWasteCode(record.getWasteCode());
                detail.setWasteName(record.getWasteName());
                detail.setWasteCategory(record.getWasteCategory());
                detail.setHazardCode(record.getHazardCode());
                detail.setContainerId(record.getContainerId());
                detail.setContainerCode(record.getContainerCode());
                detail.setRecordNo(record.getInNo());
                detail.setWeight(record.getWeight());
                detail.setOperateTime(record.getCreateTime());
                detail.setOperatorName(record.getOperatorName());
                detail.setRemark(record.getRemark());
                detail.setCreateTime(LocalDateTime.now());
                detail.setUpdateTime(LocalDateTime.now());
                details.add(detail);
            }

            for (int i = 0; i < outRecords.size(); i++) {
                WasteOutRecord record = outRecords.get(i);
                WasteLedgerDetail detail = new WasteLedgerDetail();
                detail.setLedgerId(ledgerId);
                detail.setLedgerNo(ledger.getLedgerNo());
                detail.setDetailType("OUT");
                detail.setChangeType("OUT");
                detail.setWasteId(record.getWasteId());
                detail.setWasteCode(record.getWasteCode());
                detail.setWasteName(record.getWasteName());
                detail.setContainerId(record.getContainerId());
                detail.setContainerCode(record.getContainerCode());
                detail.setRecordNo(record.getOutNo());
                detail.setWeight(record.getWeight());
                detail.setOperateTime(record.getOutTime() != null ? record.getOutTime() : record.getCreateTime());
                detail.setOperatorName(record.getOperatorName());
                detail.setRemark(record.getRemark());
                detail.setCreateTime(LocalDateTime.now());
                detail.setUpdateTime(LocalDateTime.now());
                details.add(detail);
            }

            if (CollUtil.isNotEmpty(details)) {
                for (WasteLedgerDetail detail : details) {
                    wasteLedgerDetailMapper.insert(detail);
                }
            }

            BigDecimal totalInWeight = inRecords.stream()
                    .map(WasteInRecord::getWeight)
                    .filter(Objects::nonNull)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            BigDecimal totalOutWeight = outRecords.stream()
                    .map(WasteOutRecord::getWeight)
                    .filter(Objects::nonNull)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            BigDecimal beginInventoryWeight = calculateBeginInventory(enterpriseId, startDate);
            BigDecimal endInventoryWeight = calculateEndInventory(enterpriseId, endDate);

            ledger.setTotalInCount(inRecords.size());
            ledger.setTotalInWeight(totalInWeight);
            ledger.setTotalOutCount(outRecords.size());
            ledger.setTotalOutWeight(totalOutWeight);
            ledger.setBeginInventoryWeight(beginInventoryWeight);
            ledger.setEndInventoryWeight(endInventoryWeight);

            String excelUrl = generateExcelFile(ledger, details);
            ledger.setFileUrl(excelUrl);
            ledger.setFileName(generateFileName(ledger));

            ledger.setGenerateStatus(2);
            ledger.setGenerateTime(LocalDateTime.now());
            wasteLedgerMapper.updateById(ledger);

            log.info("台账生成成功, ledgerId={}, ledgerNo={}", ledgerId, ledger.getLedgerNo());

        } catch (Exception e) {
            log.error("台账生成失败, ledgerId={}", ledgerId, e);
            WasteLedger ledger = wasteLedgerMapper.selectById(ledgerId);
            if (ledger != null) {
                ledger.setGenerateStatus(3);
                ledger.setGenerateFailReason(e.getMessage());
                wasteLedgerMapper.updateById(ledger);
            }
        }
    }

    @Override
    public WasteLedger regenerateLedger(Long id) {
        WasteLedger ledger = getById(id);
        WasteLedgerDTO dto = new WasteLedgerDTO();
        dto.setLedgerType(ledger.getLedgerType());
        dto.setPeriodYear(ledger.getPeriodYear());
        dto.setPeriodMonth(ledger.getPeriodMonth());
        dto.setRemark(ledger.getRemark());
        return generateLedger(dto, ledger.getEnterpriseId());
    }

    @Override
    public String previewLedger(Long id) {
        WasteLedger ledger = getById(id);
        if (ledger.getGenerateStatus() != 2) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "台账尚未生成完成，无法预览");
        }
        if (StrUtil.isBlank(ledger.getFileUrl())) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "台账文件不存在");
        }
        return ledger.getFileUrl();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void reportLedger(Long id, String reportType) {
        WasteLedger ledger = getById(id);
        if (ledger.getGenerateStatus() != 2) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "台账尚未生成完成，无法上报");
        }
        if (ledger.getReportStatus() == 1) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "台账正在上报中，请稍后");
        }

        reportLedgerAsync(ledger, reportType);
    }

    @Async
    @Transactional(rollbackFor = Exception.class)
    public void reportLedgerAsync(WasteLedger ledger, String reportType) {
        long startTime = System.currentTimeMillis();
        WasteLedgerReportLog reportLog = new WasteLedgerReportLog();
        reportLog.setLogNo(IdGeneratorUtils.generateLedgerReportLogNo());
        reportLog.setLedgerId(ledger.getId());
        reportLog.setLedgerNo(ledger.getLedgerNo());
        reportLog.setReportType(reportType);
        reportLog.setReportTime(LocalDateTime.now());
        reportLog.setEnterpriseId(ledger.getEnterpriseId());

        try {
            ledger.setReportStatus(1);
            wasteLedgerMapper.updateById(ledger);

            Map<String, Object> requestData = buildReportRequestData(ledger);
            String requestPayload = JsonUtils.toJsonString(requestData);
            reportLog.setRequestPayload(requestPayload);

            String responsePayload;
            String platformLedgerNo;

            if (mockEnabled) {
                responsePayload = mockReportResponse(ledger);
                platformLedgerNo = "MOCK_" + System.currentTimeMillis();
                reportLog.setReportStatus(1);
            } else {
                ResponseEntity<String> response = callNationalPlatformApi(requestData);
                responsePayload = response.getBody();
                Map<String, Object> responseMap = JsonUtils.parseMap(responsePayload);
                if (responseMap != null && "success".equals(responseMap.get("code"))) {
                    platformLedgerNo = (String) responseMap.get("data");
                    reportLog.setReportStatus(1);
                } else {
                    throw new BusinessException(ResultCode.SYSTEM_ERROR,
                            responseMap != null ? (String) responseMap.get("message") : "上报失败");
                }
            }

            reportLog.setResponsePayload(responsePayload);
            reportLog.setPlatformLedgerNo(platformLedgerNo);

            ledger.setReportStatus(2);
            ledger.setReportTime(LocalDateTime.now());
            ledger.setPlatformLedgerNo(platformLedgerNo);
            ledger.setRetryCount(ledger.getRetryCount() != null ? ledger.getRetryCount() + 1 : 1);
            wasteLedgerMapper.updateById(ledger);

            log.info("台账上报成功, ledgerId={}, platformLedgerNo={}", ledger.getId(), platformLedgerNo);

        } catch (Exception e) {
            log.error("台账上报失败, ledgerId={}", ledger.getId(), e);
            reportLog.setReportStatus(2);
            reportLog.setFailReason(e.getMessage());

            ledger.setReportStatus(3);
            ledger.setReportFailReason(e.getMessage());
            ledger.setRetryCount(ledger.getRetryCount() != null ? ledger.getRetryCount() + 1 : 1);
            wasteLedgerMapper.updateById(ledger);
        } finally {
            reportLog.setDurationMs(System.currentTimeMillis() - startTime);
            reportLog.setCreateTime(LocalDateTime.now());
            reportLog.setUpdateTime(LocalDateTime.now());
            wasteLedgerReportLogMapper.insert(reportLog);
        }
    }

    @Override
    public void batchReport(List<Long> ids) {
        for (Long id : ids) {
            try {
                reportLedger(id, "MANUAL");
            } catch (Exception e) {
                log.error("批量上报失败, ledgerId={}", id, e);
            }
        }
    }

    @Override
    public void retryReport(Long id) {
        WasteLedger ledger = getById(id);
        if (ledger.getRetryCount() != null && ledger.getRetryCount() >= maxRetryTimes) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "已达最大重试次数，请联系管理员");
        }
        reportLedger(id, "RETRY");
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        deleteLedgerAndDetails(id);
    }

    private void deleteLedgerAndDetails(Long ledgerId) {
        LambdaQueryWrapper<WasteLedgerDetail> detailWrapper = new LambdaQueryWrapper<>();
        detailWrapper.eq(WasteLedgerDetail::getLedgerId, ledgerId);
        wasteLedgerDetailMapper.delete(detailWrapper);

        LambdaQueryWrapper<WasteLedgerReportLog> logWrapper = new LambdaQueryWrapper<>();
        logWrapper.eq(WasteLedgerReportLog::getLedgerId, ledgerId);
        wasteLedgerReportLogMapper.delete(logWrapper);

        wasteLedgerMapper.deleteById(ledgerId);
    }

    @Override
    public WasteLedger generateMonthlyLedger(Integer year, Integer month, Long enterpriseId) {
        WasteLedgerDTO dto = new WasteLedgerDTO();
        dto.setLedgerType("MONTHLY");
        dto.setPeriodYear(year);
        dto.setPeriodMonth(month);
        return generateLedger(dto, enterpriseId);
    }

    @Override
    public WasteLedger generateYearlyLedger(Integer year, Long enterpriseId) {
        WasteLedgerDTO dto = new WasteLedgerDTO();
        dto.setLedgerType("YEARLY");
        dto.setPeriodYear(year);
        return generateLedger(dto, enterpriseId);
    }

    @Override
    public void autoGenerateMonthlyLedger() {
        log.info("开始自动生成月度台账...");
        List<EnterpriseInfo> enterprises = enterpriseInfoMapper.selectList(null);
        LocalDate now = LocalDate.now();
        LocalDate lastMonth = now.minusMonths(1);

        for (EnterpriseInfo enterprise : enterprises) {
            try {
                generateMonthlyLedger(lastMonth.getYear(), lastMonth.getMonthValue(), enterprise.getId());
                log.info("企业[{}]月度台账生成任务已提交", enterprise.getEnterpriseName());
            } catch (Exception e) {
                log.error("企业[{}]月度台账生成失败", enterprise.getEnterpriseName(), e);
            }
        }
    }

    @Override
    public void autoGenerateYearlyLedger() {
        log.info("开始自动生成年度台账...");
        List<EnterpriseInfo> enterprises = enterpriseInfoMapper.selectList(null);
        LocalDate now = LocalDate.now();
        int lastYear = now.getYear() - 1;

        for (EnterpriseInfo enterprise : enterprises) {
            try {
                generateYearlyLedger(lastYear, enterprise.getId());
                log.info("企业[{}]年度台账生成任务已提交", enterprise.getEnterpriseName());
            } catch (Exception e) {
                log.error("企业[{}]年度台账生成失败", enterprise.getEnterpriseName(), e);
            }
        }
    }

    @Override
    public void autoReportLedger() {
        log.info("开始自动上报台账...");
        LambdaQueryWrapper<WasteLedger> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(WasteLedger::getReportStatus, 0, 3);
        wrapper.eq(WasteLedger::getGenerateStatus, 2);
        List<WasteLedger> ledgers = wasteLedgerMapper.selectList(wrapper);

        for (WasteLedger ledger : ledgers) {
            try {
                if (ledger.getRetryCount() != null && ledger.getRetryCount() >= maxRetryTimes) {
                    continue;
                }
                reportLedgerAsync(ledger, "AUTO");
            } catch (Exception e) {
                log.error("台账自动上报失败, ledgerId={}", ledger.getId(), e);
            }
        }
    }

    private List<WasteInRecord> queryInRecords(Long enterpriseId, LocalDateTime startDateTime, LocalDateTime endDateTime) {
        LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
        wrapper.ge(WasteInRecord::getCreateTime, startDateTime);
        wrapper.le(WasteInRecord::getCreateTime, endDateTime);
        wrapper.ne(WasteInRecord::getStatus, 0);
        wrapper.orderByAsc(WasteInRecord::getCreateTime);
        return wasteInRecordMapper.selectList(wrapper);
    }

    private List<WasteOutRecord> queryOutRecords(Long enterpriseId, LocalDateTime startDateTime, LocalDateTime endDateTime) {
        LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
        wrapper.ge(WasteOutRecord::getCreateTime, startDateTime);
        wrapper.le(WasteOutRecord::getCreateTime, endDateTime);
        wrapper.ne(WasteOutRecord::getStatus, 0);
        wrapper.orderByAsc(WasteOutRecord::getCreateTime);
        return wasteOutRecordMapper.selectList(wrapper);
    }

    private BigDecimal calculateBeginInventory(Long enterpriseId, LocalDate startDate) {
        LocalDateTime startDateTime = startDate.atStartOfDay();
        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        wrapper.eq(WasteInventory::getStatus, 1);
        wrapper.le(WasteInventory::getInDate, startDate);
        List<WasteInventory> inventories = wasteInventoryMapper.selectList(wrapper);

        return inventories.stream()
                .map(WasteInventory::getWeight)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private BigDecimal calculateEndInventory(Long enterpriseId, LocalDate endDate) {
        LocalDateTime endDateTime = endDate.atTime(23, 59, 59);
        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        wrapper.eq(WasteInventory::getStatus, 1);
        wrapper.le(WasteInventory::getCreateTime, endDateTime);
        List<WasteInventory> inventories = wasteInventoryMapper.selectList(wrapper);

        return inventories.stream()
                .map(WasteInventory::getWeight)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private String generateExcelFile(WasteLedger ledger, List<WasteLedgerDetail> details) {
        String fileName = generateFileName(ledger);
        String tempPath = System.getProperty("java.io.tmpdir") + File.separator + fileName;

        try {
            List<WasteLedgerSummaryExcelData> summaryData = buildSummaryData(ledger);
            List<WasteLedgerExcelData> detailData = buildDetailData(details);

            try (ExcelWriter excelWriter = EasyExcel.write(tempPath).build()) {
                WriteSheet summarySheet = EasyExcel.writerSheet(0, "汇总信息")
                        .head(WasteLedgerSummaryExcelData.class)
                        .build();
                excelWriter.write(summaryData, summarySheet);

                WriteSheet detailSheet = EasyExcel.writerSheet(1, "明细信息")
                        .head(WasteLedgerExcelData.class)
                        .build();
                excelWriter.write(detailData, detailSheet);
            }

            byte[] fileBytes = FileUtil.readBytes(tempPath);
            InputStream inputStream = new ByteArrayInputStream(fileBytes);

            String fileUrl = fileService.upload(inputStream, fileName, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    fileBytes.length, "waste_ledger", ledger.getLedgerNo(), ledger.getEnterpriseId());

            FileUtil.del(tempPath);

            return fileUrl;
        } catch (Exception e) {
            log.error("生成Excel文件失败, ledgerId={}", ledger.getId(), e);
            FileUtil.del(tempPath);
            throw new BusinessException(ResultCode.SYSTEM_ERROR, "生成Excel文件失败: " + e.getMessage());
        }
    }

    private String generateFileName(WasteLedger ledger) {
        String type = "MONTHLY".equals(ledger.getLedgerType()) ? "月报" : "年报";
        String period;
        if ("MONTHLY".equals(ledger.getLedgerType())) {
            period = String.format("%04d%02d", ledger.getPeriodYear(), ledger.getPeriodMonth());
        } else {
            period = String.format("%04d", ledger.getPeriodYear());
        }
        return String.format("危废电子台账_%s_%s_%s.xlsx", type, period, ledger.getLedgerNo());
    }

    private List<WasteLedgerSummaryExcelData> buildSummaryData(WasteLedger ledger) {
        List<WasteLedgerSummaryExcelData> list = new ArrayList<>();

        WasteLedgerSummaryExcelData enterpriseInfo = new WasteLedgerSummaryExcelData();
        enterpriseInfo.setItem("企业名称");
        enterpriseInfo.setRemark(ledger.getEnterpriseName());
        list.add(enterpriseInfo);

        WasteLedgerSummaryExcelData enterpriseCode = new WasteLedgerSummaryExcelData();
        enterpriseCode.setItem("统一社会信用代码");
        enterpriseCode.setRemark(ledger.getEnterpriseCode());
        list.add(enterpriseCode);

        WasteLedgerSummaryExcelData period = new WasteLedgerSummaryExcelData();
        period.setItem("统计周期");
        period.setRemark(ledger.getStartDate().format(DATE_FORMATTER) + " 至 " + ledger.getEndDate().format(DATE_FORMATTER));
        list.add(period);

        WasteLedgerSummaryExcelData generateTime = new WasteLedgerSummaryExcelData();
        generateTime.setItem("生成时间");
        generateTime.setRemark(LocalDateTime.now().format(DATE_TIME_FORMATTER));
        list.add(generateTime);

        list.add(new WasteLedgerSummaryExcelData());

        WasteLedgerSummaryExcelData header = new WasteLedgerSummaryExcelData();
        header.setItem("项目");
        header.setCount(0);
        header.setWeight(BigDecimal.ZERO);
        header.setRemark("备注");
        list.add(header);

        WasteLedgerSummaryExcelData beginInventory = new WasteLedgerSummaryExcelData();
        beginInventory.setItem("期初库存");
        beginInventory.setWeight(ledger.getBeginInventoryWeight());
        list.add(beginInventory);

        WasteLedgerSummaryExcelData totalIn = new WasteLedgerSummaryExcelData();
        totalIn.setItem("本期入库");
        totalIn.setCount(ledger.getTotalInCount());
        totalIn.setWeight(ledger.getTotalInWeight());
        list.add(totalIn);

        WasteLedgerSummaryExcelData totalOut = new WasteLedgerSummaryExcelData();
        totalOut.setItem("本期出库");
        totalOut.setCount(ledger.getTotalOutCount());
        totalOut.setWeight(ledger.getTotalOutWeight());
        list.add(totalOut);

        WasteLedgerSummaryExcelData endInventory = new WasteLedgerSummaryExcelData();
        endInventory.setItem("期末库存");
        endInventory.setWeight(ledger.getEndInventoryWeight());
        list.add(endInventory);

        return list;
    }

    private List<WasteLedgerExcelData> buildDetailData(List<WasteLedgerDetail> details) {
        List<WasteLedgerExcelData> list = new ArrayList<>();

        for (int i = 0; i < details.size(); i++) {
            WasteLedgerDetail detail = details.get(i);
            WasteLedgerExcelData data = new WasteLedgerExcelData();
            data.setSeq(i + 1);
            data.setDetailType("IN".equals(detail.getDetailType()) ? "入库" : "出库");
            data.setRecordNo(detail.getRecordNo());
            data.setWasteCode(detail.getWasteCode());
            data.setWasteName(detail.getWasteName());
            data.setWasteCategory(detail.getWasteCategory());
            data.setHazardCode(detail.getHazardCode());
            data.setContainerCode(detail.getContainerCode());
            data.setWeight(detail.getWeight());
            data.setChangeType("IN".equals(detail.getChangeType()) ? "入库" : "出库");
            data.setOperateTime(detail.getOperateTime() != null ? detail.getOperateTime().format(DATE_TIME_FORMATTER) : "");
            data.setOperatorName(detail.getOperatorName());
            data.setRemark(detail.getRemark());
            list.add(data);
        }

        return list;
    }

    private Map<String, Object> buildReportRequestData(WasteLedger ledger) {
        Map<String, Object> data = new HashMap<>();
        data.put("ledgerNo", ledger.getLedgerNo());
        data.put("ledgerType", ledger.getLedgerType());
        data.put("periodYear", ledger.getPeriodYear());
        data.put("periodMonth", ledger.getPeriodMonth());
        data.put("startDate", ledger.getStartDate().format(DATE_FORMATTER));
        data.put("endDate", ledger.getEndDate().format(DATE_FORMATTER));
        data.put("enterpriseName", ledger.getEnterpriseName());
        data.put("enterpriseCode", ledger.getEnterpriseCode());
        data.put("totalInCount", ledger.getTotalInCount());
        data.put("totalInWeight", ledger.getTotalInWeight());
        data.put("totalOutCount", ledger.getTotalOutCount());
        data.put("totalOutWeight", ledger.getTotalOutWeight());
        data.put("beginInventoryWeight", ledger.getBeginInventoryWeight());
        data.put("endInventoryWeight", ledger.getEndInventoryWeight());
        data.put("fileUrl", ledger.getFileUrl());
        data.put("reportTime", LocalDateTime.now().format(DATE_TIME_FORMATTER));

        Map<String, String> header = new HashMap<>();
        header.put("appId", nationalPlatformAppId);
        header.put("timestamp", String.valueOf(System.currentTimeMillis()));
        header.put("sign", generateSign(data));

        Map<String, Object> request = new HashMap<>();
        request.put("header", header);
        request.put("data", data);

        return request;
    }

    private String generateSign(Map<String, Object> data) {
        String dataStr = JsonUtils.toJsonString(data);
        return cn.hutool.crypto.SecureUtil.md5(dataStr + nationalPlatformAppSecret);
    }

    private ResponseEntity<String> callNationalPlatformApi(Map<String, Object> requestData) {
        RestTemplate restTemplate = new RestTemplate();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("appId", nationalPlatformAppId);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestData, headers);
        String url = nationalPlatformUrl + "/ledger/report";

        return restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
    }

    private String mockReportResponse(WasteLedger ledger) {
        Map<String, Object> response = new HashMap<>();
        response.put("code", "success");
        response.put("message", "上报成功");
        response.put("data", "PROV_" + ledger.getLedgerNo());
        response.put("timestamp", System.currentTimeMillis());
        return JsonUtils.toJsonString(response);
    }

    private LambdaQueryWrapper<WasteLedger> buildQueryWrapper(WasteLedger wasteLedger, Long enterpriseId) {
        LambdaQueryWrapper<WasteLedger> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WasteLedger::getEnterpriseId, enterpriseId);
        }
        if (StrUtil.isNotBlank(wasteLedger.getLedgerNo())) {
            wrapper.like(WasteLedger::getLedgerNo, wasteLedger.getLedgerNo());
        }
        if (StrUtil.isNotBlank(wasteLedger.getLedgerType())) {
            wrapper.eq(WasteLedger::getLedgerType, wasteLedger.getLedgerType());
        }
        if (wasteLedger.getPeriodYear() != null) {
            wrapper.eq(WasteLedger::getPeriodYear, wasteLedger.getPeriodYear());
        }
        if (wasteLedger.getPeriodMonth() != null) {
            wrapper.eq(WasteLedger::getPeriodMonth, wasteLedger.getPeriodMonth());
        }
        if (wasteLedger.getGenerateStatus() != null) {
            wrapper.eq(WasteLedger::getGenerateStatus, wasteLedger.getGenerateStatus());
        }
        if (wasteLedger.getReportStatus() != null) {
            wrapper.eq(WasteLedger::getReportStatus, wasteLedger.getReportStatus());
        }
        return wrapper;
    }
}
