package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.dto.CompatibilityCheckDTO;
import com.waste.dto.PackagingRecommendationDTO;
import com.waste.entity.WasteCatalog;
import com.waste.entity.WasteIncompatibility;
import com.waste.entity.WastePackagingRule;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.mapper.WasteIncompatibilityMapper;
import com.waste.mapper.WastePackagingRuleMapper;
import com.waste.service.WasteSmartService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Slf4j
@Service
public class WasteSmartServiceImpl implements WasteSmartService {

    public static final int INCOMPATIBILITY_LEVEL_CRITICAL = 3;
    public static final int INCOMPATIBILITY_LEVEL_WARNING = 2;
    public static final int INCOMPATIBILITY_LEVEL_CAUTION = 1;

    public static final String CONTAINER_TYPE_BARREL = "barrel";
    public static final String CONTAINER_TYPE_BAG = "bag";
    public static final String CONTAINER_TYPE_BOX = "box";
    public static final String CONTAINER_TYPE_TANK = "tank";
    public static final String CONTAINER_TYPE_DRUM = "drum";

    public static final String PHYSICAL_STATE_LIQUID = "liquid";
    public static final String PHYSICAL_STATE_SOLID = "solid";
    public static final String PHYSICAL_STATE_SLUDGE = "sludge";
    public static final String PHYSICAL_STATE_PASTE = "paste";

    private static final Pattern HW_PATTERN = Pattern.compile("HW(\\d{1,2})", Pattern.CASE_INSENSITIVE);
    private static final Pattern NATIONAL_CODE_PATTERN = Pattern.compile("\\d{3}-\\d{3}-(\\d{2})");

    @Autowired
    private WastePackagingRuleMapper packagingRuleMapper;

    @Autowired
    private WasteIncompatibilityMapper incompatibilityMapper;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Override
    public PackagingRecommendationDTO recommendPackaging(String wasteCode, Long enterpriseId) {
        PackagingRecommendationDTO result = new PackagingRecommendationDTO();
        result.setWasteCode(wasteCode);

        WasteCatalog catalog = findCatalog(wasteCode, enterpriseId);
        String hwCategory = resolveHwCategory(wasteCode, catalog);

        if (catalog != null) {
            result.setWasteName(catalog.getWasteName());
            result.setWasteCategory(catalog.getWasteCategory());
            result.setHazardCode(catalog.getHazardCode());
            result.setStorageRequirement(catalog.getStorageRequirement());
        }

        List<WastePackagingRule> matchedRules = findMatchedRulesLayered(hwCategory, catalog);
        if (CollUtil.isEmpty(matchedRules)) {
            log.warn("未找到包装规则, 使用默认推荐, wasteCode={}, hwCategory={}", wasteCode, hwCategory);
            matchedRules = getDefaultRules(catalog);
        }

        if (CollUtil.isNotEmpty(matchedRules)) {
            WastePackagingRule primary = matchedRules.get(0);
            result.setPrimaryRecommendation(buildRecommendedPackage(primary));
            result.setMaxWeightPerPackage(primary.getMaxWeightPerPackage());

            List<PackagingRecommendationDTO.RecommendedPackage> alternatives = new ArrayList<>();
            for (int i = 1; i < matchedRules.size(); i++) {
                alternatives.add(buildRecommendedPackage(matchedRules.get(i)));
            }
            result.setAlternativeRecommendations(alternatives);
        }

        List<String> precautions = new ArrayList<>();
        if (catalog != null && StrUtil.isNotBlank(catalog.getSafetyMeasures())) {
            precautions.add(catalog.getSafetyMeasures());
        }
        for (WastePackagingRule rule : matchedRules) {
            if (StrUtil.isNotBlank(rule.getPrecaution()) && !precautions.contains(rule.getPrecaution())) {
                precautions.add(rule.getPrecaution());
            }
        }
        result.setPrecautions(precautions);

        return result;
    }

    @Override
    public List<PackagingRecommendationDTO> recommendPackagingBatch(List<String> wasteCodes, Long enterpriseId) {
        List<PackagingRecommendationDTO> result = new ArrayList<>();
        if (CollUtil.isEmpty(wasteCodes)) {
            return result;
        }
        for (String code : wasteCodes) {
            result.add(recommendPackaging(code, enterpriseId));
        }
        return result;
    }

