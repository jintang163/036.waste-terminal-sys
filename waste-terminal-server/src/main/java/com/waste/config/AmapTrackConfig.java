package com.waste.config;

import lombok.Data;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
public class AmapTrackConfig {

    @Value("${amap.track.key:}")
    private String key;

    @Value("${amap.track.service-id:}")
    private String defaultServiceId;

    @Value("${amap.track.url:https://tsapi.amap.com/v1/track}")
    private String apiUrl;

    @Value("${amap.track.connection-timeout:10000}")
    private Integer connectionTimeout;

    @Value("${amap.track.read-timeout:30000}")
    private Integer readTimeout;

    @Value("${amap.track.mock-enabled:false}")
    private Boolean mockEnabled;
}
