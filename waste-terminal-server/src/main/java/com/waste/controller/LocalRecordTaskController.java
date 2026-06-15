package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.LocalRecordTask;
import com.waste.service.LocalRecordTaskService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

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

    @GetMapping("/task/{taskId}")
    public Result<LocalRecordTask> getByTaskId(@PathVariable String taskId,
                                               @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LocalRecordTask task = localRecordTaskService.getByTaskId(taskId, enterpriseId);
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
    public Result<Map<String, Object>> triggerRecord(@RequestBody Map<String, Object> params,
                                                       @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        String cameraCode = (String) params.get("cameraCode");
        String triggerType = (String) params.get("triggerType");
        String triggerId = (String) params.get("triggerId");
        Integer preSeconds = params.get("preSeconds") != null ?
                Integer.parseInt(params.get("preSeconds").toString()) : 10;
        Integer postSeconds = params.get("postSeconds") != null ?
                Integer.parseInt(params.get("postSeconds").toString()) : 10;

        String taskId = UUID.randomUUID().toString().replace("-", "");

        LocalRecordTask task = new LocalRecordTask();
        task.setTaskId(taskId);
        task.setCameraCode(cameraCode);
        task.setTriggerType(triggerType);
        task.setTriggerId(triggerId);
        task.setPreSeconds(String.valueOf(preSeconds));
        task.setPostSeconds(String.valueOf(postSeconds));
        task.setStatus(0);
        task.setSyncStatus(0);

        localRecordTaskService.add(task, enterpriseId);

        Map<String, Object> data = new HashMap<>();
        data.put("taskId", taskId);
        data.put("preSeconds", preSeconds);
        data.put("postSeconds", postSeconds);
        return Result.success(data);
    }

    @PostMapping("/confirm-upload")
    public Result<Void> confirmUpload(@RequestBody Map<String, Object> params,
                                       @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        String taskId = (String) params.get("taskId");
        String filePath = (String) params.get("filePath");
        Long fileSize = params.get("fileSize") != null ?
                Long.parseLong(params.get("fileSize").toString()) : 0L;
        Integer durationSeconds = params.get("durationSeconds") != null ?
                Integer.parseInt(params.get("durationSeconds").toString()) : 0;
        String startTime = (String) params.get("startTime");
        String endTime = (String) params.get("endTime");

        localRecordTaskService.confirmUpload(taskId, filePath, fileSize, durationSeconds,
                startTime, endTime, enterpriseId);
        return Result.success();
    }
}
