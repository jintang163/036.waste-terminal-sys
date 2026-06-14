package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.WasteOutRecordDTO;
import com.waste.entity.WasteContainer;
import com.waste.entity.WasteInventory;
import com.waste.entity.WasteOutRecord;
import com.waste.mapper.WasteContainerMapper;
import com.waste.mapper.WasteInventoryMapper;
import com.waste.mapper.WasteOutRecordMapper;
import com.waste.service.WasteOutRecordService;
import com.waste.utils.IdGeneratorUtils;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import com.waste.entity.WasteCatalog;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.mq.WasteMqProducer;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class WasteOutRecordServiceImpl implements WasteOutRecordService {

    @Autowired
    private WasteOutRecordMapper wasteOutRecordMapper;

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    @Override
    public IPage<WasteOutRecord> page(PageQuery pageQuery, WasteOutRecord wasteOutRecord, Long enterpriseId) {
        Page<WasteOutRecord> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteOutRecord> wrapper = buildQueryWrapper(wasteOutRecord, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteOutRecord::getCreateTime);
        }
        return wasteOutRecordMapper.selectPage(page, wrapper);
    }

    @Override
    public WasteOutRecord getById(Long id) {
        WasteOutRecord record = wasteOutRecordMapper.selectById(id);
        if (record == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return record;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(WasteOutRecordDTO dto, Long enterpriseId) {
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
        if (container.getStatus() == 0) {
            throw new BusinessException("容器未使用，无法出库");
        }

        LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
        inventoryWrapper.eq(WasteInventory::getContainerId, dto.getContainerId());
        inventoryWrapper.eq(WasteInventory::getWasteId, dto.getWasteId());
        inventoryWrapper.eq(WasteInventory::getStatus, 1);
        WasteInventory inventory = wasteInventoryMapper.selectOne(inventoryWrapper);
        if (inventory == null) {
            throw new BusinessException(ResultCode.INVENTORY_NOT_ENOUGH);
        }

        WasteOutRecord record = new WasteOutRecord();
        BeanUtils.copyProperties(dto, record);
        record.setOutNo(IdGeneratorUtils.generateOutNo());
        record.setContainerCode(container.getContainerCode());
        record.setWasteCode(inventory.getWasteCode());
        record.setWasteName(inventory.getWasteName());
        record.setStatus(0);
        record.setSignStatus(0);
        record.setSyncStatus(1);
        record.setSyncTime(LocalDateTime.now());
        if (enterpriseId != null) {
            record.setEnterpriseId(enterpriseId);
        }

        wasteOutRecordMapper.insert(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, WasteOutRecordDTO dto) {
        WasteOutRecord record = getById(id);
        if (record.getStatus() == 1) {
            throw new BusinessException("出库记录已确认，无法修改");
        }
        if (record.getStatus() == 2) {
            throw new BusinessException("出库记录已作废，无法修改");
        }

        if (dto.getReceiverUnitId() != null) {
            record.setReceiverUnitId(dto.getReceiverUnitId());
        }
        if (dto.getReceiverUnitName() != null) {
            record.setReceiverUnitName(dto.getReceiverUnitName());
        }
        if (dto.getTransporterId() != null) {
            record.setTransporterId(dto.getTransporterId());
        }
        if (dto.getTransporterName() != null) {
            record.setTransporterName(dto.getTransporterName());
        }
        if (dto.getVehicleNo() != null) {
            record.setVehicleNo(dto.getVehicleNo());
        }
        if (dto.getDriverName() != null) {
            record.setDriverName(dto.getDriverName());
        }
        if (dto.getDriverPhone() != null) {
            record.setDriverPhone(dto.getDriverPhone());
        }
        if (dto.getWeight() != null) {
            record.setWeight(dto.getWeight());
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
        if (dto.getSignPhoto() != null) {
            record.setSignPhoto(dto.getSignPhoto());
        }
        if (dto.getReceiptPhoto() != null) {
            record.setReceiptPhoto(dto.getReceiptPhoto());
        }
        if (dto.getTransferOrderId() != null) {
            record.setTransferOrderId(dto.getTransferOrderId());
        }

        wasteOutRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        WasteOutRecord record = getById(id);
        if (record.getStatus() == 1) {
            throw new BusinessException("出库记录已确认，无法删除");
        }
        wasteOutRecordMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<WasteOutRecordDTO> list, Long enterpriseId) {
        if (CollUtil.isEmpty(list)) {
            throw new BusinessException(ResultCode.SYNC_DATA_EMPTY);
        }

        List<String> offlineIds = new ArrayList<>();
        for (WasteOutRecordDTO dto : list) {
            if (StrUtil.isBlank(dto.getOfflineId())) {
                throw new BusinessException(ResultCode.SYNC_DATA_ERROR, "离线数据ID不能为空");
            }
            offlineIds.add(dto.getOfflineId());
        }

        LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(WasteOutRecord::getOfflineId, offlineIds);
        if (enterpriseId != null) {
            wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
        }
        List<WasteOutRecord> existRecords = wasteOutRecordMapper.selectList(wrapper);
        List<String> existOfflineIds = new ArrayList<>();
        for (WasteOutRecord record : existRecords) {
            existOfflineIds.add(record.getOfflineId());
        }

        for (WasteOutRecordDTO dto : list) {
            if (existOfflineIds.contains(dto.getOfflineId())) {
                continue;
            }
            try {
                add(dto, enterpriseId);
            } catch (Exception e) {
                WasteOutRecord failRecord = new WasteOutRecord();
                BeanUtils.copyProperties(dto, failRecord);
                failRecord.setOutNo(IdGeneratorUtils.generateOutNo());
                failRecord.setSyncStatus(2);
                failRecord.setSyncTime(LocalDateTime.now());
                if (enterpriseId != null) {
                    failRecord.setEnterpriseId(enterpriseId);
                }
                wasteOutRecordMapper.insert(failRecord);
            }
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void confirm(Long id) {
        WasteOutRecord record = getById(id);
        if (record.getStatus() == 1) {
            throw new BusinessException("出库记录已确认，请勿重复操作");
        }
        if (record.getStatus() == 2) {
            throw new BusinessException("出库记录已作废，无法确认");
        }

        LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
        inventoryWrapper.eq(WasteInventory::getContainerId, record.getContainerId());
        inventoryWrapper.eq(WasteInventory::getWasteId, record.getWasteId());
        inventoryWrapper.eq(WasteInventory::getStatus, 1);
        WasteInventory inventory = wasteInventoryMapper.selectOne(inventoryWrapper);
        if (inventory == null) {
            throw new BusinessException(ResultCode.INVENTORY_NOT_ENOUGH);
        }
        if (inventory.getWeight().compareTo(record.getWeight()) < 0) {
            throw new BusinessException(ResultCode.INVENTORY_NOT_ENOUGH);
        }

        inventory.setOutWeight(inventory.getOutWeight().add(record.getWeight()));
        inventory.setWeight(inventory.getWeight().subtract(record.getWeight()));
        if (inventory.getWeight().compareTo(java.math.BigDecimal.ZERO) <= 0) {
            inventory.setStatus(0);
            WasteContainer container = wasteContainerMapper.selectById(record.getContainerId());
            if (container != null) {
                container.setStatus(0);
                wasteContainerMapper.updateById(container);
            }
        }
        wasteInventoryMapper.updateById(inventory);

        record.setStatus(1);
        record.setOutTime(LocalDateTime.now());
        wasteOutRecordMapper.updateById(record);

        try {
            wasteMqProducer.sendWasteOutReport(record);
            wasteMqProducer.sendWasteOutSync(record);
            log.info("出库确认成功，已发送MQ消息, recordId={}, outNo={}", record.getId(), record.getOutNo());
        } catch (Exception e) {
            log.error("出库确认后发送MQ消息失败, recordId={}", record.getId(), e);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void sign(Long id, String signPhoto, String receiptPhoto) {
        WasteOutRecord record = getById(id);
        if (record.getSignStatus() == 1) {
            throw new BusinessException("出库记录已签收，请勿重复操作");
        }
        if (record.getStatus() == 2) {
            throw new BusinessException("出库记录已作废，无法签收");
        }
        if (record.getStatus() == 0) {
            throw new BusinessException("出库记录未确认，无法签收");
        }

        record.setSignStatus(1);
        record.setSignTime(LocalDateTime.now());
        if (StrUtil.isNotBlank(signPhoto)) {
            record.setSignPhoto(signPhoto);
        }
        if (StrUtil.isNotBlank(receiptPhoto)) {
            record.setReceiptPhoto(receiptPhoto);
        }
        wasteOutRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long id) {
        WasteOutRecord record = getById(id);
        if (record.getStatus() == 2) {
            throw new BusinessException("出库记录已作废，请勿重复操作");
        }

        if (record.getStatus() == 1) {
            LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
            inventoryWrapper.eq(WasteInventory::getContainerId, record.getContainerId());
            inventoryWrapper.eq(WasteInventory::getWasteId, record.getWasteId());
            WasteInventory inventory = wasteInventoryMapper.selectOne(inventoryWrapper);
            if (inventory != null) {
                inventory.setOutWeight(inventory.getOutWeight().subtract(record.getWeight()));
                inventory.setWeight(inventory.getWeight().add(record.getWeight()));
                inventory.setStatus(1);
                wasteInventoryMapper.updateById(inventory);

                WasteContainer container = wasteContainerMapper.selectById(record.getContainerId());
                if (container != null) {
                    container.setStatus(1);
                    wasteContainerMapper.updateById(container);
                }
            }
        }

        record.setStatus(2);
        wasteOutRecordMapper.updateById(record);
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutRecord::getOfflineId, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
        }
        Long count = wasteOutRecordMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    public List<WasteOutRecord> getPendingSyncList(Long enterpriseId) {
        LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.ne(WasteOutRecord::getSyncStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(WasteOutRecord::getCreateTime);
        return wasteOutRecordMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public WasteOutRecord addWasteOutRecord(WasteOutRecordDTO dto) {
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

        LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
        inventoryWrapper.eq(WasteInventory::getContainerId, dto.getContainerId());
        inventoryWrapper.eq(WasteInventory::getWasteId, dto.getWasteId());
        inventoryWrapper.eq(WasteInventory::getStatus, 1);
        WasteInventory inventory = wasteInventoryMapper.selectOne(inventoryWrapper);
        if (inventory == null) {
            throw new BusinessException(ResultCode.INVENTORY_NOT_ENOUGH);
        }
        if (inventory.getWeight().compareTo(dto.getWeight()) < 0) {
            throw new BusinessException(ResultCode.INVENTORY_NOT_ENOUGH);
        }

        WasteOutRecord record = new WasteOutRecord();
        BeanUtils.copyProperties(dto, record);
        record.setOutNo(IdGeneratorUtils.generateOutNo());
        record.setContainerCode(container.getContainerCode());
        record.setWasteCode(inventory.getWasteCode());
        record.setWasteName(inventory.getWasteName());
        record.setStatus(1);
        record.setSignStatus(0);
        record.setSyncStatus(1);
        record.setSyncTime(LocalDateTime.now());
        record.setOutTime(LocalDateTime.now());
        if (dto.getEnterpriseId() != null) {
            record.setEnterpriseId(dto.getEnterpriseId());
        }
        wasteOutRecordMapper.insert(record);

        inventory.setOutWeight(inventory.getOutWeight().add(dto.getWeight()));
        inventory.setWeight(inventory.getWeight().subtract(dto.getWeight()));
        if (inventory.getWeight().compareTo(java.math.BigDecimal.ZERO) <= 0) {
            inventory.setStatus(0);
            container.setStatus(0);
            wasteContainerMapper.updateById(container);
        }
        wasteInventoryMapper.updateById(inventory);

        try {
            wasteMqProducer.sendWasteOutReport(record);
            wasteMqProducer.sendWasteOutSync(record);
            log.info("出库记录创建成功，已发送MQ消息, recordId={}, outNo={}", record.getId(), record.getOutNo());
        } catch (Exception e) {
            log.error("出库记录创建后发送MQ消息失败, recordId={}", record.getId(), e);
        }

        return record;
    }

    @Override
    public List<WasteOutRecord> queryList(WasteOutRecord wasteOutRecord, Long enterpriseId) {
        LambdaQueryWrapper<WasteOutRecord> wrapper = buildQueryWrapper(wasteOutRecord, enterpriseId);
        wrapper.orderByDesc(WasteOutRecord::getCreateTime);
        return wasteOutRecordMapper.selectList(wrapper);
    }

    @Override
    public IPage<WasteOutRecord> queryPage(PageQuery pageQuery, WasteOutRecord wasteOutRecord, Long enterpriseId) {
        return page(pageQuery, wasteOutRecord, enterpriseId);
    }

    private LambdaQueryWrapper<WasteOutRecord> buildQueryWrapper(WasteOutRecord wasteOutRecord, Long enterpriseId) {
        LambdaQueryWrapper<WasteOutRecord> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
        }
        if (wasteOutRecord != null) {
            if (StrUtil.isNotBlank(wasteOutRecord.getOutNo())) {
                wrapper.like(WasteOutRecord::getOutNo, wasteOutRecord.getOutNo());
            }
            if (StrUtil.isNotBlank(wasteOutRecord.getContainerCode())) {
                wrapper.like(WasteOutRecord::getContainerCode, wasteOutRecord.getContainerCode());
            }
            if (StrUtil.isNotBlank(wasteOutRecord.getWasteCode())) {
                wrapper.like(WasteOutRecord::getWasteCode, wasteOutRecord.getWasteCode());
            }
            if (StrUtil.isNotBlank(wasteOutRecord.getWasteName())) {
                wrapper.like(WasteOutRecord::getWasteName, wasteOutRecord.getWasteName());
            }
            if (wasteOutRecord.getStatus() != null) {
                wrapper.eq(WasteOutRecord::getStatus, wasteOutRecord.getStatus());
            }
            if (wasteOutRecord.getSignStatus() != null) {
                wrapper.eq(WasteOutRecord::getSignStatus, wasteOutRecord.getSignStatus());
            }
            if (StrUtil.isNotBlank(wasteOutRecord.getReceiverUnitName())) {
                wrapper.like(WasteOutRecord::getReceiverUnitName, wasteOutRecord.getReceiverUnitName());
            }
            if (StrUtil.isNotBlank(wasteOutRecord.getOperatorName())) {
                wrapper.like(WasteOutRecord::getOperatorName, wasteOutRecord.getOperatorName());
            }
            if (wasteOutRecord.getTransferOrderId() != null) {
                wrapper.eq(WasteOutRecord::getTransferOrderId, wasteOutRecord.getTransferOrderId());
            }
        }
        return wrapper;
    }
}
