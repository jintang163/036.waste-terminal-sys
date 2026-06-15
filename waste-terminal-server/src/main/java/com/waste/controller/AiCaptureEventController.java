package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.AiCaptureEvent;
import com.waste.service.AiCaptureEventService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/ai-capture")
public class AiCaptureEventController {

    @Autowired
    private AiCaptureEventService aiCaptureEventService;

    @GetMapping("/page")
    public Result<PageResult<AiCaptureEvent>> page(PageQuery pageQuery, AiCaptureEvent event,
                                                     @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<AiCaptureEvent> page = aiCaptureEventService.page(pageQuery, event, enterpriseId);
        PageResult<AiCaptureEvent> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<AiCaptureEvent> getById(@PathVariable Long id) {
        AiCaptureEvent event = aiCaptureEventService.getById(id);
        return Result.success(event);
    }

    @PostMapping
    public Result<Void> add(@RequestBody AiCaptureEvent event,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        aiCaptureEventService.add(event, enterpriseId);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchAdd(@RequestBody List<AiCaptureEvent> events) {
        aiCaptureEventService.batchAddFromAi(events);
        return Result.success();
    }

    @PutMapping("/handle/{id}")
    public Result<Void> handleEvent(@PathVariable Long id,
                                     @RequestParam(required = false) String handleRemark,
                                     @RequestParam(required = false) Long userId) {
        if (userId == null) {
            userId = 1L;
        }
        aiCaptureEventService.handleEvent(id, handleRemark, userId);
        return Result.success();
    }

    @PutMapping("/ignore/{id}")
    public Result<Void> ignoreEvent(@PathVariable Long id,
                                     @RequestParam(required = false) Long userId) {
        if (userId == null) {
            userId = 1L;
        }
        aiCaptureEventService.ignoreEvent(id, userId);
        return Result.success();
    }

    @GetMapping("/unhandled")
    public Result<List<AiCaptureEvent>> getUnhandledList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<AiCaptureEvent> list = aiCaptureEventService.getUnhandledList(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/list")
    public Result<List<AiCaptureEvent>> list(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<AiCaptureEvent> list = aiCaptureEventService.listByEnterpriseId(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/statistics")
    public Result<Map<String, Object>> getStatistics(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Map<String, Object> statistics = aiCaptureEventService.getStatistics(enterpriseId);
        return Result.success(statistics);
    }
}
