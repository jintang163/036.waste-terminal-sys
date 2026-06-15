package com.waste.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Data
@Component
@ConfigurationProperties(prefix = "video")
public class VideoProperties {

    private RtspProperties rtsp = new RtspProperties();
    private HuaweiAiProperties huaweiAi = new HuaweiAiProperties();
    private LocalRecordProperties localRecord = new LocalRecordProperties();

    @Data
    public static class RtspProperties {
        private boolean proxyEnabled = true;
        private int proxyPort = 8554;
        private int idleTimeout = 30000;
        private int frameRate = 25;
        private int gopSize = 50;
        private String hlsStoragePath = "/data/waste-terminal/hls";
        private int hlsSegmentDuration = 2;
        private int hlsSegmentCount = 6;
    }

    @Data
    public static class HuaweiAiProperties {
        private boolean enabled = true;
        private String endpoint = "https://ais.cn-north-4.myhuaweicloud.com";
        private String projectId = "cn-north-4";
        private String ak = "";
        private String sk = "";
        private String region = "cn-north-4";
        private String behaviorTaskName = "waste_safety_behavior";
        private int captureConfidenceThreshold = 60;
        private String callbackUrl = "/api/ai-capture/callback";
    }

    @Data
    public static class LocalRecordProperties {
        private boolean enabled = true;
        private String storagePath = "/data/waste-terminal/records";
        private int maxFileSizeMb = 200;
        private int defaultPreSeconds = 10;
        private int defaultPostSeconds = 10;
        private int autoCleanupDays = 30;
        private int uploadRetryCount = 3;
    }
}
