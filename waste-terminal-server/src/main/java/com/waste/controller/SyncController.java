package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.InventoryCheckDTO;
import com.waste.dto.SyncDataDTO;
import com.waste.dto.TransferOrderDTO;
import com.waste.dto.WasteInRecordDTO;
import com.waste.dto.WasteOutRecordDTO;
import com.waste.entity.DeviceInfo;
import com.waste.entity.InventoryCheck;
import com.waste.entity.SyncRecord;
import com.waste.entity.WasteCatalog;
import com.waste.entity.WasteContainer;
import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteInventory;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteTransferOrder;
import com.waste.entity.WarningRecord;
import com.waste.mapper.DeviceInfoMapper;
import com.waste.mapper.SyncRecordMapper;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.mapper.WasteContainerMapper;
import com.waste.mapper.WasteInRecordMapper;
import com.waste.mapper.WasteOutRecordMapper;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.mapper.InventoryCheckMapper;
import com.waste.service.InventoryCheckService;
import com.waste.service.WasteCatalogService;
import com.waste.service.WasteContainerService;
import com.waste.service.WasteInRecordService;
import com.waste.service.WasteInventoryService;
import com.waste.service.WasteOutRecordService;
import com.waste.service.WasteTransferOrderService;
import com.waste.service.WarningRecordService;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/sync")
public class SyncController {

    @Autowired
    private WasteInRecordService wasteInRecordService;

    @Autowired
    private WasteOutRecordService wasteOutRecordService;

    @Autowired
    private WasteTransferOrderService wasteTransferOrderService;

    @Autowired
    private InventoryCheckService inventoryCheckService;

    @Autowired
    private WasteCatalogService wasteCatalogService;

    @Autowired
    private WasteContainerService wasteContainerService;

    @Autowired
    private WasteInventoryService wasteInventoryService;

    @Autowired
    private WarningRecordService warningRecordService;

    @Autowired
    private SyncRecordMapper syncRecordMapper;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @Autowired
    private WasteTransferOrderMapper wasteTransferOrderMapper;

    @Autowired
    private InventoryCheckMapper inventoryCheckMapper;

    @Autowired
    private DeviceInfoMapper deviceInfoMapper;

    @PostMapping("/pull")
    @RequiresLogin
    public Result<Map<String, Object>> pull(@RequestBody Map<String, Object> params) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        String lastSyncTimeStr = params.get("lastSyncTime") != null ? params.get("lastSyncTime").toString() : null;
        LocalDateTime lastSyncTime = lastSyncTimeStr != null ? LocalDateTime.parse(lastSyncTimeStr) : null;

        Map<String, Object> result = new HashMap<>();
        result.put("catalog", pullCatalogData(enterpriseId, lastSyncTime));
        result.put("container", pullContainerData(enterpriseId, lastSyncTime));
        result.put("inventory", pullInventoryData(enterpriseId, lastSyncTime));
        result.put("warning", pullWarningData(enterpriseId, lastSyncTime));
        result.put("syncTime", LocalDateTime.now());

        SyncRecord syncRecord = new SyncRecord();
        syncRecord.setSyncNo(IdGeneratorUtils.generateSyncNo());
        syncRecord.setSyncType("FULL");
        syncRecord.setSyncDirection("PULL");
        syncRecord.setSyncTime(LocalDateTime.now());
        syncRecord.setStatus(1);
        syncRecord.setEnterpriseId(enterpriseId);
        syncRecordMapper.insert(syncRecord);

