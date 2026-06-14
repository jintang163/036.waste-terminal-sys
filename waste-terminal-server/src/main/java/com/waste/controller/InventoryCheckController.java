package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.InventoryCheckDTO;
import com.waste.entity.InventoryCheck;
import com.waste.entity.InventoryCheckDetail;
import com.waste.service.InventoryCheckService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/waste/check")
public class InventoryCheckController {

    @Autowired
    private InventoryCheckService inventoryCheckService;

    @GetMapping("/page")
    public Result<PageResult<InventoryCheck>> page(PageQuery pageQuery, InventoryCheck inventoryCheck,
                                                    @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<InventoryCheck> page = inventoryCheckService.page(pageQuery, inventoryCheck, enterpriseId);
        PageResult<InventoryCheck> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<InventoryCheck> getById(@PathVariable Long id) {
        InventoryCheck check = inventoryCheckService.getById(id);
        return Result.success(check);
    }

    @GetMapping("/{id}/details")
    public Result<List<InventoryCheckDetail>> getDetailsByCheckId(@PathVariable Long id) {
        List<InventoryCheckDetail> details = inventoryCheckService.getDetailsByCheckId(id);
        return Result.success(details);
    }

    @PostMapping
    public Result<Void> createCheck(@RequestBody InventoryCheckDTO dto,
                                    @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        inventoryCheckService.createCheck(dto, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody InventoryCheckDTO dto) {
        inventoryCheckService.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        inventoryCheckService.delete(id);
        return Result.success();
    }

    @PutMapping("/cancel/{id}")
    public Result<Void> cancel(@PathVariable Long id) {
        inventoryCheckService.cancel(id);
        return Result.success();
    }

    @PostMapping("/{id}/detail")
    public Result<Void> addDetail(@PathVariable Long id,
                                   @RequestBody InventoryCheckDTO.CheckDetailDTO detailDTO) {
        inventoryCheckService.addDetail(id, detailDTO);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchSync(@RequestBody List<InventoryCheckDTO> list,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        inventoryCheckService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @PutMapping("/complete/{id}")
    public Result<Void> completeCheck(@PathVariable Long id) {
        inventoryCheckService.completeCheck(id);
        return Result.success();
    }

    @PutMapping("/audit/{id}")
    public Result<Void> auditCheck(@PathVariable Long id,
                                    @RequestParam Integer auditStatus,
                                    @RequestParam(required = false) String auditRemark,
                                    @RequestParam(required = false) Long userId) {
        if (userId == null) {
            userId = 1L;
        }
        inventoryCheckService.auditCheck(id, auditStatus, auditRemark, userId);
        return Result.success();
    }

    @GetMapping("/check/{offlineId}")
    public Result<Boolean> checkByOfflineId(@PathVariable String offlineId,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        boolean exist = inventoryCheckService.checkByOfflineId(offlineId, enterpriseId);
        return Result.success(exist);
    }

    @GetMapping("/pending")
    public Result<List<InventoryCheck>> getPendingSyncList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<InventoryCheck> list = inventoryCheckService.getPendingSyncList(enterpriseId);
        return Result.success(list);
    }
}
