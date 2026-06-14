package com.waste.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data
public class DeltaSyncResultDTO {

    private String syncNo;

    private LocalDateTime serverSyncTime;

    private Map<String, VersionInfo> versionInfos;

    private DictionaryData dictionaryData;

    private SyncStatistics statistics;

    private List<OperationResult> operationResults;

    private Boolean hasConflicts;

    private List<ConflictInfo> conflicts;

    @Data
    public static class VersionInfo {
        private String dataType;
        private Long currentVersion;
        private Long previousVersion;
        private LocalDateTime versionTime;
        private Long recordCount;
        private Boolean hasChanges;
    }

    @Data
    public static class DictionaryData {
        private List<SyncDataDTO.WasteCatalogDTO> wasteCatalogs;
        private List<EnterpriseInfoDTO> receiverUnits;
        private List<VehicleInfoDTO> vehicles;
        private List<SyncDataDTO.WasteContainerDTO> containers;
    }

    @Data
    public static class EnterpriseInfoDTO {
        private Long id;
        private String enterpriseName;
        private String enterpriseCode;
        private String contactPerson;
        private String contactPhone;
        private String address;
        private Integer status;
    }

    @Data
    public static class VehicleInfoDTO {
        private Long id;
        private String deviceNo;
        private String deviceName;
        private String vehicleNo;
        private String deviceType;
        private Integer status;
    }

    @Data
    public static class SyncStatistics {
        private Integer totalOperations;
        private Integer successCount;
        private Integer conflictCount;
        private Integer duplicateCount;
        private Integer failCount;
        private Long syncDurationMs;
    }

    @Data
    public static class OperationResult {
        private String operationId;
        private String entityType;
        private String operationType;
        private Integer status;
        private Boolean isDuplicate;
        private Boolean hasConflict;
        private String conflictResolution;
        private String errorMessage;
        private Long serverEntityId;
    }

    @Data
    public static class ConflictInfo {
        private String operationId;
        private String entityType;
        private String entityId;
        private String fieldName;
        private Object clientValue;
        private Object serverValue;
        private Object resolvedValue;
        private String resolutionStrategy;
    }
}
