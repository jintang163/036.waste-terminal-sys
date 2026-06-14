package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.WasteInRecordDTO;
import com.waste.entity.WasteInRecord;
import com.waste.mapper.WasteInRecordMapper;
import com.waste.service.WasteInRecordService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/waste-in")
public class WasteInRecordController {

    @Autowired
    private WasteInRecordService wasteInRecordService;

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @PostMapping("/add")
    @RequiresLogin
    public Result<WasteInRecord> add(@RequestBody @Validated WasteInRecordDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && wasteInRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            return Result.fail("offline_id已存在: " + dto.getOfflineId());
        }
        wasteInRecordService.add(dto, enterpriseId);
        return Result.success();
    }

    @PostMapping("/batch-add")
    @RequiresLogin
    public Result<Map<String, Object>> batchAdd(@RequestBody @Validated List<WasteInRecordDTO> list) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        int successCount = 0;
        int failCount = 0;
        for (WasteInRecordDTO dto : list) {
            try {
                if (dto.getOfflineId() != null && wasteInRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
                    successCount++;
                    continue;
                }
                wasteInRecordService.add(dto, enterpriseId);
                successCount++;
            } catch (Exception e) {
                failCount++;
            }
        }
        Map<String, Object> result = new HashMap<>();
        result.put("successCount", successCount);
        result.put("failCount", failCount);
        result.put("totalCount", successCount + failCount);
        return Result.success(result);
    }

    @GetMapping("/list")
    @RequiresLogin
    public Result<List<WasteInRecord>> list(WasteInRecord wasteInRecord,
                                             @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
        if (wasteInRecord.getContainerCode() != null && !wasteInRecord.getContainerCode().isEmpty()) {
            wrapper.eq(WasteInRecord::getContainerCode, wasteInRecord.getContainerCode());
        }
        if (wasteInRecord.getWasteCode() != null && !wasteInRecord.getWasteCode().isEmpty()) {
            wrapper.eq(WasteInRecord::getWasteCode, wasteInRecord.getWasteCode());
        }
        if (wasteInRecord.getStatus() != null) {
            wrapper.eq(WasteInRecord::getStatus, wasteInRecord.getStatus());
        }
        if (wasteInRecord.getOfflineId() != null && !wasteInRecord.getOfflineId().isEmpty()) {
            wrapper.eq(WasteInRecord::getOfflineId, wasteInRecord.getOfflineId());
        }
        wrapper.orderByDesc(WasteInRecord::getCreateTime);
        List<WasteInRecord> list = wasteInRecordMapper.selectList(wrapper);
        return Result.success(list);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<WasteInRecord>> page(PageQuery pageQuery, WasteInRecord wasteInRecord,
                                                   @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteInRecord> page = wasteInRecordService.page(pageQuery, wasteInRecord, enterpriseId);
        PageResult<WasteInRecord> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<WasteInRecord> detail(@PathVariable Long id) {
        WasteInRecord record = wasteInRecordService.getById(id);
        return Result.success(record);
    }

    @GetMapping("/page-legacy")
    public Result<PageResult<WasteInRecord>> pageLegacy(PageQuery pageQuery, WasteInRecord wasteInRecord,
                                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteInRecord> page = wasteInRecordService.page(pageQuery, wasteInRecord, enterpriseId);
        PageResult<WasteInRecord> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<WasteInRecord> getById(@PathVariable Long id) {
        WasteInRecord record = wasteInRecordService.getById(id);
        return Result.success(record);
    }

    @PostMapping
    public Result<Void> addLegacy(@RequestBody WasteInRecordDTO dto,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteInRecordService.add(dto, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody WasteInRecordDTO dto) {
        wasteInRecordService.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        wasteInRecordService.delete(id);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchSync(@RequestBody List<WasteInRecordDTO> list,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteInRecordService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @PutMapping("/confirm/{id}")
    public Result<Void> confirm(@PathVariable Long id) {
        wasteInRecordService.confirm(id);
        return Result.success();
    }

    @PutMapping("/cancel/{id}")
    public Result<Void> cancel(@PathVariable Long id) {
        wasteInRecordService.cancel(id);
        return Result.success();
    }

    @GetMapping("/check/{offlineId}")
    public Result<Boolean> checkByOfflineId(@PathVariable String offlineId,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        boolean exist = wasteInRecordService.checkByOfflineId(offlineId, enterpriseId);
        return Result.success(exist);
    }

    @GetMapping("/pending")
    public Result<List<WasteInRecord>> getPendingSyncList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WasteInRecord> list = wasteInRecordService.getPendingSyncList(enterpriseId);
        return Result.success(list);
    }
}
