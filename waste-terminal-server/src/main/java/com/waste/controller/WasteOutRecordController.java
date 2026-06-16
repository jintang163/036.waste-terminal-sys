package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.WasteOutRecordDTO;
import com.waste.entity.WasteOutRecord;
import com.waste.mapper.WasteOutRecordMapper;
import com.waste.service.WasteOutRecordService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/waste-out")
public class WasteOutRecordController {

    @Autowired
    private WasteOutRecordService wasteOutRecordService;

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @PostMapping("/add")
    @RequiresLogin
    public Result<Void> add(@RequestBody @Validated WasteOutRecordDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && wasteOutRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            return Result.fail("offline_id已存在: " + dto.getOfflineId());
        }
        wasteOutRecordService.add(dto, enterpriseId);
        return Result.success();
    }

    @GetMapping("/list")
    @RequiresLogin
    public Result<List<WasteOutRecord>> list(WasteOutRecord wasteOutRecord,
                                              @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
        if (wasteOutRecord.getContainerCode() != null && !wasteOutRecord.getContainerCode().isEmpty()) {
            wrapper.eq(WasteOutRecord::getContainerCode, wasteOutRecord.getContainerCode());
        }
        if (wasteOutRecord.getWasteCode() != null && !wasteOutRecord.getWasteCode().isEmpty()) {
            wrapper.eq(WasteOutRecord::getWasteCode, wasteOutRecord.getWasteCode());
        }
        if (wasteOutRecord.getStatus() != null) {
            wrapper.eq(WasteOutRecord::getStatus, wasteOutRecord.getStatus());
        }
        if (wasteOutRecord.getOfflineId() != null && !wasteOutRecord.getOfflineId().isEmpty()) {
            wrapper.eq(WasteOutRecord::getOfflineId, wasteOutRecord.getOfflineId());
        }
        wrapper.orderByDesc(WasteOutRecord::getCreateTime);
        List<WasteOutRecord> list = wasteOutRecordMapper.selectList(wrapper);
        return Result.success(list);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<WasteOutRecord>> page(PageQuery pageQuery, WasteOutRecord wasteOutRecord,
                                                    @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteOutRecord> page = wasteOutRecordService.page(pageQuery, wasteOutRecord, enterpriseId);
        PageResult<WasteOutRecord> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<WasteOutRecord> detail(@PathVariable Long id) {
        WasteOutRecord record = wasteOutRecordService.getById(id);
        return Result.success(record);
    }

    @GetMapping("/page-legacy")
    public Result<PageResult<WasteOutRecord>> pageLegacy(PageQuery pageQuery, WasteOutRecord wasteOutRecord,
                                                   @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteOutRecord> page = wasteOutRecordService.page(pageQuery, wasteOutRecord, enterpriseId);
        PageResult<WasteOutRecord> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<WasteOutRecord> getById(@PathVariable Long id) {
        WasteOutRecord record = wasteOutRecordService.getById(id);
        return Result.success(record);
    }

    @PostMapping
    public Result<Void> addLegacy(@RequestBody WasteOutRecordDTO dto,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteOutRecordService.add(dto, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody WasteOutRecordDTO dto) {
        wasteOutRecordService.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        wasteOutRecordService.delete(id);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchSync(@RequestBody List<WasteOutRecordDTO> list,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteOutRecordService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @PutMapping("/confirm/{id}")
    public Result<Void> confirm(@PathVariable Long id) {
        wasteOutRecordService.confirm(id);
        return Result.success();
    }

    @PutMapping("/sign/{id}")
    public Result<Void> sign(@PathVariable Long id,
                             @RequestParam(required = false) String signPhoto,
                             @RequestParam(required = false) String receiptPhoto) {
        wasteOutRecordService.sign(id, signPhoto, receiptPhoto);
        return Result.success();
    }

    @PutMapping("/cancel/{id}")
    public Result<Void> cancel(@PathVariable Long id) {
        wasteOutRecordService.cancel(id);
        return Result.success();
    }

    @GetMapping("/check/{offlineId}")
    public Result<Boolean> checkByOfflineId(@PathVariable String offlineId,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        boolean exist = wasteOutRecordService.checkByOfflineId(offlineId, enterpriseId);
        return Result.success(exist);
    }

    @GetMapping("/pending")
    public Result<List<WasteOutRecord>> getPendingSyncList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WasteOutRecord> list = wasteOutRecordService.getPendingSyncList(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/check-double-review")
    @RequiresLogin
    public Result<Map<String, Object>> checkDoubleReviewRequired(@RequestParam Long wasteId) {
        Map<String, Object> result = wasteOutRecordService.checkDoubleReviewRequired(wasteId);
        return Result.success(result);
    }
}
