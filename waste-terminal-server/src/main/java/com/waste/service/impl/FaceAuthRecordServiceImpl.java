package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.FaceAuthRecord;
import com.waste.mapper.FaceAuthRecordMapper;
import com.waste.service.FaceAuthRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class FaceAuthRecordServiceImpl implements FaceAuthRecordService {

    @Autowired
    private FaceAuthRecordMapper faceAuthRecordMapper;

    @Override
    public IPage<FaceAuthRecord> page(PageQuery pageQuery, FaceAuthRecord record, Long enterpriseId) {
        Page<FaceAuthRecord> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<FaceAuthRecord> wrapper = buildQueryWrapper(record, enterpriseId);
        wrapper.orderByDesc(FaceAuthRecord::getAuthTime);
        return faceAuthRecordMapper.selectPage(page, wrapper);
    }

    @Override
    public FaceAuthRecord getById(Long id) {
        FaceAuthRecord record = faceAuthRecordMapper.selectById(id);
        if (record == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return record;
    }

    @Override
    public FaceAuthRecord getByAuthId(String authId, Long enterpriseId) {
        LambdaQueryWrapper<FaceAuthRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(FaceAuthRecord::getAuthId, authId);
        if (enterpriseId != null) {
            wrapper.eq(FaceAuthRecord::getEnterpriseId, enterpriseId);
        }
        return faceAuthRecordMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(FaceAuthRecord record, Long enterpriseId) {
        if (StrUtil.isBlank(record.getAuthId())) {
            record.setAuthId(UUID.randomUUID().toString().replace("-", ""));
        }
        if (record.getAuthTime() == null) {
            record.setAuthTime(LocalDateTime.now());
        }
        if (enterpriseId != null) {
            record.setEnterpriseId(enterpriseId);
        }
        faceAuthRecordMapper.insert(record);
    }

    @Override
    public List<FaceAuthRecord> listByBusiness(String businessType, String businessId, Long enterpriseId) {
        LambdaQueryWrapper<FaceAuthRecord> wrapper = new LambdaQueryWrapper<>();
        if (StrUtil.isNotBlank(businessType)) {
            wrapper.eq(FaceAuthRecord::getBusinessType, businessType);
        }
        if (StrUtil.isNotBlank(businessId)) {
            wrapper.eq(FaceAuthRecord::getBusinessId, businessId);
        }
        if (enterpriseId != null) {
            wrapper.eq(FaceAuthRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(FaceAuthRecord::getAuthTime);
        return faceAuthRecordMapper.selectList(wrapper);
    }

    @Override
    public List<FaceAuthRecord> listByUserId(Long userId, Long enterpriseId) {
        LambdaQueryWrapper<FaceAuthRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(FaceAuthRecord::getUserId, userId);
        if (enterpriseId != null) {
            wrapper.eq(FaceAuthRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(FaceAuthRecord::getAuthTime);
        return faceAuthRecordMapper.selectList(wrapper);
    }

    private LambdaQueryWrapper<FaceAuthRecord> buildQueryWrapper(FaceAuthRecord record, Long enterpriseId) {
        LambdaQueryWrapper<FaceAuthRecord> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(FaceAuthRecord::getEnterpriseId, enterpriseId);
        }
        if (record != null) {
            if (record.getUserId() != null) {
                wrapper.eq(FaceAuthRecord::getUserId, record.getUserId());
            }
            if (StrUtil.isNotBlank(record.getUsername())) {
                wrapper.like(FaceAuthRecord::getUsername, record.getUsername());
            }
            if (StrUtil.isNotBlank(record.getAuthType())) {
                wrapper.eq(FaceAuthRecord::getAuthType, record.getAuthType());
            }
            if (StrUtil.isNotBlank(record.getBusinessType())) {
                wrapper.eq(FaceAuthRecord::getBusinessType, record.getBusinessType());
            }
            if (StrUtil.isNotBlank(record.getBusinessNo())) {
                wrapper.like(FaceAuthRecord::getBusinessNo, record.getBusinessNo());
            }
            if (record.getAuthStatus() != null) {
                wrapper.eq(FaceAuthRecord::getAuthStatus, record.getAuthStatus());
            }
        }
        return wrapper;
    }
}
