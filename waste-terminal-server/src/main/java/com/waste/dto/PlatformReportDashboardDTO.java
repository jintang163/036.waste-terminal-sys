package com.waste.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class PlatformReportDashboardDTO {

    private ReportStatistics statistics;

    private List<RecentReportItem> recentReports;

    private List<FailedReportItem> failedReports;

    private List<RetryQueueItem> retryQueue;

    @Data
    public static class ReportStatistics {
        private Long totalReports;
        private Long successCount;
        private Long failCount;
        private Long pendingCount;
        private Long retryingCount;
        private BigDecimal successRate;
        private LocalDateTime lastSuccessTime;
        private LocalDateTime lastReportTime;
    }

    @Data
    public static class RecentReportItem {
        private Long id;
        private String reportNo;
        private String bizType;
        private String bizNo;
        private Integer reportStatus;
        private Integer retryCount;
        private LocalDateTime lastReportTime;
        private String failReason;
        private String nationalBizNo;
    }

    @Data
    public static class FailedReportItem {
        private Long id;
        private String reportNo;
        private String bizType;
        private String bizNo;
        private Integer retryCount;
        private Integer maxRetryCount;
        private LocalDateTime lastReportTime;
        private String failReason;
        private String requestPayload;
        private Boolean canManualRetry;
    }

    @Data
    public static class RetryQueueItem {
        private Long id;
        private String reportNo;
        private String bizType;
        private String bizNo;
        private Integer retryCount;
        private Integer maxRetryCount;
        private LocalDateTime nextRetryTime;
        private String failReason;
    }

    @Data
    public static class ManualRetryRequest {
        private Long id;
        private Boolean forceResend;
    }

    @Data
    public static class ManualRetryResult {
        private Long id;
        private Boolean success;
        private String message;
        private String nationalBizNo;
    }
}
