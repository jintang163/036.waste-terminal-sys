package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.Camera;
import com.waste.entity.LocalRecordTask;
import com.waste.mapper.CameraMapper;
import com.waste.mapper.LocalRecordTaskMapper;
import com.waste.service.LocalRecordTaskService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class LocalRecordTaskServiceImpl implements LocalRecordTaskService {

    @Autowired
    private LocalRecordTaskMapper localRecordTaskMapper;

    @Autowired
    private CameraMapper cameraMapper;

    @Override
    public IPage<LocalRecordTask> page(PageQuery pageQuery, LocalRecordTask task, Long enterpriseId) {
        Page<LocalRecordTask> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<LocalRecordTask> wrapper = buildQueryWrapper(task, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(LocalRecordTask::getCreateTime);
        }
        return localRecordTaskMapper.selectPage(page, wrapper);
    }

    @Override
    public LocalRecordTask getById(Long id) {
        LocalRecordTask task = localRecordTaskMapper.selectById(id);
        if (task == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return task;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(LocalRecordTask task, Long enterpriseId) {
        if (StrUtil.isBlank(task.getTaskId())) {
            task.setTaskId(UUID.randomUUID().toString().replace("-", ""));
        }
        if (task.getStatus() == null) {
            task.setStatus(0);
        }
        if (task.getSyncStatus() == null) {
            task.setSyncStatus(0);
        }
        if (enterpriseId != null) {
            task.setEnterpriseId(enterpriseId);
        }
        localRecordTaskMapper.insert(task);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateSyncStatus(Long id, Integer syncStatus) {
        LocalRecordTask task = getById(id);
        task.setSyncStatus(syncStatus);
        if (syncStatus == 1) {
            task.setSyncTime(LocalDateTime.now());
        }
        localRecordTaskMapper.updateById(task);
    }

    @Override
    public List<LocalRecordTask> getUnsyncedList(Long enterpriseId) {
        LambdaQueryWrapper<LocalRecordTask> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(LocalRecordTask::getSyncStatus, 0);
        wrapper.eq(LocalRecordTask::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(LocalRecordTask::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(LocalRecordTask::getCreateTime);
        return localRecordTaskMapper.selectList(wrapper);
    }

    @Override
    public List<LocalRecordTask> listByEnterpriseId(Long enterpriseId) {
        LambdaQueryWrapper<LocalRecordTask> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(LocalRecordTask::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(LocalRecordTask::getCreateTime);
        return localRecordTaskMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchUpdateSyncStatus(List<Long> ids, Integer syncStatus) {
        for (Long id : ids) {
            updateSyncStatus(id, syncStatus);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void createEventRecord(String cameraCode, String triggerType, String triggerId,
                                  Integer preSeconds, Integer postSeconds, Long enterpriseId) {
        Camera camera = null;
        if (StrUtil.isNotBlank(cameraCode)) {
            LambdaQueryWrapper<Camera> camWrapper = new LambdaQueryWrapper<>();
            camWrapper.eq(Camera::getCameraCode, cameraCode);
            if (enterpriseId != null) {
                camWrapper.eq(Camera::getEnterpriseId, enterpriseId);
            }
            camera = cameraMapper.selectOne(camWrapper);
        }

        LocalRecordTask task = new LocalRecordTask();
        task.setTaskId(UUID.randomUUID().toString().replace("-", ""));
        task.setTriggerType(triggerType);
        task.setTriggerId(triggerId);
        task.setPreSeconds(String.valueOf(preSeconds != null ? preSeconds : 10));
        task.setPostSeconds(String.valueOf(postSeconds != null ? postSeconds : 10));
        task.setStatus(0);
        task.setSyncStatus(0);
        task.setEnterpriseId(enterpriseId);

        if (camera != null) {
            task.setCameraId(camera.getId());
            task.setCameraCode(camera.getCameraCode());
            task.setCameraName(camera.getCameraName());
        } else {
            task.setCameraCode(cameraCode);
        }

        localRecordTaskMapper.insert(task);
    }

    private LambdaQueryWrapper<LocalRecordTask> buildQueryWrapper(LocalRecordTask task, Long enterpriseId) {
        LambdaQueryWrapper<LocalRecordTask> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(LocalRecordTask::getEnterpriseId, enterpriseId);
        }
        if (task != null) {
            if (StrUtil.isNotBlank(task.getCameraCode())) {
                wrapper.eq(LocalRecordTask::getCameraCode, task.getCameraCode());
            }
            if (StrUtil.isNotBlank(task.getTriggerType())) {
                wrapper.eq(LocalRecordTask::getTriggerType, task.getTriggerType());
            }
            if (task.getStatus() != null) {
                wrapper.eq(LocalRecordTask::getStatus, task.getStatus());
            }
            if (task.getSyncStatus() != null) {
                wrapper.eq(LocalRecordTask::getSyncStatus, task.getSyncStatus());
            }
            if (StrUtil.isNotBlank(task.getDeviceId())) {
                wrapper.eq(LocalRecordTask::getDeviceId, task.getDeviceId());
            }
        }
        return wrapper;
    }
}
