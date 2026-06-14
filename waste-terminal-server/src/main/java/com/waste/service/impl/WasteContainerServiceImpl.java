package com.waste.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.WasteContainer;
import com.waste.mapper.WasteContainerMapper;
import com.waste.service.WasteContainerService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class WasteContainerServiceImpl implements WasteContainerService {

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Override
    public IPage<WasteContainer> page(PageQuery pageQuery, WasteContainer wasteContainer, Long enterpriseId) {
        Page<WasteContainer> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteContainer> wrapper = buildQueryWrapper(wasteContainer, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteContainer::getCreateTime);
        }
        return wasteContainerMapper.selectPage(page, wrapper);
    }

    @Override
    public WasteContainer getById(Long id) {
        WasteContainer container = wasteContainerMapper.selectById(id);
        if (container == null) {
            throw new BusinessException(ResultCode.CONTAINER_NOT_FOUND);
        }
        return container;
    }

    @Override
    public WasteContainer getByCode(String containerCode, Long enterpriseId) {
        LambdaQueryWrapper<WasteContainer> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteContainer::getContainerCode, containerCode);
        if (enterpriseId != null) {
            wrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        }
        return wasteContainerMapper.selectOne(wrapper);
    }

    @Override
    public List<WasteContainer> getAvailableList(Long enterpriseId) {
        LambdaQueryWrapper<WasteContainer> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteContainer::getStatus, 0);
        if (enterpriseId != null) {
            wrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(WasteContainer::getContainerCode);
        return wasteContainerMapper.selectList(wrapper);
    }

    @Override
    public void add(WasteContainer wasteContainer, Long enterpriseId) {
        WasteContainer exist = getByCode(wasteContainer.getContainerCode(), enterpriseId);
        if (exist != null) {
            throw new BusinessException(ResultCode.CONTAINER_CODE_EXIST);
        }
        if (wasteContainer.getStatus() == null) {
            wasteContainer.setStatus(0);
        }
        if (enterpriseId != null) {
            wasteContainer.setEnterpriseId(enterpriseId);
        }
        wasteContainerMapper.insert(wasteContainer);
    }

    @Override
    public void update(WasteContainer wasteContainer) {
        WasteContainer exist = getById(wasteContainer.getId());
        if (!exist.getContainerCode().equals(wasteContainer.getContainerCode())) {
            WasteContainer codeExist = getByCode(wasteContainer.getContainerCode(), exist.getEnterpriseId());
            if (codeExist != null) {
                throw new BusinessException(ResultCode.CONTAINER_CODE_EXIST);
            }
        }
        wasteContainerMapper.updateById(wasteContainer);
    }

    @Override
    public void delete(Long id) {
        WasteContainer container = getById(id);
        if (container.getStatus() == 1) {
            throw new BusinessException(ResultCode.CONTAINER_IN_USE);
        }
        wasteContainerMapper.deleteById(id);
    }

    @Override
    public void updateStatus(Long id, Integer status) {
        WasteContainer container = getById(id);
        container.setStatus(status);
        wasteContainerMapper.updateById(container);
    }

    private LambdaQueryWrapper<WasteContainer> buildQueryWrapper(WasteContainer wasteContainer, Long enterpriseId) {
        LambdaQueryWrapper<WasteContainer> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WasteContainer::getEnterpriseId, enterpriseId);
        }
        if (wasteContainer != null) {
            if (wasteContainer.getContainerCode() != null && !wasteContainer.getContainerCode().isEmpty()) {
                wrapper.like(WasteContainer::getContainerCode, wasteContainer.getContainerCode());
            }
            if (wasteContainer.getContainerType() != null && !wasteContainer.getContainerType().isEmpty()) {
                wrapper.eq(WasteContainer::getContainerType, wasteContainer.getContainerType());
            }
            if (wasteContainer.getContainerSpec() != null && !wasteContainer.getContainerSpec().isEmpty()) {
                wrapper.like(WasteContainer::getContainerSpec, wasteContainer.getContainerSpec());
            }
            if (wasteContainer.getStatus() != null) {
                wrapper.eq(WasteContainer::getStatus, wasteContainer.getStatus());
            }
            if (wasteContainer.getLocation() != null && !wasteContainer.getLocation().isEmpty()) {
                wrapper.like(WasteContainer::getLocation, wasteContainer.getLocation());
            }
            if (wasteContainer.getRfidCode() != null && !wasteContainer.getRfidCode().isEmpty()) {
                wrapper.eq(WasteContainer::getRfidCode, wasteContainer.getRfidCode());
            }
        }
        return wrapper;
    }
}