    @Override
    public CompatibilityCheckDTO checkCompatibility(CompatibilityCheckDTO.CheckRequest request, Long enterpriseId) {
        CompatibilityCheckDTO result = new CompatibilityCheckDTO();
        result.setCompatible(true);
        result.setRiskLevel(0);
        result.setIncompatibilities(new ArrayList<>());
        result.setSuggestions(new ArrayList<>());

        if (request == null || CollUtil.isEmpty(request.getItems())) {
            result.setSummary("未提供检查条目");
            return result;
        }

        List<CompatibilityCheckDTO.WasteItem> allItems = enrichItems(request.getItems(), enterpriseId);

        String batchNo = request.getBatchNo();
        List<CompatibilityCheckDTO.WasteItem> items;
        if (StrUtil.isNotBlank(batchNo)) {
            items = allItems.stream()
                    .filter(it -> batchNo.equals(it.getBatchNo()))
                    .collect(Collectors.toList());
            if (items.size() < allItems.size()) {
                log.info("按批次号[{}]筛选: {}/{} 条", batchNo, items.size(), allItems.size());
            }
        } else {
            Map<String, List<CompatibilityCheckDTO.WasteItem>> byBatch = allItems.stream()
                    .filter(it -> StrUtil.isNotBlank(it.getBatchNo()))
                    .collect(Collectors.groupingBy(CompatibilityCheckDTO.WasteItem::getBatchNo));
            List<CompatibilityCheckDTO.WasteItem> noBatch = allItems.stream()
                    .filter(it -> StrUtil.isBlank(it.getBatchNo()))
                    .collect(Collectors.toList());

            if (byBatch.size() == 1 && noBatch.isEmpty()) {
                items = allItems;
            } else if (!byBatch.isEmpty()) {
                return checkCompatibilityByBatch(byBatch, noBatch, enterpriseId, request.getIncludeCompatibleGroups());
            } else {
                items = allItems;
            }
        }

        if (items.size() < 2) {
            result.setSummary("同批次危废数量不足2种，无需相容性检查");
            result.setSuggestions(Collections.singletonList("单种危废可直接按包装推荐存放"));
            if (Boolean.TRUE.equals(request.getIncludeCompatibleGroups())) {
                result.setCompatibleGroups(buildSingleGroups(items));
            }
            return result;
        }

        return doCheck(items, request.getIncludeCompatibleGroups());
    }

    private CompatibilityCheckDTO checkCompatibilityByBatch(
            Map<String, List<CompatibilityCheckDTO.WasteItem>> byBatch,
            List<CompatibilityCheckDTO.WasteItem> noBatch,
            Long enterpriseId,
            Boolean includeGroups) {

        CompatibilityCheckDTO merged = new CompatibilityCheckDTO();
        merged.setCompatible(true);
        merged.setRiskLevel(0);
        merged.setIncompatibilities(new ArrayList<>());
        merged.setSuggestions(new ArrayList<>());
        merged.setCompatibleGroups(new ArrayList<>());

        List<String> batchSummaries = new ArrayList<>();
        int totalIncompatibilities = 0;
        int maxRisk = 0;

        for (Map.Entry<String, List<CompatibilityCheckDTO.WasteItem>> entry : byBatch.entrySet()) {
            String batch = entry.getKey();
            List<CompatibilityCheckDTO.WasteItem> batchItems = entry.getValue();
            if (batchItems.size() < 2) {
                batchSummaries.add(String.format("批次[%s]: 仅%d种危废，无需检查", batch, batchItems.size()));
                continue;
            }
            CompatibilityCheckDTO batchResult = doCheck(batchItems, includeGroups);
            if (!batchResult.getCompatible()) {
                merged.setCompatible(false);
                totalIncompatibilities += batchResult.getIncompatibilities().size();
                if (batchResult.getRiskLevel() > maxRisk) {
                    maxRisk = batchResult.getRiskLevel();
                }
                merged.getIncompatibilities().addAll(batchResult.getIncompatibilities());
                merged.getSuggestions().addAll(batchResult.getSuggestions());
            }
            batchSummaries.add(String.format("批次[%s]: %s", batch, batchResult.getSummary()));
            if (batchResult.getCompatibleGroups() != null) {
                for (CompatibilityCheckDTO.CompatibilityGroup g : batchResult.getCompatibleGroups()) {
                    g.setGroupId(batch + "-" + g.getGroupId());
                    g.setGroupDescription("[批次" + batch + "] " + g.getGroupDescription());
                }
                merged.getCompatibleGroups().addAll(batchResult.getCompatibleGroups());
            }
        }

        if (!noBatch.isEmpty() && noBatch.size() >= 2) {
            CompatibilityCheckDTO noBatchResult = doCheck(noBatch, includeGroups);
            if (!noBatchResult.getCompatible()) {
                merged.setCompatible(false);
                totalIncompatibilities += noBatchResult.getIncompatibilities().size();
                if (noBatchResult.getRiskLevel() > maxRisk) {
                    maxRisk = noBatchResult.getRiskLevel();
                }
                merged.getIncompatibilities().addAll(noBatchResult.getIncompatibilities());
                merged.getSuggestions().addAll(noBatchResult.getSuggestions());
            }
            batchSummaries.add("[未指定批次]: " + noBatchResult.getSummary());
            if (noBatchResult.getCompatibleGroups() != null) {
                merged.getCompatibleGroups().addAll(noBatchResult.getCompatibleGroups());
            }
        }

        merged.setRiskLevel(maxRisk);
        merged.setSummary(String.join("; ", batchSummaries));
        return merged;
    }

