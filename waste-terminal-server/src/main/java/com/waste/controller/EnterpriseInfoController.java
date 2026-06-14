package com.waste.controller;

import com.waste.common.Result;
import com.waste.entity.EnterpriseInfo;
import com.waste.service.EnterpriseInfoService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/enterprise")
public class EnterpriseInfoController {

    @Autowired
    private EnterpriseInfoService enterpriseInfoService;

    @GetMapping("/{id}")
    public Result<EnterpriseInfo> getById(@PathVariable Long id) {
        EnterpriseInfo enterprise = enterpriseInfoService.getById(id);
        return Result.success(enterprise);
    }

    @GetMapping("/list")
    public Result<List<EnterpriseInfo>> list(@RequestParam(required = false) String enterpriseType,
                                             @RequestParam(required = false) Long enterpriseId) {
        List<EnterpriseInfo> list = enterpriseInfoService.list(enterpriseType, enterpriseId);
        return Result.success(list);
    }

    @PutMapping
    public Result<Void> update(@RequestBody EnterpriseInfo enterpriseInfo) {
        enterpriseInfoService.update(enterpriseInfo);
        return Result.success();
    }
}
