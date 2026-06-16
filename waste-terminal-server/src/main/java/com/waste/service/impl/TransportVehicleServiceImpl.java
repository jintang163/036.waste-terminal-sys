package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.TransportVehicleDTO;
import com.waste.entity.TransportVehicle;
import com.waste.mapper.TransportVehicleMapper;
import com.waste.service.TransportVehicleService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class TransportVehicleServiceImpl implements TransportVehicleService {

    @Autowired
    private TransportVehicleMapper transportVehicleMapper;

    @Override
    public IPage<TransportVehicle> page(PageQuery pageQuery, TransportVehicle transportVehicle, Long enterpriseId) {
        Page<TransportVehicle> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<TransportVehicle> wrapper = buildQueryWrapper(transportVehicle, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(TransportVehicle::getCreateTime);
        }
        return transportVehicleMapper.selectPage(page, wrapper);
    }

    @Override
    public TransportVehicle getById(Long id) {
        TransportVehicle vehicle = transportVehicleMapper.selectById(id);
        if (vehicle == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return vehicle;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(TransportVehicleDTO dto, Long enterpriseId) {
        TransportVehicle vehicle = new TransportVehicle();
        BeanUtils.copyProperties(dto, vehicle);
        if (enterpriseId != null) {
            vehicle.setEnterpriseId(enterpriseId);
        }
        transportVehicleMapper.insert(vehicle);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, TransportVehicleDTO dto) {
        TransportVehicle vehicle = getById(id);
        if (dto.getVehicleNo() != null) {
            vehicle.setVehicleNo(dto.getVehicleNo());
        }
        if (dto.getVehicleType() != null) {
            vehicle.setVehicleType(dto.getVehicleType());
        }
        if (dto.getVehicleModel() != null) {
            vehicle.setVehicleModel(dto.getVehicleModel());
        }
        if (dto.getLoadWeight() != null) {
            vehicle.setLoadWeight(dto.getLoadWeight());
        }
        if (dto.getLoadVolume() != null) {
            vehicle.setLoadVolume(dto.getLoadVolume());
        }
        if (dto.getOwnerUnit() != null) {
            vehicle.setOwnerUnit(dto.getOwnerUnit());
        }
        if (dto.getOwnerUnitId() != null) {
            vehicle.setOwnerUnitId(dto.getOwnerUnitId());
        }
        if (dto.getDriverId() != null) {
            vehicle.setDriverId(dto.getDriverId());
        }
        if (dto.getDriverName() != null) {
            vehicle.setDriverName(dto.getDriverName());
        }
        if (dto.getLicensePlateColor() != null) {
            vehicle.setLicensePlateColor(dto.getLicensePlateColor());
        }
        if (dto.getRoadTransportLicense() != null) {
            vehicle.setRoadTransportLicense(dto.getRoadTransportLicense());
        }
        if (dto.getRoadTransportLicenseExpire() != null) {
            vehicle.setRoadTransportLicenseExpire(dto.getRoadTransportLicenseExpire());
        }
        if (dto.getVehicleLicenseExpire() != null) {
            vehicle.setVehicleLicenseExpire(dto.getVehicleLicenseExpire());
        }
        if (dto.getInsuranceExpire() != null) {
            vehicle.setInsuranceExpire(dto.getInsuranceExpire());
        }
        if (dto.getInspectionExpire() != null) {
            vehicle.setInspectionExpire(dto.getInspectionExpire());
        }
        if (dto.getGpsTerminalId() != null) {
            vehicle.setGpsTerminalId(dto.getGpsTerminalId());
        }
        if (dto.getGpsSimNo() != null) {
            vehicle.setGpsSimNo(dto.getGpsSimNo());
        }
        if (dto.getIsTrackEnabled() != null) {
            vehicle.setIsTrackEnabled(dto.getIsTrackEnabled());
        }
        if (dto.getAmapServiceId() != null) {
            vehicle.setAmapServiceId(dto.getAmapServiceId());
        }
        if (dto.getAmapTerminalId() != null) {
            vehicle.setAmapTerminalId(dto.getAmapTerminalId());
        }
        if (dto.getAmapTrackName() != null) {
            vehicle.setAmapTrackName(dto.getAmapTrackName());
        }
        if (dto.getStatus() != null) {
            vehicle.setStatus(dto.getStatus());
        }
        if (dto.getRemark() != null) {
            vehicle.setRemark(dto.getRemark());
        }
        transportVehicleMapper.updateById(vehicle);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        TransportVehicle vehicle = getById(id);
        transportVehicleMapper.deleteById(id);
    }

    @Override
    public List<TransportVehicle> listForCache(Long enterpriseId) {
        LambdaQueryWrapper<TransportVehicle> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportVehicle::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(TransportVehicle::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(TransportVehicle::getVehicleNo);
        return transportVehicleMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<TransportVehicleDTO> list, Long enterpriseId) {
        if (CollUtil.isEmpty(list)) {
            throw new BusinessException(ResultCode.SYNC_DATA_EMPTY);
        }

        for (TransportVehicleDTO dto : list) {
            try {
                if (dto.getId() != null) {
                    TransportVehicle existVehicle = transportVehicleMapper.selectById(dto.getId());
                    if (existVehicle != null) {
                        update(dto.getId(), dto);
                        continue;
                    }
                }
                add(dto, enterpriseId);
            } catch (Exception e) {
                log.error("同步车辆数据失败, vehicleNo={}", dto.getVehicleNo(), e);
            }
        }
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<TransportVehicle> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportVehicle::getGpsTerminalId, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(TransportVehicle::getEnterpriseId, enterpriseId);
        }
        Long count = transportVehicleMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    public List<TransportVehicle> queryList(TransportVehicle transportVehicle, Long enterpriseId) {
        LambdaQueryWrapper<TransportVehicle> wrapper = buildQueryWrapper(transportVehicle, enterpriseId);
        wrapper.orderByDesc(TransportVehicle::getCreateTime);
        return transportVehicleMapper.selectList(wrapper);
    }

    private LambdaQueryWrapper<TransportVehicle> buildQueryWrapper(TransportVehicle transportVehicle, Long enterpriseId) {
        LambdaQueryWrapper<TransportVehicle> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(TransportVehicle::getEnterpriseId, enterpriseId);
        }
        if (transportVehicle != null) {
            if (StrUtil.isNotBlank(transportVehicle.getVehicleNo())) {
                wrapper.like(TransportVehicle::getVehicleNo, transportVehicle.getVehicleNo());
            }
            if (StrUtil.isNotBlank(transportVehicle.getVehicleType())) {
                wrapper.eq(TransportVehicle::getVehicleType, transportVehicle.getVehicleType());
            }
            if (StrUtil.isNotBlank(transportVehicle.getDriverName())) {
                wrapper.like(TransportVehicle::getDriverName, transportVehicle.getDriverName());
            }
            if (StrUtil.isNotBlank(transportVehicle.getGpsTerminalId())) {
                wrapper.eq(TransportVehicle::getGpsTerminalId, transportVehicle.getGpsTerminalId());
            }
            if (transportVehicle.getStatus() != null) {
                wrapper.eq(TransportVehicle::getStatus, transportVehicle.getStatus());
            }
            if (transportVehicle.getIsTrackEnabled() != null) {
                wrapper.eq(TransportVehicle::getIsTrackEnabled, transportVehicle.getIsTrackEnabled());
            }
        }
        return wrapper;
    }
}