    private CompatibilityCheckDTO doCheck(List<CompatibilityCheckDTO.WasteItem> items, Boolean includeGroups) {
        CompatibilityCheckDTO result = new CompatibilityCheckDTO();
        result.setCompatible(true);
        result.setRiskLevel(0);
        result.setIncompatibilities(new ArrayList<>());
        result.setSuggestions(new ArrayList<>());

        List<CompatibilityCheckDTO.IncompatibilityDetail> incompatibilities = new ArrayList<>();
        Set<String> checkedPairs = new HashSet<>();
        int maxRiskLevel = 0;

        for (int i = 0; i < items.size(); i++) {
            for (int j = i + 1; j < items.size(); j++) {
                CompatibilityCheckDTO.WasteItem a = items.get(i);
                CompatibilityCheckDTO.WasteItem b = items.get(j);

                String pairKey = buildPairKey(a.getWasteCode(), b.getWasteCode());
                if (checkedPairs.contains(pairKey)) {
                    continue;
                }
                checkedPairs.add(pairKey);

                List<WasteIncompatibility> rules = findIncompatibilityRules(a.getHwCategory(), a.getWasteCode(),
                        b.getHwCategory(), b.getWasteCode());
                if (CollUtil.isNotEmpty(rules)) {
                    for (WasteIncompatibility rule : rules) {
                        CompatibilityCheckDTO.IncompatibilityDetail detail = buildIncompatibilityDetail(a, b, rule);
                        incompatibilities.add(detail);
                        if (rule.getIncompatibilityLevel() != null && rule.getIncompatibilityLevel() > maxRiskLevel) {
                            maxRiskLevel = rule.getIncompatibilityLevel();
                        }
                    }
                }
            }
        }

        result.setIncompatibilities(incompatibilities);

        if (CollUtil.isNotEmpty(incompatibilities)) {
            result.setCompatible(false);
            result.setRiskLevel(maxRiskLevel);
            result.setSummary(
                    String.format("检测到 %d 组禁忌物组合，最高风险等级: %s",
                            incompatibilities.size(), getLevelLabel(maxRiskLevel)));

            Set<String> suggestions = new LinkedHashSet<>();
            for (CompatibilityCheckDTO.IncompatibilityDetail d : incompatibilities) {
                if (StrUtil.isNotBlank(d.getSeparationRequirement())) {
                    suggestions.add(d.getSeparationRequirement());
                }
                if (StrUtil.isNotBlank(d.getEmergencyMeasure())) {
                    suggestions.add("应急措施: " + d.getEmergencyMeasure());
                }
            }
            suggestions.add(0, "禁止将上述禁忌物混装、混合存放或同批次运输");
            suggestions.add("必须使用独立包装并物理隔离存放，保持安全距离");
            result.setSuggestions(new ArrayList<>(suggestions));
        } else {
            result.setSummary("所有危废相容性检查通过，可同批次存放");
            result.getSuggestions().add("相容性检查通过，建议仍按包装要求分类存放");
        }

        if (Boolean.TRUE.equals(includeGroups)) {
            result.setCompatibleGroups(buildCompatibleGroups(items, incompatibilities));
        }

        log.info("相容性检查完成: compatible={}, riskLevel={}, incompatibilities={}, items={}",
                result.getCompatible(), maxRiskLevel, incompatibilities.size(), items.size());
        return result;
    }

