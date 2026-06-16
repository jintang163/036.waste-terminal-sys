package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.TransportDriverDTO;
import com.waste.entity.TransportDriver;
import com.waste.mapper.TransportDriverMapper;
import com.waste.service.TransportDriverService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/transport-driver")
public class TransportDriverController {

    @Autowired
    private TransportDriverService transportDriverService;

    @Autowired
    private TransportDriverMapper transportDriverMapper;

    @PostMapping("/add")
    @RequiresLogin
    public Result<Void> add(@RequestBody @Validated TransportDriverDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportDriverService.add(dto, enterpriseId);
        return Result.success();
    }

    @GetMapping("/list")
    @RequiresLogin
    public Result<List<TransportDriver>> list(TransportDriver transportDriver,
                                                @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LambdaQueryWrapper<TransportDriver> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportDriver::getEnterpriseId, enterpriseId);
        if (transportDriver.getDriverName() != null && !transportDriver.getDriverName().isEmpty()) {
            wrapper.like(TransportDriver::getDriverName, transportDriver.getDriverName());
        }
        if (transportDriver.getStatus() != null) {
            wrapper.eq(TransportDriver::getStatus, transportDriver.getStatus());
        }
        wrapper.orderByDesc(TransportDriver::getCreateTime);
        List<TransportDriver> list = transportDriverMapper.selectList(wrapper);
        return Result.success(list);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<TransportDriver>> page(PageQuery pageQuery, TransportDriver transportDriver,
                                                      @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<TransportDriver> page = transportDriverService.page(pageQuery, transportDriver, enterpriseId);
        PageResult<TransportDriver> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<TransportDriver> detail(@PathVariable Long id) {
        TransportDriver driver = transportDriverService.getById(id);
        return Result.success(driver);
    }

    @GetMapping("/{id}")
    public Result<TransportDriver> getById(@PathVariable Long id) {
        TransportDriver driver = transportDriverService.getById(id);
        return Result.success(driver);
    }

    @PostMapping
    public Result<Void> addLegacy(@RequestBody TransportDriverDTO dto,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportDriverService.add(dto, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody TransportDriverDTO dto) {
        transportDriverService.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        transportDriverService.delete(id);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchSync(@RequestBody List<TransportDriverDTO> list,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportDriverService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @GetMapping("/check/{offlineId}")
    public Result<Boolean> checkByOfflineId(@PathVariable String offlineId,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        boolean exist = transportDriverService.checkByOfflineId(offlineId, enterpriseId);
        return Result.success(exist);
    }

    @GetMapping("/select")
    @RequiresLogin
    public Result<List<TransportDriver>> select(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<TransportDriver> list = transportDriverService.listForCache(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/cache")
    public Result<List<TransportDriver>> listForCache(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<TransportDriver> list = transportDriverService.listForCache(enterpriseId);
        return Result.success(list);
    }
}
