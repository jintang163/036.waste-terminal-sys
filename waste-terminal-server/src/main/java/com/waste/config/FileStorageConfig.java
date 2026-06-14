package com.waste.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 文件存储配置
 */
@Configuration
@EnableConfigurationProperties(FileStorageConfig.FileStorageProperties.class)
public class FileStorageConfig {

    @Data
    @ConfigurationProperties(prefix = "waste.file")
    public static class FileStorageProperties {

        private String uploadPath = "uploads";

        private String accessPrefix = "/files";

        private Long maxSize = 10485760L;

        private String[] allowedTypes = {"jpg", "jpeg", "png", "gif", "pdf", "doc", "docx", "xls", "xlsx"};
    }
}
