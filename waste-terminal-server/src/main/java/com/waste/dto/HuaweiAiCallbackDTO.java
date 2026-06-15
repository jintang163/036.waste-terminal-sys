package com.waste.dto;

import lombok.Data;

import java.util.List;

@Data
public class HuaweiAiCallbackDTO {

    private String taskId;

    private String taskName;

    private String streamName;

    private String cameraCode;

    private Long timestamp;

    private List<AiEventResult> results;

    private String snapshotUrl;

    private String videoUrl;

    private String algorithmVersion;

    private String signature;

    @Data
    public static class AiEventResult {

        private String eventType;

        private String eventCategory;

        private String eventName;

        private Integer confidence;

        private BoundingBox boundingBox;

        private String detail;

        private List<String> labels;
    }

    @Data
    public static class BoundingBox {
        private Integer x;
        private Integer y;
        private Integer width;
        private Integer height;
    }
}
