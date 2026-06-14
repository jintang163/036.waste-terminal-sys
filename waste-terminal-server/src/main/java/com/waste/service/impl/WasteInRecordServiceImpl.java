package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.WasteInRecordDTO;
import com.waste.entity.WasteCatalog;
import com.waste.entity.WasteContainer;
import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteInventory;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.mapper.WasteContainerMapper;
import com.waste.mapper.WasteInRecordMapper;
import com.waste.mapper.WasteInventoryMapper;
import com.waste.mq.WasteMqProducer;
import com.waste.service.WasteInRecordService;
import com.waste.utils.IdGeneratorUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class WasteInRecordServiceImpl implements WasteInRecordService {

    @Autowired
    private WasteInRecordMapper wasteInRecordMapper;

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    @Override
    public IPage<WasteInRecord> page(PageQuery pageQuery, WasteInRecord wasteInRecord, Long enterpriseId) {
        Page<WasteInRecord> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteInRecord> wrapper = buildQueryWrapper(wasteInRecord, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteInRecord::getCreateTime);
        }
        return wasteInRecordMapper.selectPage(page, wrapper);
    }

    @Override
    public WasteInRecord getById(Long id) {
        WasteInRecord record = wasteInRecordMapper.selectById(id);
        if (record == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return record;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(WasteInRecordDTO dto, Long enterpriseId) {
        if (StrUtil.isNotBlank(dto.getOfflineId())) {
            boolean exist = checkByOfflineId(dto.getOfflineId(), enterpriseId);
            if (exist) {
                throw new BusinessException(ResultCode.OFFLINE_ID_EXIST);
            }
        }

        WasteContainer container = wasteContainerMapper.selectById(dto.getContainerId());
        if (container == null) {
            throw new BusinessException(ResultCode.CONTAINER_NOT_FOUND);
        }
        if (container.getStatus() == 1) {
            throw new BusinessException(ResultCode.CONTAINER_IN_USE);
        }

        WasteCatalog catalog = wasteCatalogMapper.selectById(dto.getWasteId());
        if (catalog == null) {
            throw new BusinessException(ResultCode.WASTE_NOT_FOUND);
        }

        WasteInRecord record = new WasteInRecord();
        BeanUtils.copyProperties(dto, record);
        record.setInNo(IdGeneratorUtils.generateInNo());
        record.setContainerCode(container.getContainerCode());
        record.setWasteCode(catalog.getWasteCode());
        record.setWasteName(catalog.getWasteName());
        record.setWasteCategory(catalog.getWasteCategory());
        record.setHazardCode(catalog.getHazardCode());
        if (dto.getPhotoUrls() != null && !dto.getPhotoUrls().isEmpty()) {
            record.setPhotos(String.join(",", dto.getPhotoUrls()));
        }
        record.setStatus(0);
        record.setSyncStatus(1);
        record.setSyncTime(LocalDateTime.now());
        if (enterpriseId != null) {
            record.setEnterpriseId(enterpriseId);
        }

        wasteInRecordMapper.insert(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, WasteInRecordDTO dto) {
        WasteInRecord record = getById(id);
        if (record.getStatus() == 1) {
            throw new BusinessException("入库记录已确认，无法修改");
        }
        if (record.getStatus() == 2) {
            throw new BusinessException("入库记录已作废，无法修改");
        }

        if (dto.getContainerId() != null && !dto.getContainerId().equals(record.getContainerId())) {
            WasteContainer newContainer = wasteContainerMapper.selectById(dto.getContainerId());
            if (newContainer == null) {
                throw new BusinessException(ResultCode.CONTAINER_NOT_FOUND);
            }
            if (newContainer.getStatus() == 1) {
                throw new BusinessException(ResultCode.CONTAINER_IN_USE);
            }
            record.setContainerId(dto.getContainerId());
            record.setContainerCode(newContainer.getContainerCode());
        }

        if (dto.getWasteId() != null && !dto.getWasteId().equals(record.getWasteId())) {
            WasteCatalog catalog = wasteCatalogMapper.selectById(dto.getWasteId());
            if (catalog == null) {
                throw new BusinessException(ResultCode.WASTE_NOT_FOUND);
            }
            record.setWasteId(dto.getWasteId());
            record.setWasteCode(catalog.getWasteCode());
            record.setWasteName(catalog.getWasteName());
            record.setWasteCategory(catalog.getWasteCategory());
            record.setHazardCode(catalog.getHazardCode());
        }

        if (dto.getWeight() != null) {
            record.setWeight(dto.getWeight());
        }
        if (dto.getWeightSource() != null) {
            record.setWeightSource(dto.getWeightSource());
        }
        if (dto.getScaleDevice() != null) {
            record.setScaleDevice(dto.getScaleDevice());
        }
        if (dto.getProduceDate() != null) {
            record.setProduceDate(dto.getProduceDate());
        }
        if (dto.getProduceDepartment() != null) {
            record.setProduceDepartment(dto.getProduceDepartment());
        }
        if (dto.getStorageLocation() != null) {
            record.setStorageLocation(dto.getStorageLocation());
        }
        if (dto.getOperatorId() != null) {
            record.setOperatorId(dto.getOperatorId());
        }
        if (dto.getOperatorName() != null) {
            record.setOperatorName(dto.getOperatorName());
        }
        if (dto.getRemark() != null) {
            record.setRemark(dto.getRemark());
        }
        if (dto.getPhotoUrls() != null && !dto.getPhotoUrls().isEmpty()) {
            record.setPhotos(String.join(",", dto.getPhotoUrls()));
        }

        wasteInRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        WasteInRecord record = getById(id);
        if (record.getStatus() == 1) {
            throw new BusinessException("入库记录已确认，无法删除");
        }
        wasteInRecordMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<WasteInRecordDTO> list, Long enterpriseId) {
        if (CollUtil.isEmpty(list)) {
            throw new BusinessException(ResultCode.SYNC_DATA_EMPTY);
        }

        List<String> offlineIds = new ArrayList<>();
        for (WasteInRecordDTO dto : list) {
            if (StrUtil.isBlank(dto.getOfflineId())) {
                throw new BusinessException(ResultCode.SYNC_DATA_ERROR, "离线数据ID不能为空");
            }
            offlineIds.add(dto.getOfflineId());
        }

        LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(WasteInRecord::getOfflineId, offlineIds);
        if (enterpriseId != null) {
            wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
        }
        List<WasteInRecord> existRecords = wasteInRecordMapper.selectList(wrapper);
        List<String> existOfflineIds = new ArrayList<>();
        for (WasteInRecord record : existRecords) {
            existOfflineIds.add(record.getOfflineId());
        }

        for (WasteInRecordDTO dto : list) {
            if (existOfflineIds.contains(dto.getOfflineId())) {
                continue;
            }
            try {
                add(dto, enterpriseId);
            } catch (Exception e) {
                WasteInRecord failRecord = new WasteInRecord();
                BeanUtils.copyProperties(dto, failRecord);
                failRecord.setInNo(IdGeneratorUtils.generateInNo());
                failRecord.setSyncStatus(2);
                failRecord.setSyncFailReason(e.getMessage());
                failRecord.setSyncTime(LocalDateTime.now());
                if (enterpriseId != null) {
                    failRecord.setEnterpriseId(enterpriseId);
                }
                wasteInRecordMapper.insert(failRecord);
            }
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void confirm(Long id) {
        WasteInRecord record = getById(id);
        if (record.getStatus() == 1) {
            throw new BusinessException("入库记录已确认，请勿重复操作");
        }
        if (record.getStatus() == 2) {
            throw new BusinessException("入库记录已作废，无法确认");
        }

        WasteContainer container = wasteContainerMapper.selectById(record.getContainerId());
        if (container == null) {
            throw new BusinessException(ResultCode.CONTAINER_NOT_FOUND);
        }

        WasteInventory inventory = new WasteInventory();
        inventory.setContainerId(record.getContainerId());
        inventory.setContainerCode(record.getContainerCode());
        inventory.setWasteId(record.getWasteId());
        inventory.setWasteCode(record.getWasteCode());
        inventory.setWasteName(record.getWasteName());
        inventory.setWasteCategory(record.getWasteCategory());
        inventory.setHazardCode(record.getHazardCode());
        inventory.setWeight(record.getWeight());
        inventory.setInWeight(record.getWeight());
        inventory.setOutWeight(java.math.BigDecimal.ZERO);
        inventory.setStorageDays(0);
        inventory.setStorageLimit(365);
        inventory.setProduceDate(record.getProduceDate());
        inventory.setInDate(LocalDate.now());
        inventory.setStorageLocation(record.getStorageLocation());
        inventory.setWarnStatus(0);
        inventory.setStatus(1);
        inventory.setEnterpriseId(record.getEnterpriseId());
        wasteInventoryMapper.insert(inventory);

        container.setStatus(1);
        wasteContainerMapper.updateById(container);

        record.setStatus(1);
        wasteInRecordMapper.updateById(record);

        try {
            wasteMqProducer.sendWasteInReport(record);
            wasteMqProducer.sendWasteInSync(record);
            log.info("入库确认成功，已发送MQ消息, recordId={}, inNo={}", record.getId(), record.getInNo());
        } catch (Exception e) {
            log.error("入库确认后发送MQ消息失败, recordId={}", record.getId(), e);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long id) {
        WasteInRecord record = getById(id);
        if (record.getStatus() == 2) {
            throw new BusinessException("入库记录已作废，请勿重复操作");
        }

        if (record.getStatus() == 1) {
            LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(WasteInventory::getContainerId, record.getContainerId());
            wrapper.eq(WasteInventory::getWasteId, record.getWasteId());
            wrapper.eq(WasteInventory::getStatus, 1);
            WasteInventory inventory = wasteInventoryMapper.selectOne(wrapper);
            if (inventory != null) {
                inventory.setStatus(0);
                wasteInventoryMapper.updateById(inventory);
            }

            WasteContainer container = wasteContainerMapper.selectById(record.getContainerId());
            if (container != null) {
                container.setStatus(0);
                wasteContainerMapper.updateById(container);
            }
        }

        record.setStatus(2);
        wasteInRecordMapper.updateById(record);
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInRecord::getOfflineId, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
        }
        Long count = wasteInRecordMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    public List<WasteInRecord> getPendingSyncList(Long enterpriseId) {
        LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.ne(WasteInRecord::getSyncStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(WasteInRecord::getCreateTime);
        return wasteInRecordMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public WasteInRecord addWasteInRecord(WasteInRecordDTO dto) {
        if (StrUtil.isNotBlank(dto.getOfflineId())) {
            boolean exist = checkByOfflineId(dto.getOfflineId(), dto.getEnterpriseId());
            if (exist) {
                throw new BusinessException(ResultCode.OFFLINE_ID_EXIST);
            }
        }

        WasteContainer container = wasteContainerMapper.selectById(dto.getContainerId());
        if (container == null) {
            throw new BusinessException(ResultCode.CONTAINER_NOT_FOUND);
        }

        WasteCatalog catalog = wasteCatalogMapper.selectById(dto.getWasteId());
        if (catalog == null) {
            throw new BusinessException(ResultCode.WASTE_NOT_FOUND);
        }

        WasteInRecord record = new WasteInRecord();
        BeanUtils.copyProperties(dto, record);
        record.setInNo(IdGeneratorUtils.generateInNo());
        record.setContainerCode(container.getContainerCode());
        record.setWasteCode(catalog.getWasteCode());
        record.setWasteName(catalog.getWasteName());
        record.setWasteCategory(catalog.getWasteCategory());
        record.setHazardCode(catalog.getHazardCode());
        if (dto.getPhotoUrls() != null && !dto.getPhotoUrls().isEmpty()) {
            record.setPhotos(String.join(",", dto.getPhotoUrls()));
        }
        record.setStatus(1);
        record.setSyncStatus(1);
        record.setSyncTime(LocalDateTime.now());
        if (dto.getEnterpriseId() != null) {
            record.setEnterpriseId(dto.getEnterpriseId());
        }
        wasteInRecordMapper.insert(record);

        LambdaQueryWrapper<WasteInventory> invWrapper = new LambdaQueryWrapper<>();
        invWrapper.eq(WasteInventory::getContainerId, dto.getContainerId());
        invWrapper.eq(WasteInventory::getWasteId, dto.getWasteId());
        invWrapper.eq(WasteInventory::getStatus, 1);
        WasteInventory existInventory = wasteInventoryMapper.selectOne(invWrapper);

        if (existInventory != null) {
            existInventory.setWeight(existInventory.getWeight().add(dto.getWeight()));
            existInventory.setInWeight(existInventory.getInWeight().add(dto.getWeight()));
            wasteInventoryMapper.updateById(existInventory);
        } else {
            WasteInventory inventory = new WasteInventory();
            inventory.setContainerId(dto.getContainerId());
            inventory.setContainerCode(container.getContainerCode());
            inventory.setWasteId(dto.getWasteId());
            inventory.setWasteCode(catalog.getWasteCode());
            inventory.setWasteName(catalog.getWasteName());
            inventory.setWasteCategory(catalog.getWasteCategory());
            inventory.setHazardCode(catalog.getHazardCode());
            inventory.setWeight(dto.getWeight());
            inventory.setInWeight(dto.getWeight());
            inventory.setOutWeight(java.math.BigDecimal.ZERO);
            inventory.setStorageDays(0);
            inventory.setStorageLimit(365);
            inventory.setProduceDate(dto.getProduceDate());
            inventory.setInDate(LocalDate.now());
            inventory.setStorageLocation(dto.getStorageLocation());
            inventory.setWarnStatus(0);
            inventory.setStatus(1);
            inventory.setEnterpriseId(dto.getEnterpriseId());
            wasteInventoryMapper.insert(inventory);
        }

        container.setStatus(1);
        wasteContainerMapper.updateById(container);

        try {
            wasteMqProducer.sendWasteInReport(record);
            wasteMqProducer.sendWasteInSync(record);
            log.info("入库记录创建成功，已发送MQ消息, recordId={}, inNo={}", record.getId(), record.getInNo());
        } catch (Exception e) {
            log.error("入库记录创建后发送MQ消息失败, recordId={}", record.getId(), e);
        }

        return record;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Integer> batchAddWasteInRecord(List<WasteInRecordDTO> dtoList) {
        Map<String, Integer> result = new HashMap<>();
        int successCount = 0;
        int failCount = 0;
        for (WasteInRecordDTO dto : dtoList) {
            try {
                addWasteInRecord(dto);
                successCount++;
            } catch (Exception e) {
                failCount++;
            }
        }
        result.put("success", successCount);
        result.put("fail", failCount);
        return result;
    }

    @Override
    public List<WasteInRecord> queryList(WasteInRecord wasteInRecord, Long enterpriseId) {
        LambdaQueryWrapper<WasteInRecord> wrapper = buildQueryWrapper(wasteInRecord, enterpriseId);
        wrapper.orderByDesc(WasteInRecord::getCreateTime);
        return wasteInRecordMapper.selectList(wrapper);
    }

    @Override
    public IPage<WasteInRecord> queryPage(PageQuery pageQuery, WasteInRecord wasteInRecord, Long enterpriseId) {
        return page(pageQuery, wasteInRecord, enterpriseId);
    }

    private LambdaQueryWrapper<WasteInRecord> buildQueryWrapper(WasteInRecord wasteInRecord, Long enterpriseId) {
        LambdaQueryWrapper<WasteInRecord> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WasteInRecord::getEnterpriseId, enterpriseId);
        }
        if (wasteInRecord != null) {
            if (wasteInRecord.getInNo() != null && !wasteInRecord.getInNo().isEmpty()) {
                wrapper.like(WasteInRecord::getInNo, wasteInRecord.getInNo());
            }
            if (wasteInRecord.getContainerCode() != null && !wasteInRecord.getContainerCode().isEmpty()) {
                wrapper.like(WasteInRecord::getContainerCode, wasteInRecord.getContainerCode());
            }
            if (wasteInRecord.getWasteCode() != null && !wasteInRecord.getWasteCode().isEmpty()) {
                wrapper.like(WasteInRecord::getWasteCode, wasteInRecord.getWasteCode());
            }
            if (wasteInRecord.getWasteName() != null && !wasteInRecord.getWasteName().isEmpty()) {
                wrapper.like(WasteInRecord::getWasteName, wasteInRecord.getWasteName());
            }
            if (wasteInRecord.getWasteCategory() != null && !wasteInRecord.getWasteCategory().isEmpty()) {
                wrapper.eq(WasteInRecord::getWasteCategory, wasteInRecord.getWasteCategory());
            }
            if (wasteInRecord.getStatus() != null) {
                wrapper.eq(WasteInRecord::getStatus, wasteInRecord.getStatus());
            }
            if (wasteInRecord.getSyncStatus() != null) {
                wrapper.eq(WasteInRecord::getSyncStatus, wasteInRecord.getSyncStatus());
            }
            if (wasteInRecord.getOperatorName() != null && !wasteInRecord.getOperatorName().isEmpty()) {
                wrapper.like(WasteInRecord::getOperatorName, wasteInRecord.getOperatorName());
            }
            if (wasteInRecord.getStorageLocation() != null && !wasteInRecord.getStorageLocation().isEmpty()) {
                wrapper.like(WasteInRecord::getStorageLocation, wasteInRecord.getStorageLocation());
            }
        }
        return wrapper;
    }
}
