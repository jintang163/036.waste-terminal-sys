package com.waste.dto;

import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class WasteAiRecognitionDTO {

    @Data
    public static class WasteAiRecognitionResult {
        private Long catalogId;
        private String wasteCode;
        private String wasteName;
        private String wasteCategory;
        private String wasteType;
        private String hazardCode;
        private String disposalMethod;
        private String storageRequirement;
        private String safetyMeasures;
        private Double confidence;
        private String description;
    }

    @Data
    public static class WasteAiRecognitionResponse {
        private boolean success;
        private String message;
        private String imageUrl;
        private List<WasteAiRecognitionResult> results;
        private LocalDateTime recognitionTime;
        private String provider;
        private Long processingTime;
    }
}
