package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.EnterpriseInfo;
import com.waste.mapper.EnterpriseInfoMapper;
import com.waste.service.EnterpriseInfoService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class EnterpriseInfoServiceImpl implements EnterpriseInfoService {

    @Autowired
    private EnterpriseInfoMapper enterpriseInfoMapper;

    @Override
    public EnterpriseInfo getById(Long id) {
        EnterpriseInfo enterprise = enterpriseInfoMapper.selectById(id);
        if (enterprise == null) {
            throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND);
        }
        return enterprise;
    }

    @Override
    public List<EnterpriseInfo> list(String enterpriseType, Long enterpriseId) {
        LambdaQueryWrapper<EnterpriseInfo> wrapper = new LambdaQueryWrapper<>();
        if (StrUtil.isNotBlank(enterpriseType)) {
            wrapper.eq(EnterpriseInfo::getStatus, 1);
        }
        wrapper.orderByAsc(EnterpriseInfo::getEnterpriseName);
        return enterpriseInfoMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(EnterpriseInfo enterpriseInfo) {
        EnterpriseInfo exist = getById(enterpriseInfo.getId());
        exist.setEnterpriseName(enterpriseInfo.getEnterpriseName());
        exist.setEnterpriseCode(enterpriseInfo.getEnterpriseCode());
        exist.setLegalPerson(enterpriseInfo.getLegalPerson());
        exist.setContactPerson(enterpriseInfo.getContactPerson());
        exist.setContactPhone(enterpriseInfo.getContactPhone());
        exist.setAddress(enterpriseInfo.getAddress());
        exist.setProvince(enterpriseInfo.getProvince());
        exist.setCity(enterpriseInfo.getCity());
        exist.setDistrict(enterpriseInfo.getDistrict());
        exist.setBusinessLicense(enterpriseInfo.getBusinessLicense());
        exist.setWasteLicense(enterpriseInfo.getWasteLicense());
        exist.setLicenseExpireDate(enterpriseInfo.getLicenseExpireDate());
        exist.setStorageCapacity(enterpriseInfo.getStorageCapacity());
        enterpriseInfoMapper.updateById(exist);
    }
}
