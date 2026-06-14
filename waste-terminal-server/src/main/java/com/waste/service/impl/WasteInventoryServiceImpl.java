package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.WasteContainer;
import com.waste.entity.WasteInventory;
import com.waste.mapper.WasteContainerMapper;
import com.waste.mapper.WasteInventoryMapper;
import com.waste.service.WasteInventoryService;
import com.waste.vo.WasteInventoryVO;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class WasteInventoryServiceImpl implements WasteInventoryService {

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Override
    public IPage<WasteInventoryVO> page(PageQuery pageQuery, WasteInventory wasteInventory, Long enterpriseId) {
        Page<WasteInventory> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteInventory> wrapper = buildQueryWrapper(wasteInventory, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteInventory::getCreateTime);
        }
        IPage<WasteInventory> inventoryPage = wasteInventoryMapper.selectPage(page, wrapper);
        Page<WasteInventoryVO> voPage = new Page<>(inventoryPage.getCurrent(), inventoryPage.getSize(), inventoryPage.getTotal());
        List<WasteInventoryVO> voList = new ArrayList<>();
        for (WasteInventory inventory : inventoryPage.getRecords()) {
            WasteInventoryVO vo = convertToVO(inventory);
            voList.add(vo);
        }
        voPage.setRecords(voList);
        return voPage;
    }

    @Override
    public WasteInventory getById(Long id) {
        WasteInventory inventory = wasteInventoryMapper.selectById(id);
        if (inventory == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return inventory;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(WasteInventory wasteInventory, Long enterpriseId) {
        if (wasteInventory.getContainerId() == null) {
            throw new BusinessException("容器ID不能为空");
        }
        WasteContainer container = wasteContainerMapper.selectById(wasteInventory.getContainerId());
        if (container == null) {
            throw new BusinessException(ResultCode.CONTAINER_NOT_FOUND);
        }
        if (container.getStatus() == 1) {
            throw new BusinessException(ResultCode.CONTAINER_IN_USE);
        }

        if (wasteInventory.getInDate() == null) {
            wasteInventory.setInDate(LocalDate.now());
        }
        if (wasteInventory.getStorageDays() == null) {
            wasteInventory.setStorageDays(0);
        }
        if (wasteInventory.getStorageLimit() == null) {
            wasteInventory.setStorageLimit(365);
        }
        if (wasteInventory.getWarnStatus() == null) {
            wasteInventory.setWarnStatus(0);
        }
        if (wasteInventory.getStatus() == null) {
            wasteInventory.setStatus(1);
        }
        if (wasteInventory.getOutWeight() == null) {
            wasteInventory.setOutWeight(BigDecimal.ZERO);
        }
        if (wasteInventory.getInWeight() == null && wasteInventory.getWeight() != null) {
            wasteInventory.setInWeight(wasteInventory.getWeight());
        }
        if (enterpriseId != null) {
            wasteInventory.setEnterpriseId(enterpriseId);
        }

        container.setStatus(1);
        wasteContainerMapper.updateById(container);

        wasteInventoryMapper.insert(wasteInventory);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, WasteInventory wasteInventory) {
        WasteInventory exist = getById(id);

        if (wasteInventory.getWasteId() != null) {
            exist.setWasteId(wasteInventory.getWasteId());
        }
        if (wasteInventory.getWasteCode() != null) {
            exist.setWasteCode(wasteInventory.getWasteCode());
        }
        if (wasteInventory.getWasteName() != null) {
            exist.setWasteName(wasteInventory.getWasteName());
        }
        if (wasteInventory.getWasteCategory() != null) {
            exist.setWasteCategory(wasteInventory.getWasteCategory());
        }
        if (wasteInventory.getHazardCode() != null) {
            exist.setHazardCode(wasteInventory.getHazardCode());
        }
        if (wasteInventory.getWeight() != null) {
            exist.setWeight(wasteInventory.getWeight());
        }
        if (wasteInventory.getProduceDate() != null) {
            exist.setProduceDate(wasteInventory.getProduceDate());
        }
        if (wasteInventory.getStorageLocation() != null) {
            exist.setStorageLocation(wasteInventory.getStorageLocation());
        }
        if (wasteInventory.getStorageLimit() != null) {
            exist.setStorageLimit(wasteInventory.getStorageLimit());
        }
        if (wasteInventory.getWarnStatus() != null) {
            exist.setWarnStatus(wasteInventory.getWarnStatus());
        }
        if (wasteInventory.getRemark() != null) {
            exist.setRemark(wasteInventory.getRemark());
        }

        wasteInventoryMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        WasteInventory exist = getById(id);
        if (exist.getStatus() == 1 && exist.getWeight() != null && exist.getWeight().compareTo(BigDecimal.ZERO) > 0) {
            throw new BusinessException("库存存在数据，无法删除，请先出库");
        }

        if (exist.getContainerId() != null) {
            WasteContainer container = wasteContainerMapper.selectById(exist.getContainerId());
            if (container != null) {
                container.setStatus(0);
                wasteContainerMapper.updateById(container);
            }
        }

        wasteInventoryMapper.deleteById(id);
    }

    @Override
    public WasteInventory getByContainerCode(String containerCode, Long enterpriseId) {
        if (StrUtil.isBlank(containerCode)) {
            throw new BusinessException("容器编号不能为空");
        }
        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getContainerCode, containerCode);
        wrapper.eq(WasteInventory::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        return wasteInventoryMapper.selectOne(wrapper);
    }

    @Override
    public List<Map<String, Object>> statByWasteCode(Long enterpriseId) {
        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        wrapper.groupBy(WasteInventory::getWasteCode, WasteInventory::getWasteName);
        wrapper.select(WasteInventory::getWasteCode, WasteInventory::getWasteName,
                "SUM(weight) as totalWeight", "COUNT(*) as containerCount");
        List<WasteInventory> list = wasteInventoryMapper.selectList(wrapper);
        List<Map<String, Object>> result = new ArrayList<>();
        for (WasteInventory inventory : list) {
            Map<String, Object> map = new HashMap<>();
            map.put("wasteCode", inventory.getWasteCode());
            map.put("wasteName", inventory.getWasteName());
            map.put("totalWeight", inventory.getWeight());
            map.put("containerCount", 1);
            result.add(map);
        }
        return result;
    }

    @Override
    public Map<String, Object> getStatistics(Long enterpriseId) {
        Map<String, Object> result = new HashMap<>();

        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        List<WasteInventory> list = wasteInventoryMapper.selectList(wrapper);

        BigDecimal totalWeight = BigDecimal.ZERO;
        int containerCount = 0;
        int overdueCount = 0;
        int nearExpiryCount = 0;
        int warnCount = 0;

        LocalDate today = LocalDate.now();

        for (WasteInventory inventory : list) {
            totalWeight = totalWeight.add(inventory.getWeight() != null ? inventory.getWeight() : BigDecimal.ZERO);
            containerCount++;

            if (inventory.getInDate() != null && inventory.getStorageLimit() != null) {
                long days = ChronoUnit.DAYS.between(inventory.getInDate(), today);
                int storageLimit = inventory.getStorageLimit();
                int daysRemaining = storageLimit - (int) days;

                if (daysRemaining <= 0) {
                    overdueCount++;
                } else if (daysRemaining <= 7) {
                    nearExpiryCount++;
                }
            }

            if (inventory.getWarnStatus() != null && inventory.getWarnStatus() > 0) {
                warnCount++;
            }
        }

        result.put("totalWeight", totalWeight);
        result.put("containerCount", containerCount);
        result.put("overdueCount", overdueCount);
        result.put("nearExpiryCount", nearExpiryCount);
        result.put("warnCount", warnCount);

        return result;
    }

    @Override
    public BigDecimal getCapacityRate(Long enterpriseId) {
        LambdaQueryWrapper<WasteContainer> containerWrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            containerWrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        }
        List<WasteContainer> containers = wasteContainerMapper.selectList(containerWrapper);

        BigDecimal totalCapacity = BigDecimal.ZERO;
        for (WasteContainer container : containers) {
            if (container.getCapacity() != null) {
                totalCapacity = totalCapacity.add(container.getCapacity());
            }
        }

        if (totalCapacity.compareTo(BigDecimal.ZERO) == 0) {
            return BigDecimal.ZERO;
        }

        LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
        inventoryWrapper.eq(WasteInventory::getStatus, 1);
        if (enterpriseId != null) {
            inventoryWrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        List<WasteInventory> inventories = wasteInventoryMapper.selectList(inventoryWrapper);

        BigDecimal usedCapacity = BigDecimal.ZERO;
        for (WasteInventory inventory : inventories) {
            if (inventory.getWeight() != null) {
                usedCapacity = usedCapacity.add(inventory.getWeight());
            }
        }

        return usedCapacity.divide(totalCapacity, 4, RoundingMode.HALF_UP).multiply(new BigDecimal("100"));
    }

    @Override
    public List<WasteInventory> listForCache(Long enterpriseId) {
        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(WasteInventory::getContainerCode);
        return wasteInventoryMapper.selectList(wrapper);
    }

    private WasteInventoryVO convertToVO(WasteInventory inventory) {
        WasteInventoryVO vo = new WasteInventoryVO();
        BeanUtils.copyProperties(inventory, vo);

        if (inventory.getWarnStatus() != null) {
            switch (inventory.getWarnStatus()) {
                case 0:
                    vo.setWarnStatusName("正常");
                    break;
                case 1:
                    vo.setWarnStatusName("即将超期");
                    break;
                case 2:
                    vo.setWarnStatusName("已超期");
                    break;
                case 3:
                    vo.setWarnStatusName("超量预警");
                    break;
                default:
                    vo.setWarnStatusName("未知");
            }
        }

        if (inventory.getStatus() != null) {
            switch (inventory.getStatus()) {
                case 0:
                    vo.setStatusName("已出库");
                    break;
                case 1:
                    vo.setStatusName("在库");
                    break;
                default:
                    vo.setStatusName("未知");
            }
        }

        return vo;
    }

    private LambdaQueryWrapper<WasteInventory> buildQueryWrapper(WasteInventory wasteInventory, Long enterpriseId) {
        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        if (wasteInventory != null) {
            if (StrUtil.isNotBlank(wasteInventory.getContainerCode())) {
                wrapper.like(WasteInventory::getContainerCode, wasteInventory.getContainerCode());
            }
            if (StrUtil.isNotBlank(wasteInventory.getWasteCode())) {
                wrapper.like(WasteInventory::getWasteCode, wasteInventory.getWasteCode());
            }
            if (StrUtil.isNotBlank(wasteInventory.getWasteName())) {
                wrapper.like(WasteInventory::getWasteName, wasteInventory.getWasteName());
            }
            if (StrUtil.isNotBlank(wasteInventory.getWasteCategory())) {
                wrapper.eq(WasteInventory::getWasteCategory, wasteInventory.getWasteCategory());
            }
            if (StrUtil.isNotBlank(wasteInventory.getHazardCode())) {
                wrapper.like(WasteInventory::getHazardCode, wasteInventory.getHazardCode());
            }
            if (wasteInventory.getWarnStatus() != null) {
                wrapper.eq(WasteInventory::getWarnStatus, wasteInventory.getWarnStatus());
            }
            if (wasteInventory.getStatus() != null) {
                wrapper.eq(WasteInventory::getStatus, wasteInventory.getStatus());
            }
            if (StrUtil.isNotBlank(wasteInventory.getStorageLocation())) {
                wrapper.like(WasteInventory::getStorageLocation, wasteInventory.getStorageLocation());
            }
        }
        return wrapper;
    }
}
