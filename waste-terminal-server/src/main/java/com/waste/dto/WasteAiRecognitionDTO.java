package com.waste.dto;

import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class WasteAiRecognitionDTO {

    @Data
    public static class WasteAiRecognitionResult {
        private String wasteCode;
        private String wasteName;
        private String wasteCategory;
        private String wasteType;
        private Double confidence;
        private String description;
        private Long catalogId;
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
