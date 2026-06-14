package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.WasteInventory;
import com.waste.service.WasteInventoryService;
import com.waste.vo.WasteInventoryVO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/waste/inventory")
public class WasteInventoryController {

    @Autowired
    private WasteInventoryService wasteInventoryService;

    @GetMapping("/page")
    public Result<PageResult<WasteInventoryVO>> page(PageQuery pageQuery, WasteInventory wasteInventory,
                                                     @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteInventoryVO> page = wasteInventoryService.page(pageQuery, wasteInventory, enterpriseId);
        PageResult<WasteInventoryVO> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<WasteInventory> getById(@PathVariable Long id) {
        WasteInventory inventory = wasteInventoryService.getById(id);
        return Result.success(inventory);
    }

    @PostMapping
    public Result<Void> add(@RequestBody WasteInventory wasteInventory,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteInventoryService.add(wasteInventory, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody WasteInventory wasteInventory) {
        wasteInventoryService.update(id, wasteInventory);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        wasteInventoryService.delete(id);
        return Result.success();
    }

    @GetMapping("/container/{containerCode}")
    public Result<WasteInventory> getByContainerCode(@PathVariable String containerCode,
                                                     @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        WasteInventory inventory = wasteInventoryService.getByContainerCode(containerCode, enterpriseId);
        return Result.success(inventory);
    }

    @GetMapping("/statistics")
    public Result<Map<String, Object>> getStatistics(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Map<String, Object> statistics = wasteInventoryService.getStatistics(enterpriseId);
        return Result.success(statistics);
    }

    @GetMapping("/list")
    public Result<List<WasteInventory>> listForCache(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WasteInventory> list = wasteInventoryService.listForCache(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/capacity")
    public Result<BigDecimal> getCapacityRate(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        BigDecimal capacityRate = wasteInventoryService.getCapacityRate(enterpriseId);
        return Result.success(capacityRate);
    }

    @GetMapping("/home/dashboard")
    public Result<Map<String, Object>> getHomeDashboard(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Map<String, Object> dashboard = wasteInventoryService.getHomeDashboard(enterpriseId);
        return Result.success(dashboard);
    }
}
