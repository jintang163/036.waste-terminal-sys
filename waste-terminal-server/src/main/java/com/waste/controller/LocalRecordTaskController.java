package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.LocalRecordTask;
import com.waste.service.LocalRecordTaskService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/local-record")
public class LocalRecordTaskController {

    @Autowired
    private LocalRecordTaskService localRecordTaskService;

    @GetMapping("/page")
    public Result<PageResult<LocalRecordTask>> page(PageQuery pageQuery, LocalRecordTask task,
                                                      @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<LocalRecordTask> page = localRecordTaskService.page(pageQuery, task, enterpriseId);
        PageResult<LocalRecordTask> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<LocalRecordTask> getById(@PathVariable Long id) {
        LocalRecordTask task = localRecordTaskService.getById(id);
        return Result.success(task);
    }

    @PostMapping
    public Result<Void> add(@RequestBody LocalRecordTask task,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        localRecordTaskService.add(task, enterpriseId);
        return Result.success();
    }

    @GetMapping("/unsynced")
    public Result<List<LocalRecordTask>> getUnsyncedList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<LocalRecordTask> list = localRecordTaskService.getUnsyncedList(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/list")
    public Result<List<LocalRecordTask>> list(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<LocalRecordTask> list = localRecordTaskService.listByEnterpriseId(enterpriseId);
        return Result.success(list);
    }

    @PutMapping("/sync-status/{id}")
    public Result<Void> updateSyncStatus(@PathVariable Long id, @RequestParam Integer syncStatus) {
        localRecordTaskService.updateSyncStatus(id, syncStatus);
        return Result.success();
    }

    @PutMapping("/batch-sync-status")
    public Result<Void> batchUpdateSyncStatus(@RequestBody List<Long> ids, @RequestParam Integer syncStatus) {
        localRecordTaskService.batchUpdateSyncStatus(ids, syncStatus);
        return Result.success();
    }

    @PostMapping("/trigger")
    public Result<Void> triggerRecord(@RequestParam String cameraCode,
                                       @RequestParam String triggerType,
                                       @RequestParam(required = false) String triggerId,
                                       @RequestParam(defaultValue = "10") Integer preSeconds,
                                       @RequestParam(defaultValue = "10") Integer postSeconds,
                                       @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        localRecordTaskService.createEventRecord(cameraCode, triggerType, triggerId,
                preSeconds, postSeconds, enterpriseId);
        return Result.success();
    }
}
