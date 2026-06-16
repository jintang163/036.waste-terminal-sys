package com.waste.controller;

import com.waste.common.Result;
import com.waste.config.WasteAiRecognitionConfig;
import com.waste.dto.WasteAiRecognitionDTO;
import com.waste.service.WasteAiRecognitionService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/waste-ai/recognition")
public class WasteAiRecognitionController {

    @Autowired
    private WasteAiRecognitionService wasteAiRecognitionService;

    @Autowired
    private WasteAiRecognitionConfig.WasteAiRecognitionProperties aiProperties;

    @PostMapping("/recognize")
    public Result<WasteAiRecognitionDTO.WasteAiRecognitionResponse> recognize(
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        try {
            WasteAiRecognitionDTO.WasteAiRecognitionResponse response = wasteAiRecognitionService.recognizeWaste(file, enterpriseId);
            return Result.success(response);
        } catch (Exception e) {
            log.error("AI识别失败", e);
            return Result.fail("AI识别失败: " + e.getMessage());
        }
    }

    @GetMapping("/config")
    public Result<Map<String, Object>> config() {
        Map<String, Object> configMap = new HashMap<>();
        configMap.put("enabled", aiProperties.isEnabled());
        configMap.put("provider", aiProperties.getProvider());
        configMap.put("mockEnabled", aiProperties.isMockEnabled());
        configMap.put("confidenceThreshold", aiProperties.getConfidenceThreshold());
        configMap.put("maxFileSize", aiProperties.getMaxFileSize());
        return Result.success(configMap);
    }
}
