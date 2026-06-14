package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
public class CompatibilityCheckDTO {

    private Boolean compatible;

    private Integer riskLevel;

    private String summary;

    private List<IncompatibilityDetail> incompatibilities;

    private List<CompatibilityGroup> compatibleGroups;

    private List<String> suggestions;

    @Data
    public static class IncompatibilityDetail {
        private String wasteCodeA;
        private String wasteNameA;
        private String wasteCodeB;
        private String wasteNameB;
        private Integer incompatibilityLevel;
        private String incompatibilityLevelLabel;
        private String reactionType;
        private String hazardDescription;
        private String emergencyMeasure;
        private String separationRequirement;
    }

    @Data
    public static class CompatibilityGroup {
        private String groupId;
        private List<WasteItem> items;
        private String groupDescription;
    }

    @Data
    public static class WasteItem {
        private String wasteCode;
        private String wasteName;
        private String wasteCategory;
        private BigDecimal weight;
        private String batchNo;
    }

    @Data
    public static class CheckRequest {
        private List<WasteItem> items;
        private String batchNo;
        private Boolean includeCompatibleGroups;
    }
}
