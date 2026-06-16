package com.waste.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(WasteAiRecognitionConfig.WasteAiRecognitionProperties.class)
public class WasteAiRecognitionConfig {

    @Data
    @ConfigurationProperties(prefix = "waste.ai.recognition")
    public static class WasteAiRecognitionProperties {

        private boolean enabled = true;

        private String provider = "huawei";

        private String endpoint = "";

        private String ak = "";

        private String sk = "";

        private String modelId = "";

        private double confidenceThreshold = 0.6;

        private long maxFileSize = 5242880L;

        private int connectionTimeout = 10000;

        private int readTimeout = 30000;

        private boolean mockEnabled = true;
    }
}
