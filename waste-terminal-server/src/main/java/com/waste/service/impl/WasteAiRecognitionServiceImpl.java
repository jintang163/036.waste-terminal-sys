package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.common.exception.BusinessException;
import com.waste.config.WasteAiRecognitionConfig;
import com.waste.dto.WasteAiRecognitionDTO;
import com.waste.entity.WasteCatalog;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.service.HuaweiImageTaggingService;
import com.waste.service.WasteAiRecognitionService;
import com.waste.utils.FileUploadUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
public class WasteAiRecognitionServiceImpl implements WasteAiRecognitionService {

    @Autowired
    private WasteAiRecognitionConfig.WasteAiRecognitionProperties aiProperties;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Autowired
    private FileUploadUtils fileUploadUtils;

    @Autowired
    private HuaweiImageTaggingService huaweiImageTaggingService;

    private static final Set<String> WASTE_KEYWORDS = new HashSet<>();

    static {
        WASTE_KEYWORDS.add("油桶");
        WASTE_KEYWORDS.add("废油");
        WASTE_KEYWORDS.add("润滑油");
        WASTE_KEYWORDS.add("机油");
        WASTE_KEYWORDS.add("柴油");
        WASTE_KEYWORDS.add("汽油");
        WASTE_KEYWORDS.add("油漆");
        WASTE_KEYWORDS.add("涂料");
        WASTE_KEYWORDS.add("溶剂");
        WASTE_KEYWORDS.add("酒精");
        WASTE_KEYWORDS.add("乙醇");
        WASTE_KEYWORDS.add("酸");
        WASTE_KEYWORDS.add("碱");
        WASTE_KEYWORDS.add("电池");
        WASTE_KEYWORDS.add("铅酸");
        WASTE_KEYWORDS.add("镉镍");
        WASTE_KEYWORDS.add("汞");
        WASTE_KEYWORDS.add("灯管");
        WASTE_KEYWORDS.add("荧光灯");
        WASTE_KEYWORDS.add("医疗");
        WASTE_KEYWORDS.add("针筒");
        WASTE_KEYWORDS.add("手套");
        WASTE_KEYWORDS.add("电镀");
        WASTE_KEYWORDS.add("铬");
        WASTE_KEYWORDS.add("氰化物");
        WASTE_KEYWORDS.add("石棉");
        WASTE_KEYWORDS.add("桶");
        WASTE_KEYWORDS.add("金属桶");
        WASTE_KEYWORDS.add("塑料桶");
        WASTE_KEYWORDS.add("容器");
        WASTE_KEYWORDS.add("化学品");
        WASTE_KEYWORDS.add("废液");
        WASTE_KEYWORDS.add("废渣");
        WASTE_KEYWORDS.add("污泥");
        WASTE_KEYWORDS.add("乳化液");
        WASTE_KEYWORDS.add("切削液");
        WASTE_KEYWORDS.add("磷化");
        WASTE_KEYWORDS.add("表面处理");
    }

