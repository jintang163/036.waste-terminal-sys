package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.WarningRecord;
import com.waste.mapper.WarningRecordMapper;
import com.waste.service.WarningRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class WarningRecordServiceImpl implements WarningRecordService {

    @Autowired
    private WarningRecordMapper warningRecordMapper;

    @Override
    public IPage<WarningRecord> page(PageQuery pageQuery, WarningRecord warningRecord, Long enterpriseId) {
        Page<WarningRecord> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WarningRecord> wrapper = buildQueryWrapper(warningRecord, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WarningRecord::getTriggerTime);
        }
        return warningRecordMapper.selectPage(page, wrapper);
    }

    @Override
    public WarningRecord getById(Long id) {
        WarningRecord record = warningRecordMapper.selectById(id);
        if (record == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return record;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(WarningRecord warningRecord, Long enterpriseId) {
        if (warningRecord.getTriggerTime() == null) {
            warningRecord.setTriggerTime(LocalDateTime.now());
        }
        if (warningRecord.getHandleStatus() == null) {
            warningRecord.setHandleStatus(0);
        }
        if (warningRecord.getPushStatus() == null) {
            warningRecord.setPushStatus(0);
        }
        if (StrUtil.isBlank(warningRecord.getWarningNo())) {
            warningRecord.setWarningNo("WRN" + System.currentTimeMillis());
        }
        if (enterpriseId != null) {
            warningRecord.setEnterpriseId(enterpriseId);
        }
        warningRecordMapper.insert(warningRecord);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, WarningRecord warningRecord) {
        WarningRecord exist = getById(id);

        if (warningRecord.getWarningType() != null) {
            exist.setWarningType(warningRecord.getWarningType());
        }
        if (warningRecord.getWarningLevel() != null) {
            exist.setWarningLevel(warningRecord.getWarningLevel());
        }
        if (warningRecord.getWasteCode() != null) {
            exist.setWasteCode(warningRecord.getWasteCode());
        }
        if (warningRecord.getWasteName() != null) {
            exist.setWasteName(warningRecord.getWasteName());
        }
        if (warningRecord.getContainerId() != null) {
            exist.setContainerId(warningRecord.getContainerId());
        }
        if (warningRecord.getContainerCode() != null) {
            exist.setContainerCode(warningRecord.getContainerCode());
        }
        if (warningRecord.getWarningContent() != null) {
            exist.setWarningContent(warningRecord.getWarningContent());
        }

        warningRecordMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        WarningRecord exist = getById(id);
        if (exist.getHandleStatus() != null && exist.getHandleStatus() == 0) {
            throw new BusinessException("预警未处理，无法删除");
        }
        warningRecordMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void handleWarning(Long id, String handleRemark, Long userId) {
        WarningRecord record = getById(id);
        if (record.getHandleStatus() == 1) {
            throw new BusinessException("预警已处理，请勿重复操作");
        }
        if (record.getHandleStatus() == 2) {
            throw new BusinessException("预警已忽略，无法处理");
        }

        record.setHandleStatus(1);
        record.setHandleUserId(userId);
        record.setHandleTime(LocalDateTime.now());
        record.setHandleRemark(handleRemark);
        warningRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void ignoreWarning(Long id, Long userId) {
        WarningRecord record = getById(id);
        if (record.getHandleStatus() == 1) {
            throw new BusinessException("预警已处理，无法忽略");
        }
        if (record.getHandleStatus() == 2) {
            throw new BusinessException("预警已忽略，请勿重复操作");
        }

        record.setHandleStatus(2);
        record.setHandleUserId(userId);
        record.setHandleTime(LocalDateTime.now());
        record.setHandleRemark("忽略预警");
        warningRecordMapper.updateById(record);
    }

    @Override
    public List<WarningRecord> batchSyncList(Long enterpriseId) {
        LambdaQueryWrapper<WarningRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WarningRecord::getHandleStatus, 0);
        if (enterpriseId != null) {
            wrapper.eq(WarningRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(WarningRecord::getTriggerTime);
        return warningRecordMapper.selectList(wrapper);
    }

    @Override
    public Map<String, Object> getStatistics(Long enterpriseId) {
        Map<String, Object> result = new HashMap<>();

        LambdaQueryWrapper<WarningRecord> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WarningRecord::getEnterpriseId, enterpriseId);
        }
        List<WarningRecord> allRecords = warningRecordMapper.selectList(wrapper);

        int totalCount = allRecords.size();
        int unhandledCount = 0;
        int handledCount = 0;
        int ignoredCount = 0;

        Map<String, Integer> typeCount = new HashMap<>();
        Map<Integer, Integer> levelCount = new HashMap<>();

        for (WarningRecord record : allRecords) {
            if (record.getHandleStatus() == null || record.getHandleStatus() == 0) {
                unhandledCount++;
            } else if (record.getHandleStatus() == 1) {
                handledCount++;
            } else if (record.getHandleStatus() == 2) {
                ignoredCount++;
            }

            if (StrUtil.isNotBlank(record.getWarningType())) {
                typeCount.put(record.getWarningType(),
                        typeCount.getOrDefault(record.getWarningType(), 0) + 1);
            }

            if (record.getWarningLevel() != null) {
                levelCount.put(record.getWarningLevel(),
                        levelCount.getOrDefault(record.getWarningLevel(), 0) + 1);
            }
        }

        result.put("totalCount", totalCount);
        result.put("unhandledCount", unhandledCount);
        result.put("handledCount", handledCount);
        result.put("ignoredCount", ignoredCount);
        result.put("typeCount", typeCount);
        result.put("levelCount", levelCount);

        return result;
    }

    @Override
    public List<WarningRecord> getUnhandledList(Long enterpriseId) {
        LambdaQueryWrapper<WarningRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WarningRecord::getHandleStatus, 0);
        if (enterpriseId != null) {
            wrapper.eq(WarningRecord::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(WarningRecord::getWarningLevel);
        wrapper.orderByDesc(WarningRecord::getTriggerTime);
        return warningRecordMapper.selectList(wrapper);
    }

    private LambdaQueryWrapper<WarningRecord> buildQueryWrapper(WarningRecord warningRecord, Long enterpriseId) {
        LambdaQueryWrapper<WarningRecord> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(WarningRecord::getEnterpriseId, enterpriseId);
        }
        if (warningRecord != null) {
            if (StrUtil.isNotBlank(warningRecord.getWarningNo())) {
                wrapper.like(WarningRecord::getWarningNo, warningRecord.getWarningNo());
            }
            if (StrUtil.isNotBlank(warningRecord.getWarningType())) {
                wrapper.eq(WarningRecord::getWarningType, warningRecord.getWarningType());
            }
            if (warningRecord.getWarningLevel() != null) {
                wrapper.eq(WarningRecord::getWarningLevel, warningRecord.getWarningLevel());
            }
            if (StrUtil.isNotBlank(warningRecord.getWasteCode())) {
                wrapper.like(WarningRecord::getWasteCode, warningRecord.getWasteCode());
            }
            if (StrUtil.isNotBlank(warningRecord.getWasteName())) {
                wrapper.like(WarningRecord::getWasteName, warningRecord.getWasteName());
            }
            if (StrUtil.isNotBlank(warningRecord.getContainerCode())) {
                wrapper.like(WarningRecord::getContainerCode, warningRecord.getContainerCode());
            }
            if (warningRecord.getHandleStatus() != null) {
                wrapper.eq(WarningRecord::getHandleStatus, warningRecord.getHandleStatus());
            }
            if (warningRecord.getPushStatus() != null) {
                wrapper.eq(WarningRecord::getPushStatus, warningRecord.getPushStatus());
            }
        }
        return wrapper;
    }
}
