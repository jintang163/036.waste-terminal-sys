package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
public class PackagingRecommendationDTO {

    private String wasteCode;

    private String wasteName;

    private String wasteCategory;

    private String hazardCode;

    private RecommendedPackage primaryRecommendation;

    private List<RecommendedPackage> alternativeRecommendations;

    private List<String> precautions;

    private String storageRequirement;

    private BigDecimal maxWeightPerPackage;

    @Data
    public static class RecommendedPackage {
        private String containerType;
        private String containerTypeLabel;
        private String containerSpec;
        private String material;
        private BigDecimal capacity;
        private String sealRequirement;
        private String labelRequirement;
        private Integer priority;
    }

    @Data
    public static class BatchRequest {
        private List<WasteItem> items;

        @lombok.Data
        public static class WasteItem {
            private String wasteCode;
            private String wasteName;
            private BigDecimal weight;
            private String batchNo;
        }
    }
}
