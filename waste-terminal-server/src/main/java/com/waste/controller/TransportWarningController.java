package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.TransportWarningDTO;
import com.waste.entity.TransportWarning;
import com.waste.service.TransportWarningService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/transport-warning")
public class TransportWarningController {

    @Autowired
    private TransportWarningService transportWarningService;

    @PostMapping("/create")
    @RequiresLogin
    public Result<Void> createWarning(@RequestBody @Validated TransportWarningDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        transportWarningService.createWarning(dto, enterpriseId);
        return Result.success();
    }

    @PostMapping("/handle/{id}")
    @RequiresLogin
    public Result<Void> handleWarning(@PathVariable Long id, @RequestBody TransportWarningDTO dto) {
        transportWarningService.handleWarning(id, dto);
        return Result.success();
    }

    @PostMapping("/check-timeout")
    @RequiresLogin
    public Result<List<TransportWarning>> checkTransportTimeout() {
        List<TransportWarning> warnings = transportWarningService.checkTransportTimeout();
        return Result.success(warnings);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<TransportWarning>> page(PageQuery pageQuery, TransportWarning transportWarning,
                                                      @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<TransportWarning> page = transportWarningService.page(pageQuery, transportWarning, enterpriseId);
        PageResult<TransportWarning> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<TransportWarning> detail(@PathVariable Long id) {
        TransportWarning warning = transportWarningService.getById(id);
        return Result.success(warning);
    }

    @GetMapping("/{id}")
    public Result<TransportWarning> getById(@PathVariable Long id) {
        TransportWarning warning = transportWarningService.getById(id);
        return Result.success(warning);
    }
}
