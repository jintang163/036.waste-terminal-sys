package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.Result;
import com.waste.dto.WasteLedgerDTO;
import com.waste.entity.WasteLedger;
import com.waste.entity.WasteLedgerDetail;
import com.waste.entity.WasteLedgerReportLog;
import com.waste.service.WasteLedgerService;
import com.waste.utils.UserContext;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import io.swagger.annotations.ApiParam;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Api(tags = "电子台账管理")
@RestController
@RequestMapping("/waste-ledger")
public class WasteLedgerController {

    @Autowired
    private WasteLedgerService wasteLedgerService;

    @ApiOperation("台账列表分页查询")
    @GetMapping("/page")
    @RequiresLogin
    public Result<IPage<WasteLedger>> page(PageQuery pageQuery, WasteLedger wasteLedger,
                                            @ApiParam("企业ID") @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteLedger> page = wasteLedgerService.page(pageQuery, wasteLedger, enterpriseId);
        return Result.success(page);
    }

    @ApiOperation("获取台账详情")
    @GetMapping("/{id}")
    @RequiresLogin
    public Result<WasteLedger> getById(@PathVariable Long id) {
        WasteLedger ledger = wasteLedgerService.getById(id);
        return Result.success(ledger);
    }

    @ApiOperation("获取台账明细列表")
    @GetMapping("/{id}/details")
    @RequiresLogin
    public Result<List<WasteLedgerDetail>> getDetails(@PathVariable Long id) {
        List<WasteLedgerDetail> details = wasteLedgerService.getDetailsByLedgerId(id);
        return Result.success(details);
    }

    @ApiOperation("获取台账上报日志")
    @GetMapping("/{id}/report-logs")
    @RequiresLogin
    public Result<IPage<WasteLedgerReportLog>> getReportLogs(@PathVariable Long id, PageQuery pageQuery,
                                                              @ApiParam("企业ID") @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteLedgerReportLog> page = wasteLedgerService.getReportLogs(pageQuery, id, enterpriseId);
        return Result.success(page);
    }

    @ApiOperation("生成台账")
    @PostMapping("/generate")
    @RequiresLogin
    public Result<WasteLedger> generateLedger(@RequestBody WasteLedgerDTO dto,
                                               @ApiParam("企业ID") @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        WasteLedger ledger = wasteLedgerService.generateLedger(dto, enterpriseId);
        return Result.success(ledger);
    }

    @ApiOperation("重新生成台账")
    @PostMapping("/{id}/regenerate")
    @RequiresLogin
    public Result<WasteLedger> regenerateLedger(@PathVariable Long id) {
        WasteLedger ledger = wasteLedgerService.regenerateLedger(id);
        return Result.success(ledger);
    }

    @ApiOperation("预览台账（获取Excel文件URL）")
    @GetMapping("/{id}/preview")
    @RequiresLogin
    public Result<String> previewLedger(@PathVariable Long id) {
        String fileUrl = wasteLedgerService.previewLedger(id);
        return Result.success(fileUrl);
    }

    @ApiOperation("上报台账")
    @PostMapping("/{id}/report")
    @RequiresLogin
    public Result<Void> reportLedger(@PathVariable Long id,
                                     @ApiParam("上报类型: MANUAL-手动上报 RETRY-重试上报") @RequestParam(defaultValue = "MANUAL") String reportType) {
        wasteLedgerService.reportLedger(id, reportType);
        return Result.success();
    }

    @ApiOperation("批量上报台账")
    @PostMapping("/batch-report")
    @RequiresLogin
    public Result<Void> batchReport(@RequestBody List<Long> ids) {
        wasteLedgerService.batchReport(ids);
        return Result.success();
    }

    @ApiOperation("重试上报台账")
    @PostMapping("/{id}/retry-report")
    @RequiresLogin
    public Result<Void> retryReport(@PathVariable Long id) {
        wasteLedgerService.retryReport(id);
        return Result.success();
    }

    @ApiOperation("生成月度台账")
    @PostMapping("/generate-monthly")
    @RequiresLogin
    public Result<WasteLedger> generateMonthlyLedger(
            @ApiParam("年份") @RequestParam Integer year,
            @ApiParam("月份") @RequestParam Integer month,
            @ApiParam("企业ID") @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        WasteLedger ledger = wasteLedgerService.generateMonthlyLedger(year, month, enterpriseId);
        return Result.success(ledger);
    }

    @ApiOperation("生成年度台账")
    @PostMapping("/generate-yearly")
    @RequiresLogin
    public Result<WasteLedger> generateYearlyLedger(
            @ApiParam("年份") @RequestParam Integer year,
            @ApiParam("企业ID") @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        WasteLedger ledger = wasteLedgerService.generateYearlyLedger(year, enterpriseId);
        return Result.success(ledger);
    }

    @ApiOperation("删除台账")
    @DeleteMapping("/{id}")
    @RequiresLogin
    public Result<Void> delete(@PathVariable Long id) {
        wasteLedgerService.delete(id);
        return Result.success();
    }
}
