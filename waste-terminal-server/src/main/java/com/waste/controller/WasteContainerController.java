package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.WasteContainer;
import com.waste.service.WasteContainerService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/waste/container")
public class WasteContainerController {

    @Autowired
    private WasteContainerService wasteContainerService;

    @GetMapping("/page")
    public Result<PageResult<WasteContainer>> page(PageQuery pageQuery, WasteContainer wasteContainer,
                                                   @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteContainer> page = wasteContainerService.page(pageQuery, wasteContainer, enterpriseId);
        PageResult<WasteContainer> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<WasteContainer> getById(@PathVariable Long id) {
        WasteContainer container = wasteContainerService.getById(id);
        return Result.success(container);
    }

    @GetMapping("/code/{code}")
    public Result<WasteContainer> getByCode(@PathVariable String code,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        WasteContainer container = wasteContainerService.getByCode(code, enterpriseId);
        return Result.success(container);
    }

    @GetMapping("/available")
    public Result<List<WasteContainer>> getAvailableList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WasteContainer> list = wasteContainerService.getAvailableList(enterpriseId);
        return Result.success(list);
    }

    @PostMapping
    public Result<Void> add(@RequestBody WasteContainer wasteContainer,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteContainerService.add(wasteContainer, enterpriseId);
        return Result.success();
    }

    @PutMapping
    public Result<Void> update(@RequestBody WasteContainer wasteContainer) {
        wasteContainerService.update(wasteContainer);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        wasteContainerService.delete(id);
        return Result.success();
    }
}