        return Result.success(result);
    }

    @PostMapping("/push")
    @RequiresLogin
    @Transactional(rollbackFor = Exception.class)
    public Result<Map<String, Object>> push(@RequestBody @Validated SyncDataDTO syncDataDTO) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }

        SyncRecord syncRecord = new SyncRecord();
        syncRecord.setSyncNo(IdGeneratorUtils.generateSyncNo());
        syncRecord.setSyncType("PUSH");
        syncRecord.setSyncDirection("PUSH");
        syncRecord.setDeviceId(syncDataDTO.getDeviceId());
        syncRecord.setSyncTime(LocalDateTime.now());
        syncRecord.setStatus(1);
        syncRecord.setEnterpriseId(enterpriseId);

        int successCount = 0;
        int failCount = 0;

        if (syncDataDTO.getWasteInRecords() != null && !syncDataDTO.getWasteInRecords().isEmpty()) {
            for (WasteInRecordDTO dto : syncDataDTO.getWasteInRecords()) {
                try {
                    if (dto.getOfflineId() != null && wasteInRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
                        successCount++;
                        continue;
                    }
                    if (dto.getStatus() != null && dto.getStatus() == 1) {
                        wasteInRecordService.addWasteInRecord(dto);
                    } else {
                        wasteInRecordService.add(dto, enterpriseId);
                    }
                    successCount++;
                } catch (Exception e) {
                    failCount++;
                }
            }
        }

        if (syncDataDTO.getWasteOutRecords() != null && !syncDataDTO.getWasteOutRecords().isEmpty()) {
            for (WasteOutRecordDTO dto : syncDataDTO.getWasteOutRecords()) {
                try {
                    if (dto.getOfflineId() != null && wasteOutRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
                        successCount++;
                        continue;
                    }
                    if (dto.getStatus() != null && dto.getStatus() == 1) {
                        wasteOutRecordService.addWasteOutRecord(dto);
                    } else {
                        wasteOutRecordService.add(dto, enterpriseId);
                    }
                    successCount++;
                } catch (Exception e) {
                    failCount++;
                }
            }
        }

        if (syncDataDTO.getTransferOrders() != null && !syncDataDTO.getTransferOrders().isEmpty()) {
            for (TransferOrderDTO dto : syncDataDTO.getTransferOrders()) {
                try {
                    if (dto.getOfflineId() != null && wasteTransferOrderService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
                        successCount++;
                        continue;
                    }
                    wasteTransferOrderService.create(dto, enterpriseId);
                    successCount++;
                } catch (Exception e) {
                    failCount++;
                }
            }
        }

        if (syncDataDTO.getInventoryChecks() != null && !syncDataDTO.getInventoryChecks().isEmpty()) {
            for (InventoryCheckDTO dto : syncDataDTO.getInventoryChecks()) {
                try {
                    if (dto.getOfflineId() != null && inventoryCheckService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
                        successCount++;
                        continue;
                    }
                    inventoryCheckService.createCheck(dto, enterpriseId);
                    successCount++;
                } catch (Exception e) {
                    failCount++;
                }
            }
        }

        syncRecord.setTotalCount(successCount + failCount);
        syncRecord.setSuccessCount(successCount);
        syncRecord.setFailCount(failCount);
        syncRecordMapper.insert(syncRecord);

        Map<String, Object> result = new HashMap<>();
        result.put("syncNo", syncRecord.getSyncNo());
        result.put("successCount", successCount);
        result.put("failCount", failCount);
        result.put("totalCount", successCount + failCount);
        return Result.success(result);
    }

    @GetMapping("/status")
    @RequiresLogin
    public Result<Map<String, Object>> status(@RequestParam(required = false) String deviceId) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }

        LambdaQueryWrapper<SyncRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SyncRecord::getEnterpriseId, enterpriseId);
        if (deviceId != null && !deviceId.isEmpty()) {
            wrapper.eq(SyncRecord::getDeviceId, deviceId);
        }
        wrapper.orderByDesc(SyncRecord::getSyncTime);
        wrapper.last("LIMIT 1");
        SyncRecord lastRecord = syncRecordMapper.selectOne(wrapper);

        Map<String, Object> result = new HashMap<>();
        if (lastRecord != null) {
            result.put("lastSyncTime", lastRecord.getSyncTime());
            result.put("syncDirection", lastRecord.getSyncDirection());
            result.put("syncNo", lastRecord.getSyncNo());
            result.put("status", lastRecord.getStatus());
            result.put("totalCount", lastRecord.getTotalCount());
            result.put("successCount", lastRecord.getSuccessCount());
            result.put("failCount", lastRecord.getFailCount());
        } else {
            result.put("lastSyncTime", null);
            result.put("status", 0);
        }
        return Result.success(result);
    }

    @PostMapping("/pull/waste-catalog")
    @RequiresLogin
    public Result<List<SyncDataDTO.WasteCatalogDTO>> pullWasteCatalog(@RequestBody(required = false) Map<String, Object> params) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LocalDateTime lastSyncTime = getlastSyncTimeFromParams(params);
        return Result.success(pullCatalogData(enterpriseId, lastSyncTime));
    }

    @PostMapping("/pull/container")
    @RequiresLogin
    public Result<List<SyncDataDTO.WasteContainerDTO>> pullContainer(@RequestBody(required = false) Map<String, Object> params) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LocalDateTime lastSyncTime = getlastSyncTimeFromParams(params);
        return Result.success(pullContainerData(enterpriseId, lastSyncTime));
    }

    @PostMapping("/pull/inventory")
    @RequiresLogin
    public Result<List<WasteInventory>> pullInventory(@RequestBody(required = false) Map<String, Object> params) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(pullInventoryData(enterpriseId, null));
    }

    @PostMapping("/pull/warning")
    @RequiresLogin
    public Result<List<WarningRecord>> pullWarning(@RequestBody(required = false) Map<String, Object> params) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(pullWarningData(enterpriseId, null));
    }

    @PostMapping("/push/waste-in")
    @RequiresLogin
    public Result<Map<String, Object>> pushWasteIn(@RequestBody @Validated WasteInRecordDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && wasteInRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            Map<String, Object> result = new HashMap<>();
            result.put("duplicated", true);
            result.put("offlineId", dto.getOfflineId());
            return Result.success(result);
        }
        wasteInRecordService.add(dto, enterpriseId);
        Map<String, Object> result = new HashMap<>();
        result.put("duplicated", false);
        result.put("offlineId", dto.getOfflineId());
        return Result.success(result);
    }

    @PostMapping("/push/waste-out")
    @RequiresLogin
    public Result<Map<String, Object>> pushWasteOut(@RequestBody @Validated WasteOutRecordDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && wasteOutRecordService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            Map<String, Object> result = new HashMap<>();
            result.put("duplicated", true);
            result.put("offlineId", dto.getOfflineId());
            return Result.success(result);
        }
        wasteOutRecordService.add(dto, enterpriseId);
        Map<String, Object> result = new HashMap<>();
        result.put("duplicated", false);
        result.put("offlineId", dto.getOfflineId());
        return Result.success(result);
    }

    @PostMapping("/push/transfer-order")
    @RequiresLogin
    public Result<Map<String, Object>> pushTransferOrder(@RequestBody @Validated TransferOrderDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && wasteTransferOrderService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            Map<String, Object> result = new HashMap<>();
            result.put("duplicated", true);
            result.put("offlineId", dto.getOfflineId());
            return Result.success(result);
        }
        wasteTransferOrderService.create(dto, enterpriseId);
        Map<String, Object> result = new HashMap<>();
        result.put("duplicated", false);
        result.put("offlineId", dto.getOfflineId());
        return Result.success(result);
    }

    @PostMapping("/push/inventory-check")
    @RequiresLogin
    public Result<Map<String, Object>> pushInventoryCheck(@RequestBody @Validated InventoryCheckDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && inventoryCheckService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            Map<String, Object> result = new HashMap<>();
            result.put("duplicated", true);
            result.put("offlineId", dto.getOfflineId());
            return Result.success(result);
        }
        inventoryCheckService.createCheck(dto, enterpriseId);
        Map<String, Object> result = new HashMap<>();
        result.put("duplicated", false);
        result.put("offlineId", dto.getOfflineId());
        return Result.success(result);
    }

    @PostMapping("/upload")
    @Transactional(rollbackFor = Exception.class)
    public Result<Map<String, Object>> uploadSyncData(@RequestBody SyncDataDTO syncDataDTO,
                                                       @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }

        SyncRecord syncRecord = new SyncRecord();
        syncRecord.setSyncNo(IdGeneratorUtils.generateSyncNo());
        syncRecord.setSyncType(syncDataDTO.getSyncType());
        syncRecord.setSyncDirection("UPLOAD");
        syncRecord.setDeviceId(syncDataDTO.getDeviceId());
        syncRecord.setSyncTime(LocalDateTime.now());
        syncRecord.setStatus(1);
        syncRecord.setEnterpriseId(enterpriseId);
        syncRecordMapper.insert(syncRecord);

        int successCount = 0;
        int failCount = 0;

        if (syncDataDTO.getWasteInRecords() != null && !syncDataDTO.getWasteInRecords().isEmpty()) {
            try {
                wasteInRecordService.batchSync(syncDataDTO.getWasteInRecords(), enterpriseId);
                successCount += syncDataDTO.getWasteInRecords().size();
            } catch (Exception e) {
                failCount += syncDataDTO.getWasteInRecords().size();
            }
        }

        if (syncDataDTO.getInventoryChecks() != null && !syncDataDTO.getInventoryChecks().isEmpty()) {
            try {
                inventoryCheckService.batchSync(syncDataDTO.getInventoryChecks(), enterpriseId);
                successCount += syncDataDTO.getInventoryChecks().size();
            } catch (Exception e) {
                failCount += syncDataDTO.getInventoryChecks().size();
            }
        }

        Map<String, Object> result = new HashMap<>();
        result.put("syncNo", syncRecord.getSyncNo());
        result.put("successCount", successCount);
        result.put("failCount", failCount);
        result.put("totalCount", successCount + failCount);

        return Result.success(result);
    }

    @GetMapping("/download")
    public Result<SyncDataDTO> downloadSyncData(@RequestParam(required = false) String syncType,
                                                 @RequestParam(required = false) String deviceId,
                                                 @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }

        SyncDataDTO syncDataDTO = new SyncDataDTO();
        syncDataDTO.setSyncNo(IdGeneratorUtils.generateSyncNo());
        syncDataDTO.setSyncType(syncType);
        syncDataDTO.setSyncDirection("DOWNLOAD");
        syncDataDTO.setDeviceId(deviceId);
        syncDataDTO.setSyncTime(LocalDateTime.now());
        syncDataDTO.setEnterpriseId(enterpriseId);

        LambdaQueryWrapper<WasteCatalog> catalogWrapper = new LambdaQueryWrapper<>();
        catalogWrapper.eq(WasteCatalog::getStatus, 1);
        catalogWrapper.orderByAsc(WasteCatalog::getSortOrder);
        java.util.List<WasteCatalog> catalogList = wasteCatalogMapper.selectList(catalogWrapper);
        syncDataDTO.setWasteCatalogs(convertCatalogList(catalogList));

        LambdaQueryWrapper<WasteContainer> containerWrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            containerWrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        }
        containerWrapper.orderByAsc(WasteContainer::getContainerCode);
        java.util.List<WasteContainer> containerList = wasteContainerMapper.selectList(containerWrapper);
        syncDataDTO.setWasteContainers(convertContainerList(containerList));

        java.util.List<WasteInventory> inventoryList = wasteInventoryService.listForCache(enterpriseId);

        java.util.List<WarningRecord> warningList = warningRecordService.batchSyncList(enterpriseId);

        SyncRecord syncRecord = new SyncRecord();
        syncRecord.setSyncNo(syncDataDTO.getSyncNo());
        syncRecord.setSyncType(syncType);
        syncRecord.setSyncDirection("DOWNLOAD");
        syncRecord.setDeviceId(deviceId);
        syncRecord.setSyncTime(LocalDateTime.now());
        syncRecord.setStatus(1);
        syncRecord.setEnterpriseId(enterpriseId);
        syncRecordMapper.insert(syncRecord);

        return Result.success(syncDataDTO);
    }

    @GetMapping("/record")
    public Result<PageResult<SyncRecord>> getSyncRecords(PageQuery pageQuery, SyncRecord syncRecord,
                                                          @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Page<SyncRecord> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<SyncRecord> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(SyncRecord::getEnterpriseId, enterpriseId);
        }
        if (syncRecord != null) {
            if (syncRecord.getSyncType() != null && !syncRecord.getSyncType().isEmpty()) {
                wrapper.eq(SyncRecord::getSyncType, syncRecord.getSyncType());
            }
            if (syncRecord.getSyncDirection() != null && !syncRecord.getSyncDirection().isEmpty()) {
                wrapper.eq(SyncRecord::getSyncDirection, syncRecord.getSyncDirection());
            }
            if (syncRecord.getDeviceId() != null && !syncRecord.getDeviceId().isEmpty()) {
                wrapper.eq(SyncRecord::getDeviceId, syncRecord.getDeviceId());
            }
            if (syncRecord.getStatus() != null) {
                wrapper.eq(SyncRecord::getStatus, syncRecord.getStatus());
            }
        }
        wrapper.orderByDesc(SyncRecord::getSyncTime);
        IPage<SyncRecord> syncRecordPage = syncRecordMapper.selectPage(page, wrapper);
        PageResult<SyncRecord> pageResult = PageResult.of(syncRecordPage.getTotal(), syncRecordPage.getCurrent(),
                syncRecordPage.getSize(), syncRecordPage.getRecords());
        return Result.success(pageResult);
    }

    private List<SyncDataDTO.WasteCatalogDTO> pullCatalogData(Long enterpriseId, LocalDateTime lastSyncTime) {
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteCatalog::getStatus, 1);
        if (lastSyncTime != null) {
            wrapper.ge(WasteCatalog::getUpdateTime, lastSyncTime);
        }
        wrapper.orderByAsc(WasteCatalog::getSortOrder);
        List<WasteCatalog> catalogList = wasteCatalogMapper.selectList(wrapper);
        return convertCatalogList(catalogList);
    }

    private List<SyncDataDTO.WasteContainerDTO> pullContainerData(Long enterpriseId, LocalDateTime lastSyncTime) {
        LambdaQueryWrapper<WasteContainer> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        if (lastSyncTime != null) {
            wrapper.ge(WasteContainer::getUpdateTime, lastSyncTime);
        }
        wrapper.orderByAsc(WasteContainer::getContainerCode);
        List<WasteContainer> containerList = wasteContainerMapper.selectList(wrapper);
        return convertContainerList(containerList);
    }

    private List<WasteInventory> pullInventoryData(Long enterpriseId, LocalDateTime lastSyncTime) {
        return wasteInventoryService.listForCache(enterpriseId);
    }

    private List<WarningRecord> pullWarningData(Long enterpriseId, LocalDateTime lastSyncTime) {
        return warningRecordService.batchSyncList(enterpriseId);
    }

    private LocalDateTime getlastSyncTimeFromParams(Map<String, Object> params) {
        if (params == null || params.get("lastSyncTime") == null) {
            return null;
        }
        return LocalDateTime.parse(params.get("lastSyncTime").toString());
    }

    private java.util.List<SyncDataDTO.WasteCatalogDTO> convertCatalogList(java.util.List<WasteCatalog> catalogList) {
        java.util.List<SyncDataDTO.WasteCatalogDTO> result = new java.util.ArrayList<>();
        for (WasteCatalog catalog : catalogList) {
            SyncDataDTO.WasteCatalogDTO dto = new SyncDataDTO.WasteCatalogDTO();
            dto.setId(catalog.getId());
            dto.setWasteCode(catalog.getWasteCode());
            dto.setWasteName(catalog.getWasteName());
            dto.setWasteCategory(catalog.getWasteCategory());
            dto.setWasteType(catalog.getWasteType());
            dto.setHazardCode(catalog.getHazardCode());
            dto.setDisposalMethod(catalog.getDisposalMethod());
            dto.setStorageRequirement(catalog.getStorageRequirement());
            dto.setSafetyMeasures(catalog.getSafetyMeasures());
            dto.setDescription(catalog.getDescription());
            dto.setSortOrder(catalog.getSortOrder());
            dto.setStatus(catalog.getStatus());
            result.add(dto);
        }
        return result;
    }

    private java.util.List<SyncDataDTO.WasteContainerDTO> convertContainerList(java.util.List<WasteContainer> containerList) {
        java.util.List<SyncDataDTO.WasteContainerDTO> result = new java.util.ArrayList<>();
        for (WasteContainer container : containerList) {
            SyncDataDTO.WasteContainerDTO dto = new SyncDataDTO.WasteContainerDTO();
            dto.setId(container.getId());
            dto.setContainerCode(container.getContainerCode());
            dto.setContainerType(container.getContainerType());
            dto.setContainerSpec(container.getContainerSpec());
            dto.setMaterial(container.getMaterial());
            dto.setCapacity(container.getCapacity());
            dto.setStatus(container.getStatus());
            dto.setLocation(container.getLocation());
            dto.setRfidCode(container.getRfidCode());
            result.add(dto);
        }
        return result;
    }
}