    @Override
    public List<WasteIncompatibility> findIncompatibilities(String wasteCode, Long enterpriseId) {
        String hwCategory = resolveHwCategory(wasteCode, findCatalog(wasteCode, enterpriseId));
        log.info("查询禁忌物: wasteCode={}, hwCategory={}", wasteCode, hwCategory);

        LambdaQueryWrapper<WasteIncompatibility> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteIncompatibility::getStatus, 1);
        wrapper.and(w -> {
            w.eq(WasteIncompatibility::getWasteCodeA, wasteCode)
                    .or().eq(WasteIncompatibility::getWasteCodeB, wasteCode);
            if (StrUtil.isNotBlank(hwCategory)) {
                w.or().like(WasteIncompatibility::getWasteCategoryA, hwCategory)
                        .or().like(WasteIncompatibility::getWasteCategoryB, hwCategory);
            }
        });
        return incompatibilityMapper.selectList(wrapper);
    }

    @Override
    public List<WastePackagingRule> listPackagingRules(String wasteCategory, Long enterpriseId) {
        LambdaQueryWrapper<WastePackagingRule> wrapper = new LambdaQueryWrapper<>();
        if (StrUtil.isNotBlank(wasteCategory)) {
            wrapper.and(w -> w.eq(WastePackagingRule::getWasteCategory, wasteCategory)
                    .or().like(WastePackagingRule::getWasteCategory, wasteCategory)
                    .or().eq(WastePackagingRule::getWasteCategory, "ALL"));
        }
        wrapper.eq(WastePackagingRule::getStatus, 1);
        wrapper.orderByAsc(WastePackagingRule::getPriority);
        return packagingRuleMapper.selectList(wrapper);
    }

    String resolveHwCategory(String wasteCode, WasteCatalog catalog) {
        if (StrUtil.isNotBlank(wasteCode)) {
            java.util.regex.Matcher m = HW_PATTERN.matcher(wasteCode);
            if (m.find()) {
                return "HW" + Integer.parseInt(m.group(1));
            }
            m = NATIONAL_CODE_PATTERN.matcher(wasteCode);
            if (m.find()) {
                return "HW" + Integer.parseInt(m.group(1));
            }
        }
        if (catalog != null && StrUtil.isNotBlank(catalog.getWasteCode())) {
            java.util.regex.Matcher m = HW_PATTERN.matcher(catalog.getWasteCode());
            if (m.find()) {
                return "HW" + Integer.parseInt(m.group(1));
            }
        }
        return null;
    }

    private List<WastePackagingRule> findMatchedRulesLayered(String hwCategory, WasteCatalog catalog) {
        List<WastePackagingRule> allRules = packagingRuleMapper.selectList(
                new LambdaQueryWrapper<WastePackagingRule>()
                        .eq(WastePackagingRule::getStatus, 1));

        if (CollUtil.isEmpty(allRules)) {
            return Collections.emptyList();
        }

        if (StrUtil.isNotBlank(hwCategory)) {
            List<WastePackagingRule> tier1 = allRules.stream()
                    .filter(r -> StrUtil.isNotBlank(r.getWasteCategory())
                            && !r.getWasteCategory().equals("ALL")
                            && parseCategories(r.getWasteCategory()).size() == 1
                            && r.getWasteCategory().equals(hwCategory))
                    .sorted(Comparator.comparingInt(r -> r.getPriority() != null ? r.getPriority() : 99))
                    .collect(Collectors.toList());
            if (CollUtil.isNotEmpty(tier1)) {
                log.debug("包装推荐命中Tier1(精确单类别): hwCategory={}, rules={}", hwCategory, tier1.size());
                return tier1;
            }

            List<WastePackagingRule> tier2 = allRules.stream()
                    .filter(r -> StrUtil.isNotBlank(r.getWasteCategory())
                            && !r.getWasteCategory().equals("ALL")
                            && parseCategories(r.getWasteCategory()).size() > 1
                            && parseCategories(r.getWasteCategory()).contains(hwCategory))
                    .sorted(Comparator.comparingInt(r -> r.getPriority() != null ? r.getPriority() : 99))
                    .collect(Collectors.toList());
            if (CollUtil.isNotEmpty(tier2)) {
                log.debug("包装推荐命中Tier2(逗号多类别): hwCategory={}, rules={}", hwCategory, tier2.size());
                return tier2;
            }
        }

        if (catalog != null && StrUtil.isNotBlank(catalog.getHazardCode())) {
            String catalogHazard = catalog.getHazardCode();
            List<WastePackagingRule> tier3 = allRules.stream()
                    .filter(r -> {
                        if (StrUtil.isBlank(r.getHazardCode())) return false;
                        Set<String> ruleHazards = parseHazards(r.getHazardCode());
                        Set<String> catalogHazards = parseHazards(catalogHazard);
                        return ruleHazards.stream().anyMatch(catalogHazards::contains)
                                && (StrUtil.isBlank(r.getWasteCategory()) || r.getWasteCategory().equals("ALL"));
                    })
                    .sorted(Comparator.comparingInt(r -> r.getPriority() != null ? r.getPriority() : 99))
                    .collect(Collectors.toList());
            if (CollUtil.isNotEmpty(tier3)) {
                log.debug("包装推荐命中Tier3(危险特性): hazardCode={}, rules={}", catalogHazard, tier3.size());
                return tier3;
            }
        }

        List<WastePackagingRule> tier4 = allRules.stream()
                .filter(r -> "ALL".equals(r.getWasteCategory()) && StrUtil.isBlank(r.getHazardCode()))
                .sorted(Comparator.comparingInt(r -> r.getPriority() != null ? r.getPriority() : 99))
                .collect(Collectors.toList());
        if (CollUtil.isNotEmpty(tier4)) {
            log.debug("包装推荐命中Tier4(通用ALL): rules={}", tier4.size());
            return tier4;
        }

        return Collections.emptyList();
    }

    private Set<String> parseCategories(String categoryStr) {
        if (StrUtil.isBlank(categoryStr)) {
            return Collections.emptySet();
        }
        return Arrays.stream(categoryStr.split("[,，/|]"))
                .map(String::trim)
                .filter(StrUtil::isNotBlank)
                .collect(Collectors.toSet());
    }

    private Set<String> parseHazards(String hazardStr) {
        if (StrUtil.isBlank(hazardStr)) {
            return Collections.emptySet();
        }
        return Arrays.stream(hazardStr.split("[,/|]"))
                .map(String::trim)
                .filter(StrUtil::isNotBlank)
                .map(String::toUpperCase)
                .collect(Collectors.toSet());
    }

    private WasteCatalog findCatalog(String wasteCode, Long enterpriseId) {
        if (StrUtil.isBlank(wasteCode)) {
            return null;
        }
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteCatalog::getWasteCode, wasteCode);
        wrapper.eq(WasteCatalog::getStatus, 1);
        wrapper.last("LIMIT 1");
        return wasteCatalogMapper.selectOne(wrapper);
    }

    private List<WastePackagingRule> getDefaultRules(WasteCatalog catalog) {
        List<WastePackagingRule> defaults = new ArrayList<>();
        String physicalState = catalog != null ? inferPhysicalState(catalog.getWasteCategory(), catalog.getDescription()) : PHYSICAL_STATE_SOLID;

        WastePackagingRule primary = new WastePackagingRule();
        if (PHYSICAL_STATE_LIQUID.equals(physicalState)) {
            primary.setRecommendedContainerType(CONTAINER_TYPE_DRUM);
            primary.setRecommendedContainerSpec("200L吨桶");
            primary.setRecommendedMaterial("HDPE高密度聚乙烯");
            primary.setRecommendedCapacity(new BigDecimal("200"));
            primary.setMaxWeightPerPackage(new BigDecimal("250"));
            primary.setSealRequirement("双层密封盖，防渗漏");
            primary.setLabelRequirement("粘贴危险废物标签(腐蚀性/毒性标识)");
            primary.setPrecaution("液体危废使用吨桶，确保无渗漏，避免与固体混装");
            primary.setPriority(1);
        } else if (PHYSICAL_STATE_SLUDGE.equals(physicalState)) {
            primary.setRecommendedContainerType(CONTAINER_TYPE_DRUM);
            primary.setRecommendedContainerSpec("200L钢塑复合桶");
            primary.setRecommendedMaterial("钢塑复合");
            primary.setRecommendedCapacity(new BigDecimal("200"));
            primary.setMaxWeightPerPackage(new BigDecimal("300"));
            primary.setSealRequirement("压盖密封，内层加PE内衬袋");
            primary.setLabelRequirement("粘贴危险废物标签");
            primary.setPrecaution("污泥类使用内衬钢塑桶，防止泄漏和异味扩散");
            primary.setPriority(1);
        } else if (PHYSICAL_STATE_PASTE.equals(physicalState)) {
            primary.setRecommendedContainerType(CONTAINER_TYPE_BARREL);
            primary.setRecommendedContainerSpec("50kg塑料桶");
            primary.setRecommendedMaterial("HDPE");
            primary.setRecommendedCapacity(new BigDecimal("50"));
            primary.setMaxWeightPerPackage(new BigDecimal("60"));
            primary.setSealRequirement("螺纹盖+内衬袋双层密封");
            primary.setLabelRequirement("粘贴危险废物标签");
            primary.setPrecaution("膏状物使用小规格塑料桶，便于搬运和处理");
            primary.setPriority(1);
        } else {
            primary.setRecommendedContainerType(CONTAINER_TYPE_BAG);
            primary.setRecommendedContainerSpec("1吨编织袋");
            primary.setRecommendedMaterial("PP聚丙烯加厚编织袋");
            primary.setRecommendedCapacity(new BigDecimal("1000"));
            primary.setMaxWeightPerPackage(new BigDecimal("1000"));
            primary.setSealRequirement("内膜+编织袋双层，机械缝口");
            primary.setLabelRequirement("外部粘贴危险废物标签，标签朝外侧");
            primary.setPrecaution("固体危废使用1吨编织袋，避免尖锐物刺破");
            primary.setPriority(1);
        }
        defaults.add(primary);

        WastePackagingRule alternative = new WastePackagingRule();
        alternative.setRecommendedContainerType(CONTAINER_TYPE_BOX);
        alternative.setRecommendedContainerSpec("标准危废周转箱");
        alternative.setRecommendedMaterial("工程塑料");
        alternative.setRecommendedCapacity(new BigDecimal("500"));
        alternative.setMaxWeightPerPackage(new BigDecimal("500"));
        alternative.setSealRequirement("箱盖密封扣");
        alternative.setLabelRequirement("箱盖表面粘贴标签");
        alternative.setPrecaution("周转箱用于厂内临时中转，便于搬运和管理");
        alternative.setPriority(2);
        defaults.add(alternative);

        return defaults;
    }

    private String inferPhysicalState(String wasteCategory, String description) {
        if (StrUtil.isBlank(wasteCategory) && StrUtil.isBlank(description)) {
            return PHYSICAL_STATE_SOLID;
        }
        String combined = (wasteCategory == null ? "" : wasteCategory) + " " + (description == null ? "" : description);
        String lower = combined.toLowerCase();
        if (lower.contains("液") || lower.contains("废酸") || lower.contains("废碱") || lower.contains("溶剂") || lower.contains("油")) {
            return PHYSICAL_STATE_LIQUID;
        }
        if (lower.contains("污泥") || lower.contains("底泥") || lower.contains("淤泥")) {
            return PHYSICAL_STATE_SLUDGE;
        }
        if (lower.contains("膏") || lower.contains("漆渣") || lower.contains("油墨")) {
            return PHYSICAL_STATE_PASTE;
        }
        return PHYSICAL_STATE_SOLID;
    }

    private PackagingRecommendationDTO.RecommendedPackage buildRecommendedPackage(WastePackagingRule rule) {
        PackagingRecommendationDTO.RecommendedPackage pkg = new PackagingRecommendationDTO.RecommendedPackage();
        pkg.setContainerType(rule.getRecommendedContainerType());
        pkg.setContainerTypeLabel(getContainerTypeLabel(rule.getRecommendedContainerType()));
        pkg.setContainerSpec(rule.getRecommendedContainerSpec());
        pkg.setMaterial(rule.getRecommendedMaterial());
        pkg.setCapacity(rule.getRecommendedCapacity());
        pkg.setSealRequirement(rule.getSealRequirement());
        pkg.setLabelRequirement(rule.getLabelRequirement());
        pkg.setPriority(rule.getPriority());
        return pkg;
    }

    private String getContainerTypeLabel(String type) {
        if (StrUtil.isBlank(type)) return "其他";
        switch (type) {
            case CONTAINER_TYPE_BARREL: return "塑料桶";
            case CONTAINER_TYPE_DRUM: return "吨桶/钢桶";
            case CONTAINER_TYPE_BAG: return "编织袋";
            case CONTAINER_TYPE_BOX: return "周转箱";
            case CONTAINER_TYPE_TANK: return "储罐";
            default: return type;
        }
    }

    private List<CompatibilityCheckDTO.WasteItem> enrichItems(List<CompatibilityCheckDTO.WasteItem> items, Long enterpriseId) {
        List<CompatibilityCheckDTO.WasteItem> result = new ArrayList<>();
        for (CompatibilityCheckDTO.WasteItem item : items) {
            CompatibilityCheckDTO.WasteItem enriched = new CompatibilityCheckDTO.WasteItem();
            enriched.setWasteCode(item.getWasteCode());
            enriched.setWasteName(item.getWasteName());
            enriched.setWasteCategory(item.getWasteCategory());
            enriched.setWeight(item.getWeight());
            enriched.setBatchNo(item.getBatchNo());

            WasteCatalog catalog = findCatalog(item.getWasteCode(), enterpriseId);
            if (catalog != null) {
                if (StrUtil.isBlank(enriched.getWasteName())) {
                    enriched.setWasteName(catalog.getWasteName());
                }
                if (StrUtil.isBlank(enriched.getWasteCategory())) {
                    enriched.setWasteCategory(catalog.getWasteCategory());
                }
            }

            String hw = resolveHwCategory(item.getWasteCode(), catalog);
            enriched.setHwCategory(hw);

            result.add(enriched);
        }
        return result;
    }

    private List<WasteIncompatibility> findIncompatibilityRules(String hwCategoryA, String wasteCodeA,
                                                                  String hwCategoryB, String wasteCodeB) {
        LambdaQueryWrapper<WasteIncompatibility> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteIncompatibility::getStatus, 1);
        wrapper.and(w -> {
            if (StrUtil.isNotBlank(wasteCodeA) && StrUtil.isNotBlank(wasteCodeB)) {
                w.and(w1 -> w1.eq(WasteIncompatibility::getWasteCodeA, wasteCodeA)
                        .eq(WasteIncompatibility::getWasteCodeB, wasteCodeB));
                w.or(w2 -> w2.eq(WasteIncompatibility::getWasteCodeA, wasteCodeB)
                        .eq(WasteIncompatibility::getWasteCodeB, wasteCodeA));
            }
            if (StrUtil.isNotBlank(hwCategoryA) && StrUtil.isNotBlank(hwCategoryB)) {
                w.or(w3 -> w3.like(WasteIncompatibility::getWasteCategoryA, hwCategoryA)
                        .like(WasteIncompatibility::getWasteCategoryB, hwCategoryB));
                w.or(w4 -> w4.like(WasteIncompatibility::getWasteCategoryA, hwCategoryB)
                        .like(WasteIncompatibility::getWasteCategoryB, hwCategoryA));
            }
        });

        List<WasteIncompatibility> candidates = incompatibilityMapper.selectList(wrapper);
        if (CollUtil.isEmpty(candidates)) {
            return Collections.emptyList();
        }

        return candidates.stream().filter(rule -> {
            boolean codeMatch = matchCodeOrCategory(rule.getWasteCodeA(), rule.getWasteCategoryA(), wasteCodeA, hwCategoryA)
                    && matchCodeOrCategory(rule.getWasteCodeB(), rule.getWasteCategoryB(), wasteCodeB, hwCategoryB);
            boolean reverseCodeMatch = matchCodeOrCategory(rule.getWasteCodeA(), rule.getWasteCategoryA(), wasteCodeB, hwCategoryB)
                    && matchCodeOrCategory(rule.getWasteCodeB(), rule.getWasteCategoryB(), wasteCodeA, hwCategoryA);
            return codeMatch || reverseCodeMatch;
        }).collect(Collectors.toList());
    }

    private boolean matchCodeOrCategory(String ruleCode, String ruleCategory, String itemCode, String itemHwCategory) {
        if (StrUtil.isNotBlank(ruleCode) && ruleCode.equals(itemCode)) {
            return true;
        }
        if (StrUtil.isNotBlank(ruleCategory) && StrUtil.isNotBlank(itemHwCategory)) {
            Set<String> cats = parseCategories(ruleCategory);
            return cats.contains(itemHwCategory);
        }
        return false;
    }

    private CompatibilityCheckDTO.IncompatibilityDetail buildIncompatibilityDetail(
            CompatibilityCheckDTO.WasteItem a,
            CompatibilityCheckDTO.WasteItem b,
            WasteIncompatibility rule) {
        CompatibilityCheckDTO.IncompatibilityDetail detail = new CompatibilityCheckDTO.IncompatibilityDetail();
        detail.setWasteCodeA(a.getWasteCode());
        detail.setWasteNameA(a.getWasteName());
        detail.setWasteCodeB(b.getWasteCode());
        detail.setWasteNameB(b.getWasteName());
        detail.setIncompatibilityLevel(rule.getIncompatibilityLevel());
        detail.setIncompatibilityLevelLabel(getLevelLabel(rule.getIncompatibilityLevel()));
        detail.setReactionType(rule.getReactionType());
        detail.setHazardDescription(rule.getHazardDescription());
        detail.setEmergencyMeasure(rule.getEmergencyMeasure());
        detail.setSeparationRequirement(rule.getSeparationRequirement());
        return detail;
    }

    private String buildPairKey(String a, String b) {
        if (a == null) a = "";
        if (b == null) b = "";
        return a.compareTo(b) <= 0 ? a + "|" + b : b + "|" + a;
    }

    private String getLevelLabel(Integer level) {
        if (level == null) return "未知";
        switch (level) {
            case INCOMPATIBILITY_LEVEL_CRITICAL: return "严重禁忌";
            case INCOMPATIBILITY_LEVEL_WARNING: return "警告";
            case INCOMPATIBILITY_LEVEL_CAUTION: return "注意";
            default: return "等级" + level;
        }
    }

    private List<CompatibilityCheckDTO.CompatibilityGroup> buildCompatibleGroups(
            List<CompatibilityCheckDTO.WasteItem> items,
            List<CompatibilityCheckDTO.IncompatibilityDetail> incompatibilities) {
        List<CompatibilityCheckDTO.CompatibilityGroup> groups = new ArrayList<>();
        if (CollUtil.isEmpty(items)) {
            return groups;
        }
        Map<String, Set<String>> incompatibleMap = new HashMap<>();
        for (CompatibilityCheckDTO.IncompatibilityDetail d : incompatibilities) {
            incompatibleMap.computeIfAbsent(d.getWasteCodeA(), k -> new HashSet<>()).add(d.getWasteCodeB());
            incompatibleMap.computeIfAbsent(d.getWasteCodeB(), k -> new HashSet<>()).add(d.getWasteCodeA());
        }
        List<Set<String>> groupSets = new ArrayList<>();
        for (CompatibilityCheckDTO.WasteItem item : items) {
            boolean added = false;
            for (Set<String> existingGroup : groupSets) {
                boolean conflict = false;
                Set<String> incompatibleSet = incompatibleMap.getOrDefault(item.getWasteCode(), Collections.emptySet());
                for (String existingCode : existingGroup) {
                    if (incompatibleSet.contains(existingCode)) {
                        conflict = true;
                        break;
                    }
                }
                if (!conflict) {
                    existingGroup.add(item.getWasteCode());
                    added = true;
                    break;
                }
            }
            if (!added) {
                Set<String> newGroup = new HashSet<>();
                newGroup.add(item.getWasteCode());
                groupSets.add(newGroup);
            }
        }
        int groupIdx = 1;
        for (Set<String> codes : groupSets) {
            CompatibilityCheckDTO.CompatibilityGroup group = new CompatibilityCheckDTO.CompatibilityGroup();
            group.setGroupId("G" + groupIdx++);
            List<CompatibilityCheckDTO.WasteItem> groupItems = new ArrayList<>();
            for (CompatibilityCheckDTO.WasteItem item : items) {
                if (codes.contains(item.getWasteCode())) {
                    groupItems.add(item);
                }
            }
            group.setItems(groupItems);
            group.setGroupDescription(
                    String.format("相容组 %d（%d 种危废，可同批次存放）", groupIdx - 1, groupItems.size()));
            groups.add(group);
        }
        return groups;
    }

    private List<CompatibilityCheckDTO.CompatibilityGroup> buildSingleGroups(List<CompatibilityCheckDTO.WasteItem> items) {
        List<CompatibilityCheckDTO.CompatibilityGroup> groups = new ArrayList<>();
        int idx = 1;
        for (CompatibilityCheckDTO.WasteItem item : items) {
            CompatibilityCheckDTO.CompatibilityGroup g = new CompatibilityCheckDTO.CompatibilityGroup();
            g.setGroupId("G" + idx++);
            g.setItems(Collections.singletonList(item));
            g.setGroupDescription("单种危废组");
            groups.add(g);
        }
        return groups;
    }
}
