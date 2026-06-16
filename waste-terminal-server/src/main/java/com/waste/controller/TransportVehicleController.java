package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.TransportVehicleDTO;
import com.waste.entity.TransportVehicle;
import com.waste.mapper.TransportVehicleMapper;
import com.waste.service.TransportVehicleService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/transport-vehicle")
public class TransportVehicleController {

    @Autowired
    private TransportVehicleService transportVehicleService;

    @Autowired
    private TransportVehicleMapper transportVehicleMapper;

    @PostMapping("/add")
    @RequiresLogin
    public Result<Void> add(@RequestBody @Validated TransportVehicleDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportVehicleService.add(dto, enterpriseId);
        return Result.success();
    }

    @GetMapping("/list")
    @RequiresLogin
    public Result<List<TransportVehicle>> list(TransportVehicle transportVehicle,
                                                @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LambdaQueryWrapper<TransportVehicle> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportVehicle::getEnterpriseId, enterpriseId);
        if (transportVehicle.getVehicleNo() != null && !transportVehicle.getVehicleNo().isEmpty()) {
            wrapper.like(TransportVehicle::getVehicleNo, transportVehicle.getVehicleNo());
        }
        if (transportVehicle.getStatus() != null) {
            wrapper.eq(TransportVehicle::getStatus, transportVehicle.getStatus());
        }
        wrapper.orderByDesc(TransportVehicle::getCreateTime);
        List<TransportVehicle> list = transportVehicleMapper.selectList(wrapper);
        return Result.success(list);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<TransportVehicle>> page(PageQuery pageQuery, TransportVehicle transportVehicle,
                                                      @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<TransportVehicle> page = transportVehicleService.page(pageQuery, transportVehicle, enterpriseId);
        PageResult<TransportVehicle> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<TransportVehicle> detail(@PathVariable Long id) {
        TransportVehicle vehicle = transportVehicleService.getById(id);
        return Result.success(vehicle);
    }

    @GetMapping("/{id}")
    public Result<TransportVehicle> getById(@PathVariable Long id) {
        TransportVehicle vehicle = transportVehicleService.getById(id);
        return Result.success(vehicle);
    }

    @PostMapping
    public Result<Void> addLegacy(@RequestBody TransportVehicleDTO dto,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportVehicleService.add(dto, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody TransportVehicleDTO dto) {
        transportVehicleService.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        transportVehicleService.delete(id);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchSync(@RequestBody List<TransportVehicleDTO> list,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportVehicleService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @GetMapping("/check/{offlineId}")
    public Result<Boolean> checkByOfflineId(@PathVariable String offlineId,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        boolean exist = transportVehicleService.checkByOfflineId(offlineId, enterpriseId);
        return Result.success(exist);
    }

    @GetMapping("/select")
    @RequiresLogin
    public Result<List<TransportVehicle>> select(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<TransportVehicle> list = transportVehicleService.listForCache(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/cache")
    public Result<List<TransportVehicle>> listForCache(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<TransportVehicle> list = transportVehicleService.listForCache(enterpriseId);
        return Result.success(list);
    }
}
