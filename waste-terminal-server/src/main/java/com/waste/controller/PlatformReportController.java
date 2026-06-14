package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.PlatformReportDashboardDTO;
import com.waste.entity.PlatformReportRecord;
import com.waste.mapper.PlatformReportRecordMapper;
import com.waste.service.NationalPlatformService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/platform-report")
public class PlatformReportController {

    @Autowired
    private NationalPlatformService nationalPlatformService;

    @Autowired
    private PlatformReportRecordMapper platformReportRecordMapper;

    @GetMapping("/dashboard")
    @RequiresLogin
    public Result<PlatformReportDashboardDTO> dashboard() {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }

        PlatformReportDashboardDTO dashboard = new PlatformReportDashboardDTO();
        dashboard.setStatistics(nationalPlatformService.getReportStatistics(enterpriseId));
        dashboard.setFailedReports(nationalPlatformService.getFailedReports(enterpriseId, 20));
        dashboard.setRetryQueue(nationalPlatformService.getRetryQueue(enterpriseId));

        LambdaQueryWrapper<PlatformReportRecord> recentWrapper = new LambdaQueryWrapper<>();
        recentWrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        recentWrapper.orderByDesc(PlatformReportRecord::getLastReportTime);
        recentWrapper.last("LIMIT 20");
        List<PlatformReportRecord> recentRecords = platformReportRecordMapper.selectList(recentWrapper);

        List<PlatformReportDashboardDTO.RecentReportItem> recentItems = new ArrayList<>();
        for (PlatformReportRecord r : recentRecords) {
            PlatformReportDashboardDTO.RecentReportItem item = new PlatformReportDashboardDTO.RecentReportItem();
            item.setId(r.getId());
            item.setReportNo(r.getReportNo());
            item.setBizType(r.getBizType());
            item.setBizNo(r.getBizNo());
            item.setReportStatus(r.getReportStatus());
            item.setRetryCount(r.getRetryCount());
            item.setLastReportTime(r.getLastReportTime());
            item.setFailReason(r.getFailReason());
            item.setNationalBizNo(r.getNationalBizNo());
            recentItems.add(item);
        }
        dashboard.setRecentReports(recentItems);

        return Result.success(dashboard);
    }

    @GetMapping("/statistics")
    @RequiresLogin
    public Result<PlatformReportDashboardDTO.ReportStatistics> statistics() {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(nationalPlatformService.getReportStatistics(enterpriseId));
    }

    @GetMapping("/failed")
    @RequiresLogin
    public Result<List<PlatformReportDashboardDTO.FailedReportItem>> failedReports(
            @RequestParam(required = false) Integer limit) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(nationalPlatformService.getFailedReports(enterpriseId, limit));
    }

    @GetMapping("/retry-queue")
    @RequiresLogin
    public Result<List<PlatformReportDashboardDTO.RetryQueueItem>> retryQueue() {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(nationalPlatformService.getRetryQueue(enterpriseId));
    }

    @PostMapping("/manual-retry/{id}")
    @RequiresLogin
    public Result<PlatformReportDashboardDTO.ManualRetryResult> manualRetry(
            @PathVariable Long id,
            @RequestParam(required = false, defaultValue = "false") Boolean forceResend) {
        PlatformReportDashboardDTO.ManualRetryResult result = nationalPlatformService.manualRetry(id, forceResend);
        if (result.getSuccess()) {
            return Result.success(result);
        } else {
            return Result.fail(result.getMessage());
        }
    }

    @PostMapping("/batch-manual-retry")
    @RequiresLogin
    public Result<List<PlatformReportDashboardDTO.ManualRetryResult>> batchManualRetry(
            @RequestBody List<Long> ids,
            @RequestParam(required = false, defaultValue = "false") Boolean forceResend) {
        List<PlatformReportDashboardDTO.ManualRetryResult> results = new ArrayList<>();
        for (Long id : ids) {
            results.add(nationalPlatformService.manualRetry(id, forceResend));
        }
        return Result.success(results);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<PlatformReportRecord>> page(
            PageQuery pageQuery,
            @RequestParam(required = false) Integer reportStatus,
            @RequestParam(required = false) String bizType) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }

        LambdaQueryWrapper<PlatformReportRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(PlatformReportRecord::getEnterpriseId, enterpriseId);
        if (reportStatus != null) {
            wrapper.eq(PlatformReportRecord::getReportStatus, reportStatus);
        }
        if (bizType != null && !bizType.isEmpty()) {
            wrapper.eq(PlatformReportRecord::getBizType, bizType);
        }
        wrapper.orderByDesc(PlatformReportRecord::getLastReportTime);

        IPage<PlatformReportRecord> page = platformReportRecordMapper.selectPage(
                new Page<>(pageQuery.getCurrent(), pageQuery.getSize()), wrapper);

        return Result.success(PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords()));
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<PlatformReportRecord> detail(@PathVariable Long id) {
        return Result.success(platformReportRecordMapper.selectById(id));
    }
}
