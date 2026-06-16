package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.http.HttpUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.common.exception.BusinessException;
import com.waste.config.WasteAiRecognitionConfig;
import com.waste.dto.WasteAiRecognitionDTO;
import com.waste.entity.WasteCatalog;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.service.WasteAiRecognitionService;
import com.waste.utils.FileUploadUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class WasteAiRecognitionServiceImpl implements WasteAiRecognitionService {

    @Autowired
    private WasteAiRecognitionConfig.WasteAiRecognitionProperties aiProperties;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Autowired
    private FileUploadUtils fileUploadUtils;

    @Override
    public WasteAiRecognitionDTO.WasteAiRecognitionResponse recognizeWaste(MultipartFile imageFile, Long enterpriseId) {
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
        if (aiProperties.isMockEnabled()) {
            results = _mockRecognize();
        } else {
            String provider = aiProperties.getProvider();
            switch (provider) {
                case "huawei":
                    results = _recognizeByHuawei(imageUrl);
                    break;
                case "baidu":
                    results = _recognizeByBaidu(imageUrl);
                    break;
                case "aliyun":
                    results = _recognizeByAliyun(imageUrl);
                    break;
                default:
                    throw new BusinessException("不支持的AI服务商: " + provider);
            }
        }

        results.removeIf(r -> r.getConfidence() < aiProperties.getConfidenceThreshold());

        long processingTime = System.currentTimeMillis() - startTime;

        WasteAiRecognitionDTO.WasteAiRecognitionResponse response = new WasteAiRecognitionDTO.WasteAiRecognitionResponse();
        response.setSuccess(true);
        response.setMessage("识别成功");
        response.setImageUrl(imageUrl);
        response.setResults(results);
        response.setRecognitionTime(LocalDateTime.now());
        response.setProvider(aiProperties.isMockEnabled() ? "mock" : aiProperties.getProvider());
        response.setProcessingTime(processingTime);

        return response;
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> _mockRecognize() {
        List<WasteAiRecognitionDTO.WasteAiRecognitionResult> results = new ArrayList<>();

        String[][] mockData = {
                {"HW08", "废矿物油", "HW08", "0.95"},
                {"HW49", "废油漆桶", "HW49", "0.82"},
                {"HW09", "废乳化液", "HW09", "0.65"}
        };

        for (String[] data : mockData) {
            WasteAiRecognitionDTO.WasteAiRecognitionResult result = new WasteAiRecognitionDTO.WasteAiRecognitionResult();
            result.setWasteCode(data[0]);
            result.setWasteName(data[1]);
            result.setWasteCategory(data[2]);
            result.setConfidence(Double.parseDouble(data[3]));

            LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteCatalog::getWasteCode, data[0]);
            WasteCatalog catalog = wasteCatalogMapper.selectOne(wrapper);
            if (catalog != null) {
                result.setCatalogId(catalog.getId());
                result.setWasteName(catalog.getWasteName());
                result.setWasteCategory(catalog.getWasteCategory());
            }

            results.add(result);
        }

        return results;
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> _recognizeByHuawei(String imageUrl) {
        throw new BusinessException("该AI服务商暂未接入");
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> _recognizeByBaidu(String imageUrl) {
        throw new BusinessException("该AI服务商暂未接入");
    }

    private List<WasteAiRecognitionDTO.WasteAiRecognitionResult> _recognizeByAliyun(String imageUrl) {
        throw new BusinessException("该AI服务商暂未接入");
    }
}
