package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.WasteLedgerDTO;
import com.waste.entity.WasteLedger;
import com.waste.entity.WasteLedgerDetail;
import com.waste.entity.WasteLedgerReportLog;

import java.util.List;

public interface WasteLedgerService {

    IPage<WasteLedger> page(PageQuery pageQuery, WasteLedger wasteLedger, Long enterpriseId);

    WasteLedger getById(Long id);

    List<WasteLedgerDetail> getDetailsByLedgerId(Long ledgerId);

    IPage<WasteLedgerReportLog> getReportLogs(PageQuery pageQuery, Long ledgerId, Long enterpriseId);

    WasteLedger generateLedger(WasteLedgerDTO dto, Long enterpriseId);

    WasteLedger regenerateLedger(Long id);

    String previewLedger(Long id);

    void reportLedger(Long id, String reportType);

    void batchReport(List<Long> ids);

    void retryReport(Long id);

    void delete(Long id);

    WasteLedger generateMonthlyLedger(Integer year, Integer month, Long enterpriseId);

    WasteLedger generateYearlyLedger(Integer year, Long enterpriseId);

    void autoGenerateMonthlyLedger();

    void autoGenerateYearlyLedger();

    void autoReportLedger();
}