    @Override
    public WasteAiRecognitionDTO.WasteAiRecognitionResponse recognizeWaste(
            MultipartFile imageFile, Long enterpriseId) {
        long startTime = System.currentTimeMillis();

        if (imageFile == null || imageFile.isEmpty()) {
            throw new BusinessException("图片文件不能为空");
        }
        if (imageFile.getSize() > aiProperties.getMaxFileSize()) {
            throw new BusinessException("图片文件大小超过限制");
        }
        if (!aiProperties.isEnabled()) {
            throw new BusinessException("AI识别功能未启用");
        }

        String objectKey = fileUploadUtils.uploadFile(imageFile, "waste_ai_recognition");
        String imageUrl = fileUploadUtils.getFileUrl(objectKey);

        List<WasteAiRecognitionDTO.WasteAiRecognitionResult> results;
        String provider;

        try {
            if (aiProperties.isMockEnabled()) {
                results = mockRecognize(imageFile.getOriginalFilename());
                provider = "mock";
            } else {
                String providerType = aiProperties.getProvider();
                provider = providerType;
                switch (providerType) {
                    case "huawei":
                        results = recognizeByHuawei(imageFile);
                        break;
                    case "baidu":
                        results = recognizeByBaidu(imageUrl);
                        break;
                    case "aliyun":
                        results = recognizeByAliyun(imageUrl);
                        break;
                    default:
                        throw new BusinessException("不支持的AI服务商: " + providerType);
                }
            }
        } catch (Exception e) {
            log.error("AI识别失败", e);
            WasteAiRecognitionDTO.WasteAiRecognitionResponse response =
                    new WasteAiRecognitionDTO.WasteAiRecognitionResponse();
            response.setSuccess(false);
            response.setMessage("识别失败: " + e.getMessage());
            response.setImageUrl(imageUrl);
            response.setResults(new ArrayList<>());
            response.setRecognitionTime(LocalDateTime.now());
            response.setProvider(aiProperties.isMockEnabled() ? "mock" : aiProperties.getProvider());
            response.setProcessingTime(System.currentTimeMillis() - startTime);
            return response;
        }

        List<WasteAiRecognitionDTO.WasteAiRecognitionResult> filteredResults =
                enrichWithCatalogData(results, enterpriseId);

        filteredResults = filteredResults.stream()
                .filter(r -> r.getConfidence() != null
                        && r.getConfidence() >= aiProperties.getConfidenceThreshold())
                .sorted(Comparator.comparing(
                        WasteAiRecognitionDTO.WasteAiRecognitionResult::getConfidence)
                        .reversed())
                .limit(10)
                .collect(Collectors.toList());

        long processingTime = System.currentTimeMillis() - startTime;

        WasteAiRecognitionDTO.WasteAiRecognitionResponse response =
                new WasteAiRecognitionDTO.WasteAiRecognitionResponse();
        response.setSuccess(true);
        response.setMessage(filteredResults.isEmpty() ? "未识别到匹配的危废类别" : "识别成功");
        response.setImageUrl(imageUrl);
        response.setResults(filteredResults);
        response.setRecognitionTime(LocalDateTime.now());
        response.setProvider(provider);
        response.setProcessingTime(processingTime);

        return response;
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> recognizeByHuawei(
            MultipartFile imageFile) {
        try {
            byte[] imageBytes = imageFile.getBytes();

            List<HuaweiImageTaggingService.ImageTag> tags =
                    huaweiImageTaggingService.tagImage(imageBytes, aiProperties);

            return mapTagsToWasteCatalog(tags);
        } catch (Exception e) {
            log.error("华为云图像识别失败", e);
            throw new BusinessException("华为云图像识别失败: " + e.getMessage());
        }
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> recognizeByBaidu(
            String imageUrl) {
        throw new BusinessException("百度AI图像识别暂未接入");
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> recognizeByAliyun(
            String imageUrl) {
        throw new BusinessException("阿里云图像识别暂未接入");
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> mapTagsToWasteCatalog(
            List<HuaweiImageTaggingService.ImageTag> tags) {
        if (tags == null || tags.isEmpty()) {
            return new ArrayList<>();
        }

        List<WasteCatalog> allCatalogs = loadAllWasteCatalogs();
        if (allCatalogs.isEmpty()) {
            return new ArrayList<>();
        }

        List<WasteMatchCandidate> candidates = new ArrayList<>();

        for (HuaweiImageTaggingService.ImageTag tag : tags) {
            String tagLower = tag.getTag().toLowerCase();
            double tagConfidence = tag.getConfidence() != null
                    ? tag.getConfidence() : 0.5;

            for (WasteCatalog catalog : allCatalogs) {
                double nameMatchScore = calculateMatchScore(tagLower, catalog);
                if (nameMatchScore > 0) {
                    double combinedConfidence = tagConfidence * nameMatchScore;
                    candidates.add(new WasteMatchCandidate(catalog, combinedConfidence,
                            "标签[" + tag.getTag() + "]匹配"));
                }
            }
        }

        Set<Long> seenCatalogIds = new HashSet<>();
        List<WasteAiRecognitionDTO.WasteAiRecognitionResult> results = new ArrayList<>();

        candidates.sort(Comparator.comparing(WasteMatchCandidate::getConfidence).reversed());

        for (WasteMatchCandidate candidate : candidates) {
            if (seenCatalogIds.contains(candidate.getCatalog().getId())) {
                continue;
            }
            seenCatalogIds.add(candidate.getCatalog().getId());

            WasteAiRecognitionDTO.WasteAiRecognitionResult result =
                    new WasteAiRecognitionDTO.WasteAiRecognitionResult();
            WasteCatalog catalog = candidate.getCatalog();

            result.setCatalogId(catalog.getId());
            result.setWasteCode(catalog.getWasteCode());
            result.setWasteName(catalog.getWasteName());
            result.setWasteCategory(catalog.getWasteCategory());
            result.setWasteType(catalog.getWasteType());
            result.setHazardCode(catalog.getHazardCode());
            result.setDisposalMethod(catalog.getDisposalMethod());
            result.setStorageRequirement(catalog.getStorageRequirement());
            result.setSafetyMeasures(catalog.getSafetyMeasures());
            result.setConfidence(Math.min(0.99, candidate.getConfidence()));
            result.setDescription(candidate.getMatchReason() + " → "
                    + (catalog.getDescription() != null ? catalog.getDescription() : ""));

            results.add(result);
        }

        return results;
    }

    private double calculateMatchScore(String tagLower, WasteCatalog catalog) {
        double maxScore = 0;

        if (catalog.getWasteName() != null) {
            String name = catalog.getWasteName().toLowerCase();
            if (name.contains(tagLower) || tagLower.contains(name)) {
                maxScore = Math.max(maxScore, 0.9);
            }
            int commonChars = countCommonChars(tagLower, name);
            double similarity = (double) commonChars / Math.max(tagLower.length(), name.length());
            if (similarity > 0.3) {
                maxScore = Math.max(maxScore, similarity * 0.8);
            }
        }

        if (catalog.getWasteCode() != null) {
            String code = catalog.getWasteCode().toLowerCase();
            if (code.equals(tagLower) || tagLower.equals(code.replace("hw", ""))) {
                maxScore = Math.max(maxScore, 0.95);
            }
        }

        if (catalog.getWasteCategory() != null) {
            String category = catalog.getWasteCategory().toLowerCase();
            if (category.contains(tagLower) || tagLower.contains(category)) {
                maxScore = Math.max(maxScore, 0.7);
            }
        }

        if (catalog.getWasteType() != null) {
            String type = catalog.getWasteType().toLowerCase();
            if (type.contains(tagLower) || tagLower.contains(type)) {
                maxScore = Math.max(maxScore, 0.6);
            }
        }

        if (catalog.getDescription() != null) {
            String desc = catalog.getDescription().toLowerCase();
            if (desc.contains(tagLower)) {
                maxScore = Math.max(maxScore, 0.5);
            }
        }

        return maxScore;
    }

    private int countCommonChars(String s1, String s2) {
        Set<Character> set1 = new HashSet<>();
        for (char c : s1.toCharArray()) {
            set1.add(c);
        }
        int count = 0;
        for (char c : s2.toCharArray()) {
            if (set1.contains(c)) {
                count++;
            }
        }
        return count;
    }

    private List<WasteCatalog> loadAllWasteCatalogs() {
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteCatalog::getStatus, 1);
        wrapper.orderByAsc(WasteCatalog::getSortOrder);
        return wasteCatalogMapper.selectList(wrapper);
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> enrichWithCatalogData(
            List<WasteAiRecognitionDTO.WasteAiRecognitionResult> results, Long enterpriseId) {
        if (results == null || results.isEmpty()) {
            return new ArrayList<>();
        }

        List<Long> catalogIds = results.stream()
                .filter(r -> r.getCatalogId() != null)
                .map(WasteAiRecognitionDTO.WasteAiRecognitionResult::getCatalogId)
                .collect(Collectors.toList());

        if (!catalogIds.isEmpty()) {
            LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
            wrapper.in(WasteCatalog::getId, catalogIds);
            List<WasteCatalog> catalogs = wasteCatalogMapper.selectList(wrapper);

            for (WasteAiRecognitionDTO.WasteAiRecognitionResult result : results) {
                for (WasteCatalog catalog : catalogs) {
                    if (catalog.getId().equals(result.getCatalogId())) {
                        result.setWasteCode(catalog.getWasteCode());
                        result.setWasteName(catalog.getWasteName());
                        result.setWasteCategory(catalog.getWasteCategory());
                        result.setWasteType(catalog.getWasteType());
                        result.setHazardCode(catalog.getHazardCode());
                        result.setDisposalMethod(catalog.getDisposalMethod());
                        result.setStorageRequirement(catalog.getStorageRequirement());
                        result.setSafetyMeasures(catalog.getSafetyMeasures());
                        if (result.getDescription() == null) {
                            result.setDescription(catalog.getDescription());
                        }
                        break;
                    }
                }
            }
        }

        return results;
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> mockRecognize(
            String fileName) {
        List<WasteCatalog> allCatalogs = loadAllWasteCatalogs();
        if (allCatalogs.isEmpty()) {
            List<WasteAiRecognitionDTO.WasteAiRecognitionResult> results = new ArrayList<>();
            WasteAiRecognitionDTO.WasteAiRecognitionResult r =
                    new WasteAiRecognitionDTO.WasteAiRecognitionResult();
            r.setWasteCode("HW08");
            r.setWasteName("废矿物油");
            r.setWasteCategory("废矿物油与含矿物油废物");
            r.setConfidence(0.85);
            r.setDescription("Mock模拟识别结果");
            results.add(r);
            return results;
        }

        Random random = new Random();
        int seed = fileName != null ? fileName.hashCode() : (int) System.currentTimeMillis();
        random.setSeed(seed);

        int resultCount = 2 + random.nextInt(4);

        List<WasteAiRecognitionDTO.WasteAiRecognitionResult> results = new ArrayList<>();
        Set<Integer> usedIndices = new HashSet<>();

        for (int i = 0; i < resultCount && usedIndices.size() < allCatalogs.size(); i++) {
            int idx = random.nextInt(allCatalogs.size());
            while (usedIndices.contains(idx)) {
                idx = random.nextInt(allCatalogs.size());
            }
            usedIndices.add(idx);

            WasteCatalog catalog = allCatalogs.get(idx);
            double baseConfidence = 0.5 + random.nextDouble() * 0.45;

            WasteAiRecognitionDTO.WasteAiRecognitionResult result =
                    new WasteAiRecognitionDTO.WasteAiRecognitionResult();
            result.setCatalogId(catalog.getId());
            result.setWasteCode(catalog.getWasteCode());
            result.setWasteName(catalog.getWasteName());
            result.setWasteCategory(catalog.getWasteCategory());
            result.setWasteType(catalog.getWasteType());
            result.setHazardCode(catalog.getHazardCode());
            result.setDisposalMethod(catalog.getDisposalMethod());
            result.setStorageRequirement(catalog.getStorageRequirement());
            result.setSafetyMeasures(catalog.getSafetyMeasures());
            result.setConfidence(baseConfidence);
            result.setDescription("模拟AI识别：图像特征匹配[" + catalog.getWasteName() + "]");

            results.add(result);
        }

        results.sort(Comparator.comparing(
                WasteAiRecognitionDTO.WasteAiRecognitionResult::getConfidence).reversed());

        return results;
    }

    private static class WasteMatchCandidate {
        private final WasteCatalog catalog;
        private final double confidence;
        private final String matchReason;

        public WasteMatchCandidate(WasteCatalog catalog, double confidence, String matchReason) {
            this.catalog = catalog;
            this.confidence = confidence;
            this.matchReason = matchReason;
        }

        public WasteCatalog getCatalog() {
            return catalog;
        }

        public double getConfidence() {
            return confidence;
        }

        public String getMatchReason() {
            return matchReason;
        }
    }
}
