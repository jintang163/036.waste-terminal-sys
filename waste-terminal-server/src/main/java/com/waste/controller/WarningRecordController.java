package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.WarningRecord;
import com.waste.service.WarningRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/warning")
public class WarningRecordController {

    @Autowired
    private WarningRecordService warningRecordService;

    @GetMapping("/page")
    public Result<PageResult<WarningRecord>> page(PageQuery pageQuery, WarningRecord warningRecord,
                                                 @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WarningRecord> page = warningRecordService.page(pageQuery, warningRecord, enterpriseId);
        PageResult<WarningRecord> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<WarningRecord> getById(@PathVariable Long id) {
        WarningRecord record = warningRecordService.getById(id);
        return Result.success(record);
    }

    @PostMapping
    public Result<Void> add(@RequestBody WarningRecord warningRecord,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        warningRecordService.add(warningRecord, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody WarningRecord warningRecord) {
        warningRecordService.update(id, warningRecord);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        warningRecordService.delete(id);
        return Result.success();
    }

    @GetMapping("/unhandled")
    public Result<List<WarningRecord>> getUnhandledList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WarningRecord> list = warningRecordService.getUnhandledList(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/statistics")
    public Result<Map<String, Object>> getStatistics(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Map<String, Object> statistics = warningRecordService.getStatistics(enterpriseId);
        return Result.success(statistics);
    }

    @PutMapping("/handle/{id}")
    public Result<Void> handleWarning(@PathVariable Long id,
                                        @RequestParam(required = false) String handleRemark,
                                        @RequestParam(required = false) Long userId) {
        if (userId == null) {
            userId = 1L;
        }
        warningRecordService.handleWarning(id, handleRemark, userId);
        return Result.success();
    }

    @PutMapping("/ignore/{id}")
    public Result<Void> ignoreWarning(@PathVariable Long id,
                                        @RequestParam(required = false) Long userId) {
        if (userId == null) {
            userId = 1L;
        }
        warningRecordService.ignoreWarning(id, userId);
        return Result.success();
    }

    @GetMapping("/list")
    public Result<List<WarningRecord>> getWarningList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WarningRecord> list = warningRecordService.batchSyncList(enterpriseId);
        return Result.success(list);
    }
}
