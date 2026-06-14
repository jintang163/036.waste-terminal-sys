package com.waste.service;

import com.waste.dto.CompatibilityCheckDTO;
import com.waste.dto.PackagingRecommendationDTO;
import com.waste.entity.WasteIncompatibility;
import com.waste.entity.WastePackagingRule;

import java.util.List;

public interface WasteSmartService {

    PackagingRecommendationDTO recommendPackaging(String wasteCode, Long enterpriseId);

    List<PackagingRecommendationDTO> recommendPackagingBatch(List<String> wasteCodes, Long enterpriseId);

    CompatibilityCheckDTO checkCompatibility(CompatibilityCheckDTO.CheckRequest request, Long enterpriseId);

    List<WasteIncompatibility> findIncompatibilities(String wasteCode, Long enterpriseId);

    List<WastePackagingRule> listPackagingRules(String wasteCategory, Long enterpriseId);
}
