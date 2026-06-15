package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.FaceAuthRecord;
import com.waste.service.FaceAuthRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/face-auth")
public class FaceAuthRecordController {

    @Autowired
    private FaceAuthRecordService faceAuthRecordService;

    @GetMapping("/page")
    public Result<PageResult<FaceAuthRecord>> page(PageQuery pageQuery, FaceAuthRecord record,
                                                    @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<FaceAuthRecord> page = faceAuthRecordService.page(pageQuery, record, enterpriseId);
        PageResult<FaceAuthRecord> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<FaceAuthRecord> getById(@PathVariable Long id) {
        FaceAuthRecord record = faceAuthRecordService.getById(id);
        return Result.success(record);
    }

    @GetMapping("/auth/{authId}")
    public Result<FaceAuthRecord> getByAuthId(@PathVariable String authId,
                                               @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        FaceAuthRecord record = faceAuthRecordService.getByAuthId(authId, enterpriseId);
        return Result.success(record);
    }

    @PostMapping
    public Result<Map<String, Object>> add(@RequestBody FaceAuthRecord record,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        faceAuthRecordService.add(record, enterpriseId);
        Map<String, Object> data = new HashMap<>();
        data.put("id", record.getId());
        data.put("authId", record.getAuthId());
        return Result.success(data);
    }

    @GetMapping("/business")
    public Result<List<FaceAuthRecord>> listByBusiness(@RequestParam String businessType,
                                                        @RequestParam(required = false) String businessId,
                                                        @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<FaceAuthRecord> list = faceAuthRecordService.listByBusiness(businessType, businessId, enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/user/{userId}")
    public Result<List<FaceAuthRecord>> listByUserId(@PathVariable Long userId,
                                                      @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<FaceAuthRecord> list = faceAuthRecordService.listByUserId(userId, enterpriseId);
        return Result.success(list);
    }

    @PostMapping("/batch")
    public Result<Void> batchAdd(@RequestBody List<FaceAuthRecord> records,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        for (FaceAuthRecord record : records) {
            faceAuthRecordService.add(record, enterpriseId);
        }
        return Result.success();
    }
}
