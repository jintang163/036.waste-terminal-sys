package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.waste.dto.*;
import com.waste.entity.*;
import com.waste.mapper.*;
import com.waste.service.*;
import com.waste.utils.IdGeneratorUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class DataSyncServiceImpl implements DataSyncService {

    public static final String DATA_TYPE_WASTE_CATALOG = "WASTE_CATALOG";
    public static final String DATA_TYPE_RECEIVER_UNIT = "RECEIVER_UNIT";
    public static final String DATA_TYPE_VEHICLE = "VEHICLE";
    public static final String DATA_TYPE_CONTAINER = "CONTAINER";
    public static final String DATA_TYPE_INVENTORY = "INVENTORY";

    public static final String ENTITY_TYPE_WASTE_IN = "WASTE_IN";
    public static final String ENTITY_TYPE_WASTE_OUT = "WASTE_OUT";
    public static final String ENTITY_TYPE_INVENTORY_CHECK = "INVENTORY_CHECK";

    public static final String OPERATION_TYPE_CREATE = "CREATE";
    public static final String OPERATION_TYPE_UPDATE = "UPDATE";
    public static final String OPERATION_TYPE_DELETE = "DELETE";
    public static final String OPERATION_TYPE_CONFIRM = "CONFIRM";
    public static final String OPERATION_TYPE_CANCEL = "CANCEL";

    public static final int OPERATION_STATUS_SUCCESS = 1;
    public static final int OPERATION_STATUS_CONFLICT = 2;
    public static final int OPERATION_STATUS_DUPLICATE = 3;
    public static final int OPERATION_STATUS_FAIL = 0;

    public static final String CONFLICT_STRATEGY_LAST_WRITE_WINS = "LAST_WRITE_WINS";

    @Autowired
    private DataVersionMapper dataVersionMapper;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Autowired
    private EnterpriseInfoMapper enterpriseInfoMapper;

    @Autowired
    private DeviceInfoMapper deviceInfoMapper;

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private WasteInRecordService wasteInRecordService;

    @Autowired
    private WasteOutRecordService wasteOutRecordService;

    @Autowired
    private InventoryCheckService inventoryCheckService;

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @Autowired
    private InventoryCheckMapper inventoryCheckMapper;

    @Autowired
    private InventoryCheckDetailMapper inventoryCheckDetailMapper;

    @Autowired
    private ObjectMapper objectMapper;

    @Override
    public Map<String, DeltaSyncResultDTO.VersionInfo> getCurrentVersions(Long enterpriseId) {
        Map<String, DeltaSyncResultDTO.VersionInfo> result = new LinkedHashMap<>();

        String[] dataTypes = {
                DATA_TYPE_WASTE_CATALOG,
                DATA_TYPE_RECEIVER_UNIT,
                DATA_TYPE_VEHICLE,
                DATA_TYPE_CONTAINER,
                DATA_TYPE_INVENTORY
        };

        for (String dataType : dataTypes) {
            result.put(dataType, buildVersionInfo(dataType, enterpriseId));
        }

        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void bumpVersion(String dataType, Long enterpriseId, String changeSummary, Long recordCount) {
        LambdaQueryWrapper<DataVersion> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(DataVersion::getDataType, dataType);
        if (enterpriseId != null) {
            wrapper.eq(DataVersion::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(DataVersion::getVersion);
        wrapper.last("LIMIT 1");
        DataVersion latest = dataVersionMapper.selectOne(wrapper);

        long nextVersion = latest != null && latest.getVersion() != null ? latest.getVersion() + 1 : 1L;

        DataVersion dv = new DataVersion();
        dv.setDataType(dataType);
        dv.setVersion(nextVersion);
        dv.setVersionTime(LocalDateTime.now());
        dv.setChangeSummary(changeSummary);
        dv.setRecordCount(recordCount);
        dv.setEnterpriseId(enterpriseId);
        dataVersionMapper.insert(dv);

        log.info("数据版本已更新: dataType={}, version={}, enterpriseId={}", dataType, nextVersion, enterpriseId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public DeltaSyncResultDTO performDeltaSync(DeltaSyncDTO request, Long enterpriseId) {
        long startTime = System.currentTimeMillis();

        DeltaSyncResultDTO result = new DeltaSyncResultDTO();
        result.setSyncNo(IdGeneratorUtils.generateSyncNo());
        result.setServerSyncTime(LocalDateTime.now());

        List<DeltaSyncResultDTO.OperationResult> operationResults = new ArrayList<>();
        List<DeltaSyncResultDTO.ConflictInfo> conflicts = new ArrayList<>();
        int successCount = 0;
        int conflictCount = 0;
        int duplicateCount = 0;
        int failCount = 0;

        result.setVersionInfos(collectVersionInfos(request.getDataVersions(), enterpriseId));
        result.setDictionaryData(collectDictionaryData(request.getDataVersions(), enterpriseId));

        List<DeltaSyncDTO.OperationQueueItem> sortedQueue = sortOperationQueue(request.getOperationQueue());

        if (CollUtil.isNotEmpty(sortedQueue)) {
            for (DeltaSyncDTO.OperationQueueItem item : sortedQueue) {
                DeltaSyncResultDTO.OperationResult opResult = processOperation(item, enterpriseId, conflicts);
                operationResults.add(opResult);

                switch (opResult.getStatus()) {
                    case OPERATION_STATUS_SUCCESS:
                        successCount++;
                        break;
                    case OPERATION_STATUS_CONFLICT:
                        conflictCount++;
                        successCount++;
                        break;
                    case OPERATION_STATUS_DUPLICATE:
                        duplicateCount++;
                        break;
                    default:
                        failCount++;
                        break;
                }
            }
        }

        DeltaSyncResultDTO.SyncStatistics stats = new DeltaSyncResultDTO.SyncStatistics();
        stats.setTotalOperations(sortedQueue != null ? sortedQueue.size() : 0);
        stats.setSuccessCount(successCount);
        stats.setConflictCount(conflictCount);
        stats.setDuplicateCount(duplicateCount);
        stats.setFailCount(failCount);
        stats.setSyncDurationMs(System.currentTimeMillis() - startTime);
        result.setStatistics(stats);

        result.setOperationResults(operationResults);
        result.setHasConflicts(!conflicts.isEmpty());
        result.setConflicts(conflicts);

        log.info("增量同步完成: syncNo={}, total={}, success={}, conflict={}, duplicate={}, fail={}, duration={}ms",
                result.getSyncNo(), stats.getTotalOperations(), successCount, conflictCount, duplicateCount, failCount, stats.getSyncDurationMs());

        return result;
    }

    private Map<String, DeltaSyncResultDTO.VersionInfo> collectVersionInfos(Map<String, Long> clientVersions, Long enterpriseId) {
        Map<String, DeltaSyncResultDTO.VersionInfo> result = new LinkedHashMap<>();

        String[] dataTypes = {
                DATA_TYPE_WASTE_CATALOG,
                DATA_TYPE_RECEIVER_UNIT,
                DATA_TYPE_VEHICLE,
                DATA_TYPE_CONTAINER,
                DATA_TYPE_INVENTORY
        };

        for (String dataType : dataTypes) {
            DeltaSyncResultDTO.VersionInfo info = buildVersionInfo(dataType, enterpriseId);
            Long clientVer = clientVersions != null ? clientVersions.get(dataType) : null;
            info.setHasChanges(clientVer == null || info.getCurrentVersion() > clientVer);
            info.setPreviousVersion(clientVer);
            result.put(dataType, info);
        }

        return result;
    }

    private DeltaSyncResultDTO.VersionInfo buildVersionInfo(String dataType, Long enterpriseId) {
        DeltaSyncResultDTO.VersionInfo info = new DeltaSyncResultDTO.VersionInfo();
        info.setDataType(dataType);

        LambdaQueryWrapper<DataVersion> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(DataVersion::getDataType, dataType);
        if (enterpriseId != null && !DATA_TYPE_WASTE_CATALOG.equals(dataType)) {
            wrapper.eq(DataVersion::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(DataVersion::getVersion);
        wrapper.last("LIMIT 1");
        DataVersion latest = dataVersionMapper.selectOne(wrapper);

        if (latest != null) {
            info.setCurrentVersion(latest.getVersion());
            info.setVersionTime(latest.getVersionTime());
            info.setRecordCount(latest.getRecordCount());
        } else {
            info.setCurrentVersion(1L);
            info.setRecordCount(0L);
            info.setVersionTime(LocalDateTime.now());
        }

        return info;
    }

    private DeltaSyncResultDTO.DictionaryData collectDictionaryData(Map<String, Long> clientVersions, Long enterpriseId) {
        DeltaSyncResultDTO.DictionaryData data = new DeltaSyncResultDTO.DictionaryData();

        if (shouldPull(clientVersions, DATA_TYPE_WASTE_CATALOG)) {
            data.setWasteCatalogs(pullWasteCatalogs(null));
        }
        if (shouldPull(clientVersions, DATA_TYPE_RECEIVER_UNIT)) {
            data.setReceiverUnits(pullReceiverUnits(enterpriseId, null));
        }
        if (shouldPull(clientVersions, DATA_TYPE_VEHICLE)) {
            data.setVehicles(pullVehicles(enterpriseId, null));
        }
        if (shouldPull(clientVersions, DATA_TYPE_CONTAINER)) {
            data.setContainers(pullContainers(enterpriseId, null));
        }

        return data;
    }

    private boolean shouldPull(Map<String, Long> clientVersions, String dataType) {
        if (clientVersions == null || clientVersions.get(dataType) == null) {
            return true;
        }
        LambdaQueryWrapper<DataVersion> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(DataVersion::getDataType, dataType);
        wrapper.orderByDesc(DataVersion::getVersion);
        wrapper.last("LIMIT 1");
        DataVersion latest = dataVersionMapper.selectOne(wrapper);
        if (latest == null) {
            return false;
        }
        return latest.getVersion() > clientVersions.get(dataType);
    }

    private List<SyncDataDTO.WasteCatalogDTO> pullWasteCatalogs(LocalDateTime since) {
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteCatalog::getStatus, 1);
        if (since != null) {
            wrapper.ge(WasteCatalog::getUpdateTime, since);
        }
        wrapper.orderByAsc(WasteCatalog::getSortOrder);
        List<WasteCatalog> list = wasteCatalogMapper.selectList(wrapper);
        List<SyncDataDTO.WasteCatalogDTO> result = new ArrayList<>();
        for (WasteCatalog c : list) {
            SyncDataDTO.WasteCatalogDTO dto = new SyncDataDTO.WasteCatalogDTO();
            BeanUtils.copyProperties(c, dto);
            result.add(dto);
        }
        return result;
    }

    private List<DeltaSyncResultDTO.EnterpriseInfoDTO> pullReceiverUnits(Long enterpriseId, LocalDateTime since) {
        LambdaQueryWrapper<EnterpriseInfo> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(EnterpriseInfo::getStatus, 1);
        if (since != null) {
            wrapper.ge(EnterpriseInfo::getUpdateTime, since);
        }
        List<EnterpriseInfo> list = enterpriseInfoMapper.selectList(wrapper);
        List<DeltaSyncResultDTO.EnterpriseInfoDTO> result = new ArrayList<>();
        for (EnterpriseInfo e : list) {
            DeltaSyncResultDTO.EnterpriseInfoDTO dto = new DeltaSyncResultDTO.EnterpriseInfoDTO();
            dto.setId(e.getId());
            dto.setEnterpriseName(e.getEnterpriseName());
            dto.setEnterpriseCode(e.getEnterpriseCode());
            dto.setContactPerson(e.getContactPerson());
            dto.setContactPhone(e.getContactPhone());
            dto.setAddress(e.getAddress());
            dto.setStatus(e.getStatus());
            result.add(dto);
        }
        return result;
    }

    private List<DeltaSyncResultDTO.VehicleInfoDTO> pullVehicles(Long enterpriseId, LocalDateTime since) {
        LambdaQueryWrapper<DeviceInfo> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(DeviceInfo::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(DeviceInfo::getEnterpriseId, enterpriseId);
        }
        if (since != null) {
            wrapper.ge(DeviceInfo::getUpdateTime, since);
        }
        wrapper.and(w -> w.eq(DeviceInfo::getDeviceType, "VEHICLE").or().like(DeviceInfo::getDeviceType, "车"));
        List<DeviceInfo> list = deviceInfoMapper.selectList(wrapper);
        List<DeltaSyncResultDTO.VehicleInfoDTO> result = new ArrayList<>();
        for (DeviceInfo d : list) {
            DeltaSyncResultDTO.VehicleInfoDTO dto = new DeltaSyncResultDTO.VehicleInfoDTO();
            dto.setId(d.getId());
            dto.setDeviceNo(d.getDeviceNo());
            dto.setDeviceName(d.getDeviceName());
            dto.setVehicleNo(d.getDeviceNo());
            dto.setDeviceType(d.getDeviceType());
            dto.setStatus(d.getStatus());
            result.add(dto);
        }
        return result;
    }

    private List<SyncDataDTO.WasteContainerDTO> pullContainers(Long enterpriseId, LocalDateTime since) {
        LambdaQueryWrapper<WasteContainer> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        }
        if (since != null) {
            wrapper.ge(WasteContainer::getUpdateTime, since);
        }
        wrapper.orderByAsc(WasteContainer::getContainerCode);
        List<WasteContainer> list = wasteContainerMapper.selectList(wrapper);
        List<SyncDataDTO.WasteContainerDTO> result = new ArrayList<>();
        for (WasteContainer c : list) {
            SyncDataDTO.WasteContainerDTO dto = new SyncDataDTO.WasteContainerDTO();
            BeanUtils.copyProperties(c, dto);
            result.add(dto);
        }
        return result;
    }

    private List<DeltaSyncDTO.OperationQueueItem> sortOperationQueue(List<DeltaSyncDTO.OperationQueueItem> queue) {
        if (CollUtil.isEmpty(queue)) {
            return Collections.emptyList();
        }
        return queue.stream()
                .sorted(Comparator.comparing(
                        DeltaSyncDTO.OperationQueueItem::getOperationTime,
                        Comparator.nullsLast(Comparator.naturalOrder())
                ))
                .collect(Collectors.toList());
    }

    private DeltaSyncResultDTO.OperationResult processOperation(
            DeltaSyncDTO.OperationQueueItem item,
            Long enterpriseId,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        DeltaSyncResultDTO.OperationResult result = new DeltaSyncResultDTO.OperationResult();
        result.setOperationId(item.getOperationId());
        result.setEntityType(item.getEntityType());
        result.setOperationType(item.getOperationType());

        try {
            switch (item.getEntityType()) {
                case ENTITY_TYPE_WASTE_IN:
                    processWasteInOperation(item, enterpriseId, result, conflicts);
                    break;
                case ENTITY_TYPE_WASTE_OUT:
                    processWasteOutOperation(item, enterpriseId, result, conflicts);
                    break;
                case ENTITY_TYPE_INVENTORY_CHECK:
                    processInventoryCheckOperation(item, enterpriseId, result, conflicts);
                    break;
                default:
                    result.setStatus(OPERATION_STATUS_FAIL);
                    result.setErrorMessage("未知的实体类型: " + item.getEntityType());
                    break;
            }
        } catch (Exception e) {
            log.error("处理操作失败: operationId={}, entityType={}", item.getOperationId(), item.getEntityType(), e);
            result.setStatus(OPERATION_STATUS_FAIL);
            result.setErrorMessage(e.getMessage());
        }

        return result;
    }

    @Transactional(rollbackFor = Exception.class)
    protected void processWasteInOperation(
            DeltaSyncDTO.OperationQueueItem item,
            Long enterpriseId,
            DeltaSyncResultDTO.OperationResult result,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        WasteInRecordDTO dto = convertPayload(item.getPayload(), WasteInRecordDTO.class);
        if (dto == null) {
            result.setStatus(OPERATION_STATUS_FAIL);
            result.setErrorMessage("载荷解析失败");
            return;
        }

        String offlineId = dto.getOfflineId();
        if (StrUtil.isBlank(offlineId)) {
            offlineId = item.getOperationId();
            dto.setOfflineId(offlineId);
        }

        if (OPERATION_TYPE_CREATE.equals(item.getOperationType()) || OPERATION_TYPE_CONFIRM.equals(item.getOperationType())) {
            boolean exists = wasteInRecordService.checkByOfflineId(offlineId, enterpriseId);
            if (exists) {
                LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
                wrapper.eq(WasteInRecord::getOfflineId, offlineId);
                if (enterpriseId != null) {
                    wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
                }
                WasteInRecord existing = wasteInRecordMapper.selectOne(wrapper);

                if (existing != null && detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                    resolveWasteInConflict(existing, dto, item, result, conflicts);
                    return;
                }

                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
                result.setServerEntityId(existing != null ? existing.getId() : null);
                return;
            }

            try {
                if (OPERATION_TYPE_CONFIRM.equals(item.getOperationType()) ||
                        (dto.getStatus() != null && dto.getStatus() == 1)) {
                    WasteInRecord created = wasteInRecordService.addWasteInRecord(dto);
                    result.setServerEntityId(created.getId());
                } else {
                    wasteInRecordService.add(dto, enterpriseId);
                    LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
                    wrapper.eq(WasteInRecord::getOfflineId, offlineId);
                    if (enterpriseId != null) {
                        wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
                    }
                    WasteInRecord created = wasteInRecordMapper.selectOne(wrapper);
                    if (created != null) {
                        result.setServerEntityId(created.getId());
                    }
                }
                result.setStatus(OPERATION_STATUS_SUCCESS);
            } catch (Exception e) {
                log.error("入库操作失败: offlineId={}", offlineId, e);
                result.setStatus(OPERATION_STATUS_FAIL);
                result.setErrorMessage(e.getMessage());
            }
        } else if (OPERATION_TYPE_UPDATE.equals(item.getOperationType())) {
            LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteInRecord::getOfflineId, offlineId);
            if (enterpriseId != null) {
                wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
            }
            WasteInRecord existing = wasteInRecordMapper.selectOne(wrapper);
            if (existing == null) {
                try {
                    wasteInRecordService.add(dto, enterpriseId);
                    result.setStatus(OPERATION_STATUS_SUCCESS);
                } catch (Exception e) {
                    result.setStatus(OPERATION_STATUS_FAIL);
                    result.setErrorMessage(e.getMessage());
                }
                return;
            }

            if (detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                resolveWasteInConflict(existing, dto, item, result, conflicts);
            } else {
                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
                result.setServerEntityId(existing.getId());
            }
        } else if (OPERATION_TYPE_CANCEL.equals(item.getOperationType())) {
            LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteInRecord::getOfflineId, offlineId);
            if (enterpriseId != null) {
                wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
            }
            WasteInRecord existing = wasteInRecordMapper.selectOne(wrapper);
            if (existing != null) {
                if (detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                    resolveWasteInConflict(existing, dto, item, result, conflicts);
                } else {
                    try {
                        wasteInRecordService.cancel(existing.getId());
                        result.setStatus(OPERATION_STATUS_SUCCESS);
                        result.setServerEntityId(existing.getId());
                    } catch (Exception e) {
                        result.setStatus(OPERATION_STATUS_FAIL);
                        result.setErrorMessage(e.getMessage());
                    }
                }
            } else {
                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
            }
        }
    }

    @Transactional(rollbackFor = Exception.class)
    protected void processWasteOutOperation(
            DeltaSyncDTO.OperationQueueItem item,
            Long enterpriseId,
            DeltaSyncResultDTO.OperationResult result,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        WasteOutRecordDTO dto = convertPayload(item.getPayload(), WasteOutRecordDTO.class);
        if (dto == null) {
            result.setStatus(OPERATION_STATUS_FAIL);
            result.setErrorMessage("载荷解析失败");
            return;
        }

        String offlineId = dto.getOfflineId();
        if (StrUtil.isBlank(offlineId)) {
            offlineId = item.getOperationId();
            dto.setOfflineId(offlineId);
        }

        if (OPERATION_TYPE_CREATE.equals(item.getOperationType()) || OPERATION_TYPE_CONFIRM.equals(item.getOperationType())) {
            boolean exists = wasteOutRecordService.checkByOfflineId(offlineId, enterpriseId);
            if (exists) {
                LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
                wrapper.eq(WasteOutRecord::getOfflineId, offlineId);
                if (enterpriseId != null) {
                    wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
                }
                WasteOutRecord existing = wasteOutRecordMapper.selectOne(wrapper);

                if (existing != null && detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                    resolveWasteOutConflict(existing, dto, item, result, conflicts);
                    return;
                }

                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
                result.setServerEntityId(existing != null ? existing.getId() : null);
                return;
            }

            try {
                if (OPERATION_TYPE_CONFIRM.equals(item.getOperationType()) ||
                        (dto.getStatus() != null && dto.getStatus() == 1)) {
                    WasteOutRecord created = wasteOutRecordService.addWasteOutRecord(dto);
                    result.setServerEntityId(created.getId());
                } else {
                    wasteOutRecordService.add(dto, enterpriseId);
                    LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
                    wrapper.eq(WasteOutRecord::getOfflineId, offlineId);
                    if (enterpriseId != null) {
                        wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
                    }
                    WasteOutRecord created = wasteOutRecordMapper.selectOne(wrapper);
                    if (created != null) {
                        result.setServerEntityId(created.getId());
                    }
                }
                result.setStatus(OPERATION_STATUS_SUCCESS);
            } catch (Exception e) {
                log.error("出库操作失败: offlineId={}", offlineId, e);
                result.setStatus(OPERATION_STATUS_FAIL);
                result.setErrorMessage(e.getMessage());
            }
        } else if (OPERATION_TYPE_UPDATE.equals(item.getOperationType())) {
            LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteOutRecord::getOfflineId, offlineId);
            if (enterpriseId != null) {
                wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
            }
            WasteOutRecord existing = wasteOutRecordMapper.selectOne(wrapper);
            if (existing == null) {
                try {
                    wasteOutRecordService.add(dto, enterpriseId);
                    result.setStatus(OPERATION_STATUS_SUCCESS);
                } catch (Exception e) {
                    result.setStatus(OPERATION_STATUS_FAIL);
                    result.setErrorMessage(e.getMessage());
                }
                return;
            }

            if (detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                resolveWasteOutConflict(existing, dto, item, result, conflicts);
            } else {
                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
                result.setServerEntityId(existing.getId());
            }
        } else if (OPERATION_TYPE_CANCEL.equals(item.getOperationType())) {
            LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteOutRecord::getOfflineId, offlineId);
            if (enterpriseId != null) {
                wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
            }
            WasteOutRecord existing = wasteOutRecordMapper.selectOne(wrapper);
            if (existing != null) {
                if (detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                    resolveWasteOutConflict(existing, dto, item, result, conflicts);
                } else {
                    try {
                        wasteOutRecordService.cancel(existing.getId());
                        result.setStatus(OPERATION_STATUS_SUCCESS);
                        result.setServerEntityId(existing.getId());
                    } catch (Exception e) {
                        result.setStatus(OPERATION_STATUS_FAIL);
                        result.setErrorMessage(e.getMessage());
                    }
                }
            } else {
                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
            }
        }
    }

    @Transactional(rollbackFor = Exception.class)
    protected void processInventoryCheckOperation(
            DeltaSyncDTO.OperationQueueItem item,
            Long enterpriseId,
            DeltaSyncResultDTO.OperationResult result,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        InventoryCheckDTO dto = convertPayload(item.getPayload(), InventoryCheckDTO.class);
        if (dto == null) {
            result.setStatus(OPERATION_STATUS_FAIL);
            result.setErrorMessage("载荷解析失败");
            return;
        }

        String offlineId = dto.getOfflineId();
        if (StrUtil.isBlank(offlineId)) {
            offlineId = item.getOperationId();
            dto.setOfflineId(offlineId);
        }

        if (OPERATION_TYPE_CREATE.equals(item.getOperationType()) || OPERATION_TYPE_CONFIRM.equals(item.getOperationType())) {
            boolean exists = inventoryCheckService.checkByOfflineId(offlineId, enterpriseId);
            if (exists) {
                LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
                wrapper.eq(InventoryCheck::getOfflineId, offlineId);
                if (enterpriseId != null) {
                    wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
                }
                InventoryCheck existing = inventoryCheckMapper.selectOne(wrapper);

                if (existing != null && detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                    resolveInventoryCheckConflict(existing, dto, item, result, conflicts);
                    return;
                }

                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
                result.setServerEntityId(existing != null ? existing.getId() : null);
                return;
            }

            try {
                inventoryCheckService.createCheck(dto, enterpriseId);
                if (CollUtil.isNotEmpty(dto.getDetails())) {
                    LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
                    wrapper.eq(InventoryCheck::getOfflineId, offlineId);
                    if (enterpriseId != null) {
                        wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
                    }
                    InventoryCheck created = inventoryCheckMapper.selectOne(wrapper);
                    if (created != null) {
                        for (InventoryCheckDTO.CheckDetailDTO detailDTO : dto.getDetails()) {
                            inventoryCheckService.addDetail(created.getId(), detailDTO);
                        }
                        if (OPERATION_TYPE_CONFIRM.equals(item.getOperationType()) ||
                                (dto.getStatus() != null && dto.getStatus() == 1)) {
                            inventoryCheckService.completeCheck(created.getId());
                        }
                        result.setServerEntityId(created.getId());
                    }
                }
                result.setStatus(OPERATION_STATUS_SUCCESS);
            } catch (Exception e) {
                log.error("盘点操作失败: offlineId={}", offlineId, e);
                result.setStatus(OPERATION_STATUS_FAIL);
                result.setErrorMessage(e.getMessage());
            }
        } else if (OPERATION_TYPE_UPDATE.equals(item.getOperationType())) {
            LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(InventoryCheck::getOfflineId, offlineId);
            if (enterpriseId != null) {
                wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
            }
            InventoryCheck existing = inventoryCheckMapper.selectOne(wrapper);
            if (existing == null) {
                try {
                    inventoryCheckService.createCheck(dto, enterpriseId);
                    result.setStatus(OPERATION_STATUS_SUCCESS);
                } catch (Exception e) {
                    result.setStatus(OPERATION_STATUS_FAIL);
                    result.setErrorMessage(e.getMessage());
                }
                return;
            }

            if (detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                resolveInventoryCheckConflict(existing, dto, item, result, conflicts);
            } else {
                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
                result.setServerEntityId(existing.getId());
            }
        } else if (OPERATION_TYPE_CANCEL.equals(item.getOperationType())) {
            LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(InventoryCheck::getOfflineId, offlineId);
            if (enterpriseId != null) {
                wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
            }
            InventoryCheck existing = inventoryCheckMapper.selectOne(wrapper);
            if (existing != null) {
                if (detectAndResolveConflict(existing.getUpdateTime(), item.getOperationTime())) {
                    resolveInventoryCheckConflict(existing, dto, item, result, conflicts);
                } else {
                    try {
                        inventoryCheckService.cancel(existing.getId());
                        result.setStatus(OPERATION_STATUS_SUCCESS);
                        result.setServerEntityId(existing.getId());
                    } catch (Exception e) {
                        result.setStatus(OPERATION_STATUS_FAIL);
                        result.setErrorMessage(e.getMessage());
                    }
                }
            } else {
                result.setStatus(OPERATION_STATUS_DUPLICATE);
                result.setIsDuplicate(true);
            }
        }
    }

    private boolean detectAndResolveConflict(LocalDateTime serverUpdateTime, LocalDateTime clientOperationTime) {
        if (serverUpdateTime == null || clientOperationTime == null) {
            return false;
        }
        return clientOperationTime.isAfter(serverUpdateTime);
    }

    private void resolveWasteInConflict(
            WasteInRecord existing,
            WasteInRecordDTO dto,
            DeltaSyncDTO.OperationQueueItem item,
            DeltaSyncResultDTO.OperationResult result,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        List<String> conflictFields = new ArrayList<>();

        if (dto.getWeight() != null && existing.getWeight() != null
                && dto.getWeight().compareTo(existing.getWeight()) != 0) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_WASTE_IN, existing.getId(),
                    "weight", existing.getWeight(), dto.getWeight(), dto.getWeight());
            conflicts.add(ci);
            conflictFields.add("weight");
            existing.setWeight(dto.getWeight());
        }

        if (dto.getRemark() != null && !dto.getRemark().equals(existing.getRemark())) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_WASTE_IN, existing.getId(),
                    "remark", existing.getRemark(), dto.getRemark(), dto.getRemark());
            conflicts.add(ci);
            conflictFields.add("remark");
            existing.setRemark(dto.getRemark());
        }

        if (dto.getStatus() != null && !dto.getStatus().equals(existing.getStatus())) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_WASTE_IN, existing.getId(),
                    "status", existing.getStatus(), dto.getStatus(), dto.getStatus());
            conflicts.add(ci);
            conflictFields.add("status");
            existing.setStatus(dto.getStatus());
        }

        if (!conflictFields.isEmpty()) {
            wasteInRecordMapper.updateById(existing);
            result.setStatus(OPERATION_STATUS_CONFLICT);
            result.setHasConflict(true);
            result.setConflictResolution(CONFLICT_STRATEGY_LAST_WRITE_WINS);
            result.setServerEntityId(existing.getId());
            log.info("入库冲突解决(最后写入优先): offlineId={}, 冲突字段={}", dto.getOfflineId(), conflictFields);
        } else {
            result.setStatus(OPERATION_STATUS_DUPLICATE);
            result.setIsDuplicate(true);
            result.setServerEntityId(existing.getId());
        }
    }

    private void resolveWasteOutConflict(
            WasteOutRecord existing,
            WasteOutRecordDTO dto,
            DeltaSyncDTO.OperationQueueItem item,
            DeltaSyncResultDTO.OperationResult result,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        List<String> conflictFields = new ArrayList<>();

        if (dto.getWeight() != null && existing.getWeight() != null
                && dto.getWeight().compareTo(existing.getWeight()) != 0) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_WASTE_OUT, existing.getId(),
                    "weight", existing.getWeight(), dto.getWeight(), dto.getWeight());
            conflicts.add(ci);
            conflictFields.add("weight");
            existing.setWeight(dto.getWeight());
        }

        if (dto.getRemark() != null && !dto.getRemark().equals(existing.getRemark())) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_WASTE_OUT, existing.getId(),
                    "remark", existing.getRemark(), dto.getRemark(), dto.getRemark());
            conflicts.add(ci);
            conflictFields.add("remark");
            existing.setRemark(dto.getRemark());
        }

        if (dto.getStatus() != null && !dto.getStatus().equals(existing.getStatus())) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_WASTE_OUT, existing.getId(),
                    "status", existing.getStatus(), dto.getStatus(), dto.getStatus());
            conflicts.add(ci);
            conflictFields.add("status");
            existing.setStatus(dto.getStatus());
        }

        if (!conflictFields.isEmpty()) {
            wasteOutRecordMapper.updateById(existing);
            result.setStatus(OPERATION_STATUS_CONFLICT);
            result.setHasConflict(true);
            result.setConflictResolution(CONFLICT_STRATEGY_LAST_WRITE_WINS);
            result.setServerEntityId(existing.getId());
            log.info("出库冲突解决(最后写入优先): offlineId={}, 冲突字段={}", dto.getOfflineId(), conflictFields);
        } else {
            result.setStatus(OPERATION_STATUS_DUPLICATE);
            result.setIsDuplicate(true);
            result.setServerEntityId(existing.getId());
        }
    }

    private void resolveInventoryCheckConflict(
            InventoryCheck existing,
            InventoryCheckDTO dto,
            DeltaSyncDTO.OperationQueueItem item,
            DeltaSyncResultDTO.OperationResult result,
            List<DeltaSyncResultDTO.ConflictInfo> conflicts) {

        List<String> conflictFields = new ArrayList<>();

        if (dto.getDiffWeight() != null && existing.getDiffWeight() != null
                && dto.getDiffWeight().compareTo(existing.getDiffWeight()) != 0) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_INVENTORY_CHECK, existing.getId(),
                    "diffWeight", existing.getDiffWeight(), dto.getDiffWeight(), dto.getDiffWeight());
            conflicts.add(ci);
            conflictFields.add("diffWeight");
            existing.setDiffWeight(dto.getDiffWeight());
        }

        if (dto.getRemark() != null && !dto.getRemark().equals(existing.getRemark())) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_INVENTORY_CHECK, existing.getId(),
                    "remark", existing.getRemark(), dto.getRemark(), dto.getRemark());
            conflicts.add(ci);
            conflictFields.add("remark");
            existing.setRemark(dto.getRemark());
        }

        if (dto.getStatus() != null && !dto.getStatus().equals(existing.getStatus())) {
            DeltaSyncResultDTO.ConflictInfo ci = buildConflictInfo(
                    item.getOperationId(), ENTITY_TYPE_INVENTORY_CHECK, existing.getId(),
                    "status", existing.getStatus(), dto.getStatus(), dto.getStatus());
            conflicts.add(ci);
            conflictFields.add("status");
            existing.setStatus(dto.getStatus());
        }

        if (!conflictFields.isEmpty()) {
            inventoryCheckMapper.updateById(existing);
            result.setStatus(OPERATION_STATUS_CONFLICT);
            result.setHasConflict(true);
            result.setConflictResolution(CONFLICT_STRATEGY_LAST_WRITE_WINS);
            result.setServerEntityId(existing.getId());
            log.info("盘点冲突解决(最后写入优先): offlineId={}, 冲突字段={}", dto.getOfflineId(), conflictFields);
        } else {
            result.setStatus(OPERATION_STATUS_DUPLICATE);
            result.setIsDuplicate(true);
            result.setServerEntityId(existing.getId());
        }
    }

    private DeltaSyncResultDTO.ConflictInfo buildConflictInfo(
            String operationId, String entityType, Long entityId,
            String fieldName, Object serverValue, Object clientValue, Object resolvedValue) {
        DeltaSyncResultDTO.ConflictInfo ci = new DeltaSyncResultDTO.ConflictInfo();
        ci.setOperationId(operationId);
        ci.setEntityType(entityType);
        ci.setEntityId(entityId != null ? entityId.toString() : null);
        ci.setFieldName(fieldName);
        ci.setServerValue(serverValue);
        ci.setClientValue(clientValue);
        ci.setResolvedValue(resolvedValue);
        ci.setResolutionStrategy(CONFLICT_STRATEGY_LAST_WRITE_WINS);
        return ci;
    }

    private <T> T convertPayload(Object payload, Class<T> clazz) {
        if (payload == null) {
            return null;
        }
        if (clazz.isInstance(payload)) {
            return clazz.cast(payload);
        }
        try {
            return objectMapper.convertValue(payload, clazz);
        } catch (Exception e) {
            log.warn("Payload转换失败, 尝试类型引用方式: {}", e.getMessage());
            try {
                return objectMapper.readValue(objectMapper.writeValueAsString(payload), clazz);
            } catch (Exception ex) {
                log.error("Payload转换失败", ex);
                return null;
            }
        }
    }
}
