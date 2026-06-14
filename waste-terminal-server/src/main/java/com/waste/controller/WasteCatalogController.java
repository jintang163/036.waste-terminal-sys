package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.WasteCatalog;
import com.waste.service.WasteCatalogService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/waste/catalog")
public class WasteCatalogController {

    @Autowired
    private WasteCatalogService wasteCatalogService;

    @GetMapping("/page")
    public Result<PageResult<WasteCatalog>> page(PageQuery pageQuery, WasteCatalog wasteCatalog,
                                                 @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteCatalog> page = wasteCatalogService.page(pageQuery, wasteCatalog, enterpriseId);
        PageResult<WasteCatalog> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<WasteCatalog> getById(@PathVariable Long id) {
        WasteCatalog wasteCatalog = wasteCatalogService.getById(id);
        return Result.success(wasteCatalog);
    }

    @GetMapping("/list")
    public Result<List<WasteCatalog>> list(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WasteCatalog> list = wasteCatalogService.listAll(enterpriseId);
        return Result.success(list);
    }

    @PostMapping
    public Result<Void> add(@RequestBody WasteCatalog wasteCatalog,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteCatalogService.add(wasteCatalog, enterpriseId);
        return Result.success();
    }

    @PutMapping
    public Result<Void> update(@RequestBody WasteCatalog wasteCatalog) {
        wasteCatalogService.update(wasteCatalog);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        wasteCatalogService.delete(id);
        return Result.success();
    }
}
