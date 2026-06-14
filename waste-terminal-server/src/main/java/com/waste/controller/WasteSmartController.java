package com.waste.controller;

import com.waste.annotation.RequiresLogin;
import com.waste.common.Result;
import com.waste.dto.CompatibilityCheckDTO;
import com.waste.dto.PackagingRecommendationDTO;
import com.waste.entity.WasteIncompatibility;
import com.waste.entity.WastePackagingRule;
import com.waste.service.WasteSmartService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/waste-smart")
public class WasteSmartController {

    @Autowired
    private WasteSmartService wasteSmartService;

    @GetMapping("/packaging/recommend")
    @RequiresLogin
    public Result<PackagingRecommendationDTO> recommendPackaging(@RequestParam String wasteCode) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(wasteSmartService.recommendPackaging(wasteCode, enterpriseId));
    }

    @PostMapping("/packaging/recommend-batch")
    @RequiresLogin
    public Result<List<PackagingRecommendationDTO>> recommendPackagingBatch(@RequestBody List<String> wasteCodes) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(wasteSmartService.recommendPackagingBatch(wasteCodes, enterpriseId));
    }

    @PostMapping("/compatibility/check")
    @RequiresLogin
    public Result<CompatibilityCheckDTO> checkCompatibility(@RequestBody CompatibilityCheckDTO.CheckRequest request) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(wasteSmartService.checkCompatibility(request, enterpriseId));
    }

    @GetMapping("/compatibility/incompatibilities")
    @RequiresLogin
    public Result<List<WasteIncompatibility>> getIncompatibilities(@RequestParam String wasteCode) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(wasteSmartService.findIncompatibilities(wasteCode, enterpriseId));
    }

    @GetMapping("/packaging/rules")
    @RequiresLogin
    public Result<List<WastePackagingRule>> listPackagingRules(
            @RequestParam(required = false) String wasteCategory) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(wasteSmartService.listPackagingRules(wasteCategory, enterpriseId));
    }
}
