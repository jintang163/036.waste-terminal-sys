package com.waste.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.WasteCatalog;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.service.WasteCatalogService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class WasteCatalogServiceImpl implements WasteCatalogService {

    @Autowired
    private WasteCatalogMapper wasteCatalogMapper;

    @Override
    public IPage<WasteCatalog> page(PageQuery pageQuery, WasteCatalog wasteCatalog, Long enterpriseId) {
        Page<WasteCatalog> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteCatalog> wrapper = buildQueryWrapper(wasteCatalog, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteCatalog::getCreateTime);
        }
        return wasteCatalogMapper.selectPage(page, wrapper);
    }

    @Override
    public WasteCatalog getById(Long id) {
        WasteCatalog wasteCatalog = wasteCatalogMapper.selectById(id);
        if (wasteCatalog == null) {
            throw new BusinessException(ResultCode.WASTE_NOT_FOUND);
        }
        return wasteCatalog;
    }

    @Override
    public WasteCatalog getByWasteCode(String wasteCode, Long enterpriseId) {
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteCatalog::getWasteCode, wasteCode);
        if (enterpriseId != null) {
            // 名录表如果是全局的，可能不需要企业ID过滤，这里保留扩展
        }
        return wasteCatalogMapper.selectOne(wrapper);
    }

    @Override
    public List<WasteCatalog> listAll(Long enterpriseId) {
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteCatalog::getStatus, 1);
        wrapper.orderByAsc(WasteCatalog::getSortOrder);
        return wasteCatalogMapper.selectList(wrapper);
    }

    @Override
    public void add(WasteCatalog wasteCatalog, Long enterpriseId) {
        WasteCatalog exist = getByWasteCode(wasteCatalog.getWasteCode(), enterpriseId);
        if (exist != null) {
            throw new BusinessException(ResultCode.WASTE_CODE_EXIST);
        }
        if (wasteCatalog.getStatus() == null) {
            wasteCatalog.setStatus(1);
        }
        if (wasteCatalog.getSortOrder() == null) {
            wasteCatalog.setSortOrder(0);
        }
        wasteCatalogMapper.insert(wasteCatalog);
    }

    @Override
    public void update(WasteCatalog wasteCatalog) {
        WasteCatalog exist = getById(wasteCatalog.getId());
        if (!exist.getWasteCode().equals(wasteCatalog.getWasteCode())) {
            WasteCatalog codeExist = getByWasteCode(wasteCatalog.getWasteCode(), null);
            if (codeExist != null) {
                throw new BusinessException(ResultCode.WASTE_CODE_EXIST);
            }
        }
        wasteCatalogMapper.updateById(wasteCatalog);
    }

    @Override
    public void delete(Long id) {
        getById(id);
        wasteCatalogMapper.deleteById(id);
    }

    private LambdaQueryWrapper<WasteCatalog> buildQueryWrapper(WasteCatalog wasteCatalog, Long enterpriseId) {
        LambdaQueryWrapper<WasteCatalog> wrapper = new LambdaQueryWrapper<>();
        if (wasteCatalog != null) {
            if (wasteCatalog.getWasteCode() != null && !wasteCatalog.getWasteCode().isEmpty()) {
                wrapper.like(WasteCatalog::getWasteCode, wasteCatalog.getWasteCode());
            }
            if (wasteCatalog.getWasteName() != null && !wasteCatalog.getWasteName().isEmpty()) {
                wrapper.like(WasteCatalog::getWasteName, wasteCatalog.getWasteName());
            }
            if (wasteCatalog.getWasteCategory() != null && !wasteCatalog.getWasteCategory().isEmpty()) {
                wrapper.eq(WasteCatalog::getWasteCategory, wasteCatalog.getWasteCategory());
            }
            if (wasteCatalog.getWasteType() != null && !wasteCatalog.getWasteType().isEmpty()) {
                wrapper.eq(WasteCatalog::getWasteType, wasteCatalog.getWasteType());
            }
            if (wasteCatalog.getStatus() != null) {
                wrapper.eq(WasteCatalog::getStatus, wasteCatalog.getStatus());
            }
        }
        return wrapper;
    }
}
