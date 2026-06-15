package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.Camera;
import com.waste.mapper.CameraMapper;
import com.waste.service.CameraService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class CameraServiceImpl implements CameraService {

    @Autowired
    private CameraMapper cameraMapper;

    @Override
    public IPage<Camera> page(PageQuery pageQuery, Camera camera, Long enterpriseId) {
        Page<Camera> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<Camera> wrapper = buildQueryWrapper(camera, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(Camera::getCreateTime);
        }
        return cameraMapper.selectPage(page, wrapper);
    }

    @Override
    public Camera getById(Long id) {
        Camera camera = cameraMapper.selectById(id);
        if (camera == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return camera;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(Camera camera, Long enterpriseId) {
        if (StrUtil.isBlank(camera.getCameraCode())) {
            camera.setCameraCode("CAM" + System.currentTimeMillis());
        }
        if (camera.getStatus() == null) {
            camera.setStatus(1);
        }
        if (camera.getAiEnabled() == null) {
            camera.setAiEnabled(false);
        }
        if (camera.getStreamType() == null) {
            camera.setStreamType(0);
        }
        if (enterpriseId != null) {
            camera.setEnterpriseId(enterpriseId);
        }

        LambdaQueryWrapper<Camera> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(Camera::getCameraCode, camera.getCameraCode());
        if (enterpriseId != null) {
            existWrapper.eq(Camera::getEnterpriseId, enterpriseId);
        }
        if (cameraMapper.selectCount(existWrapper) > 0) {
            throw new BusinessException("摄像头编码已存在");
        }

        cameraMapper.insert(camera);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, Camera camera) {
        Camera exist = getById(id);

        if (camera.getCameraName() != null) {
            exist.setCameraName(camera.getCameraName());
        }
        if (camera.getCameraType() != null) {
            exist.setCameraType(camera.getCameraType());
        }
        if (camera.getBrand() != null) {
            exist.setBrand(camera.getBrand());
        }
        if (camera.getRtspUrl() != null) {
            exist.setRtspUrl(camera.getRtspUrl());
        }
        if (camera.getHttpUrl() != null) {
            exist.setHttpUrl(camera.getHttpUrl());
        }
        if (camera.getLocation() != null) {
            exist.setLocation(camera.getLocation());
        }
        if (camera.getWarehouseCode() != null) {
            exist.setWarehouseCode(camera.getWarehouseCode());
        }
        if (camera.getResolution() != null) {
            exist.setResolution(camera.getResolution());
        }
        if (camera.getStreamType() != null) {
            exist.setStreamType(camera.getStreamType());
        }
        if (camera.getUsername() != null) {
            exist.setUsername(camera.getUsername());
        }
        if (camera.getPassword() != null) {
            exist.setPassword(camera.getPassword());
        }
        if (camera.getSnapshotUrl() != null) {
            exist.setSnapshotUrl(camera.getSnapshotUrl());
        }

        cameraMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        Camera exist = getById(id);
        if (exist.getAiEnabled() != null && exist.getAiEnabled()) {
            throw new BusinessException("摄像头已启用AI检测，请先关闭后再删除");
        }
        cameraMapper.deleteById(id);
    }

    @Override
    public List<Camera> listByEnterpriseId(Long enterpriseId) {
        LambdaQueryWrapper<Camera> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(Camera::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(Camera::getCameraCode);
        return cameraMapper.selectList(wrapper);
    }

    @Override
    public Camera getByCode(String cameraCode, Long enterpriseId) {
        LambdaQueryWrapper<Camera> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Camera::getCameraCode, cameraCode);
        if (enterpriseId != null) {
            wrapper.eq(Camera::getEnterpriseId, enterpriseId);
        }
        return cameraMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateStatus(Long id, Integer status) {
        Camera exist = getById(id);
        exist.setStatus(status);
        cameraMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void toggleAi(Long id, Boolean enabled) {
        Camera exist = getById(id);
        exist.setAiEnabled(enabled);
        cameraMapper.updateById(exist);
    }

    private LambdaQueryWrapper<Camera> buildQueryWrapper(Camera camera, Long enterpriseId) {
        LambdaQueryWrapper<Camera> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(Camera::getEnterpriseId, enterpriseId);
        }
        if (camera != null) {
            if (StrUtil.isNotBlank(camera.getCameraCode())) {
                wrapper.like(Camera::getCameraCode, camera.getCameraCode());
            }
            if (StrUtil.isNotBlank(camera.getCameraName())) {
                wrapper.like(Camera::getCameraName, camera.getCameraName());
            }
            if (StrUtil.isNotBlank(camera.getCameraType())) {
                wrapper.eq(Camera::getCameraType, camera.getCameraType());
            }
            if (StrUtil.isNotBlank(camera.getBrand())) {
                wrapper.eq(Camera::getBrand, camera.getBrand());
            }
            if (camera.getStatus() != null) {
                wrapper.eq(Camera::getStatus, camera.getStatus());
            }
            if (camera.getAiEnabled() != null) {
                wrapper.eq(Camera::getAiEnabled, camera.getAiEnabled());
            }
            if (StrUtil.isNotBlank(camera.getLocation())) {
                wrapper.like(Camera::getLocation, camera.getLocation());
            }
            if (StrUtil.isNotBlank(camera.getWarehouseCode())) {
                wrapper.eq(Camera::getWarehouseCode, camera.getWarehouseCode());
            }
        }
        return wrapper;
    }
}
