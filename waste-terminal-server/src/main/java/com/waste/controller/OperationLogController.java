package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.OperationLog;
import com.waste.service.OperationLogService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/log")
public class OperationLogController {

    @Autowired
    private OperationLogService operationLogService;

    @GetMapping("/page")
    public Result<PageResult<OperationLog>> page(PageQuery pageQuery, OperationLog queryLog,
                                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) enterpriseId = 1L;
        IPage<OperationLog> page = operationLogService.page(pageQuery, queryLog, enterpriseId);
        return Result.success(PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords()));
    }

    @GetMapping("/{id}")
    public Result<OperationLog> getById(@PathVariable Long id) {
        return Result.success(operationLogService.getById(id));
    }

    @PostMapping
    public Result<Void> add(@RequestBody OperationLog operationLog) {
        operationLogService.add(operationLog);
        return Result.success();
    }

    @PostMapping("/upload")
    public Result<Map<String, Object>> upload(@RequestBody Map<String, Object> logData) {
        log.debug("收到单条日志上传");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> list = List.of(logData);
        return Result.success(operationLogService.batchUpload(list));
    }

    @PostMapping("/batch-upload")
    public Result<Map<String, Object>> batchUpload(@RequestBody Object payload) {
        List<Map<String, Object>> logDataList = extractLogList(payload);
        log.info("收到批量日志上传: count={}", logDataList.size());
        return Result.success(operationLogService.batchUpload(logDataList));
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> extractLogList(Object payload) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (payload == null) {
            return result;
        }
        if (payload instanceof List) {
            for (Object item : (List<?>) payload) {
                if (item instanceof Map) {
                    result.add((Map<String, Object>) item);
                }
            }
        } else if (payload instanceof Map) {
            Map<String, Object> map = (Map<String, Object>) payload;
            Object logsObj = map.get("logs");
            if (logsObj instanceof List) {
                for (Object item : (List<?>) logsObj) {
                    if (item instanceof Map) {
                        result.add((Map<String, Object>) item);
                    }
                }
            } else if (map.containsKey("logId") || map.containsKey("id")) {
                result.add(map);
            }
        }
        return result;
    }
}
