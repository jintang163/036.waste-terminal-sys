package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.TransportDriverDTO;
import com.waste.entity.TransportDriver;
import com.waste.mapper.TransportDriverMapper;
import com.waste.service.TransportDriverService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
public class TransportDriverServiceImpl implements TransportDriverService {

    @Autowired
    private TransportDriverMapper transportDriverMapper;

    @Override
    public IPage<TransportDriver> page(PageQuery pageQuery, TransportDriver transportDriver, Long enterpriseId) {
        Page<TransportDriver> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<TransportDriver> wrapper = buildQueryWrapper(transportDriver, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(TransportDriver::getCreateTime);
        }
        return transportDriverMapper.selectPage(page, wrapper);
    }

    @Override
    public TransportDriver getById(Long id) {
        TransportDriver driver = transportDriverMapper.selectById(id);
        if (driver == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return driver;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(TransportDriverDTO dto, Long enterpriseId) {
        TransportDriver driver = new TransportDriver();
        BeanUtils.copyProperties(dto, driver);
        if (enterpriseId != null) {
            driver.setEnterpriseId(enterpriseId);
        }
        transportDriverMapper.insert(driver);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, TransportDriverDTO dto) {
        TransportDriver driver = getById(id);
        if (dto.getDriverName() != null) {
            driver.setDriverName(dto.getDriverName());
        }
        if (dto.getGender() != null) {
            driver.setGender(dto.getGender());
        }
        if (dto.getPhone() != null) {
            driver.setPhone(dto.getPhone());
        }
        if (dto.getIdCard() != null) {
            driver.setIdCard(dto.getIdCard());
        }
        if (dto.getDriverLicense() != null) {
            driver.setDriverLicense(dto.getDriverLicense());
        }
        if (dto.getDriverLicenseType() != null) {
            driver.setDriverLicenseType(dto.getDriverLicenseType());
        }
        if (dto.getDriverLicenseExpire() != null) {
            driver.setDriverLicenseExpire(dto.getDriverLicenseExpire());
        }
        if (dto.getQualificationCert() != null) {
            driver.setQualificationCert(dto.getQualificationCert());
        }
        if (dto.getQualificationCertExpire() != null) {
            driver.setQualificationCertExpire(dto.getQualificationCertExpire());
        }
        if (dto.getHazardousCert() != null) {
            driver.setHazardousCert(dto.getHazardousCert());
        }
        if (dto.getHazardousCertExpire() != null) {
            driver.setHazardousCertExpire(dto.getHazardousCertExpire());
        }
        if (dto.getEscortCert() != null) {
            driver.setEscortCert(dto.getEscortCert());
        }
        if (dto.getEscortCertExpire() != null) {
            driver.setEscortCertExpire(dto.getEscortCertExpire());
        }
        if (dto.getWorkYears() != null) {
            driver.setWorkYears(dto.getWorkYears());
        }
        if (dto.getVehicleId() != null) {
            driver.setVehicleId(dto.getVehicleId());
        }
        if (dto.getVehicleNo() != null) {
            driver.setVehicleNo(dto.getVehicleNo());
        }
        if (dto.getEmergencyContact() != null) {
            driver.setEmergencyContact(dto.getEmergencyContact());
        }
        if (dto.getEmergencyPhone() != null) {
            driver.setEmergencyPhone(dto.getEmergencyPhone());
        }
        if (dto.getPhotoUrl() != null) {
            driver.setPhotoUrl(dto.getPhotoUrl());
        }
        if (dto.getStatus() != null) {
            driver.setStatus(dto.getStatus());
        }
        if (dto.getRemark() != null) {
            driver.setRemark(dto.getRemark());
        }
        transportDriverMapper.updateById(driver);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        TransportDriver driver = getById(id);
        transportDriverMapper.deleteById(id);
    }

    @Override
    public List<TransportDriver> listForCache(Long enterpriseId) {
        LambdaQueryWrapper<TransportDriver> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportDriver::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(TransportDriver::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(TransportDriver::getDriverName);
        return transportDriverMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<TransportDriverDTO> list, Long enterpriseId) {
        if (CollUtil.isEmpty(list)) {
            throw new BusinessException(ResultCode.SYNC_DATA_EMPTY);
        }

        for (TransportDriverDTO dto : list) {
            try {
                if (dto.getId() != null) {
                    TransportDriver existDriver = transportDriverMapper.selectById(dto.getId());
                    if (existDriver != null) {
                        update(dto.getId(), dto);
                        continue;
                    }
                }
                add(dto, enterpriseId);
            } catch (Exception e) {
                log.error("同步驾驶员数据失败, driverName={}", dto.getDriverName(), e);
            }
        }
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<TransportDriver> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportDriver::getIdCard, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(TransportDriver::getEnterpriseId, enterpriseId);
        }
        Long count = transportDriverMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    public List<TransportDriver> queryList(TransportDriver transportDriver, Long enterpriseId) {
        LambdaQueryWrapper<TransportDriver> wrapper = buildQueryWrapper(transportDriver, enterpriseId);
        wrapper.orderByDesc(TransportDriver::getCreateTime);
        return transportDriverMapper.selectList(wrapper);
    }

    private LambdaQueryWrapper<TransportDriver> buildQueryWrapper(TransportDriver transportDriver, Long enterpriseId) {
        LambdaQueryWrapper<TransportDriver> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(TransportDriver::getEnterpriseId, enterpriseId);
        }
        if (transportDriver != null) {
            if (StrUtil.isNotBlank(transportDriver.getDriverName())) {
                wrapper.like(TransportDriver::getDriverName, transportDriver.getDriverName());
            }
            if (StrUtil.isNotBlank(transportDriver.getPhone())) {
                wrapper.like(TransportDriver::getPhone, transportDriver.getPhone());
            }
            if (StrUtil.isNotBlank(transportDriver.getIdCard())) {
                wrapper.eq(TransportDriver::getIdCard, transportDriver.getIdCard());
            }
            if (StrUtil.isNotBlank(transportDriver.getVehicleNo())) {
                wrapper.eq(TransportDriver::getVehicleNo, transportDriver.getVehicleNo());
            }
            if (transportDriver.getStatus() != null) {
                wrapper.eq(TransportDriver::getStatus, transportDriver.getStatus());
            }
        }
        return wrapper;
    }
}
