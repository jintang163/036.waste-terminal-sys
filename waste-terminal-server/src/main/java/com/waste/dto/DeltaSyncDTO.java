package com.waste.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data
public class DeltaSyncDTO {

    private String deviceId;

    private Long enterpriseId;

    private LocalDateTime clientSyncTime;

    private Map<String, Long> dataVersions;

    private List<OperationQueueItem> operationQueue;

    @Data
    public static class OperationQueueItem {

        private String operationId;

        private String operationType;

        private LocalDateTime operationTime;

        private String entityType;

        private String entityId;

        private Integer operationStatus;

        private Integer retryCount;

        private String errorMessage;

        private Object payload;
    }
}
