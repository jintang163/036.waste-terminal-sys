package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.AiCaptureEvent;
import com.waste.mapper.AiCaptureEventMapper;
import com.waste.service.AiCaptureEventService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class AiCaptureEventServiceImpl implements AiCaptureEventService {

    @Autowired
    private AiCaptureEventMapper aiCaptureEventMapper;

    @Override
    public IPage<AiCaptureEvent> page(PageQuery pageQuery, AiCaptureEvent event, Long enterpriseId) {
        Page<AiCaptureEvent> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<AiCaptureEvent> wrapper = buildQueryWrapper(event, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(AiCaptureEvent::getCaptureTime);
        }
        return aiCaptureEventMapper.selectPage(page, wrapper);
    }

    @Override
    public AiCaptureEvent getById(Long id) {
        AiCaptureEvent event = aiCaptureEventMapper.selectById(id);
        if (event == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return event;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(AiCaptureEvent event, Long enterpriseId) {
        if (event.getCaptureTime() == null) {
            event.setCaptureTime(LocalDateTime.now());
        }
        if (StrUtil.isBlank(event.getEventNo())) {
            event.setEventNo("AIE" + System.currentTimeMillis());
        }
        if (event.getHandleStatus() == null) {
            event.setHandleStatus(0);
        }
        if (event.getPushStatus() == null) {
            event.setPushStatus(0);
        }
        if (enterpriseId != null) {
            event.setEnterpriseId(enterpriseId);
        }
        aiCaptureEventMapper.insert(event);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void handleEvent(Long id, String handleRemark, Long userId) {
        AiCaptureEvent event = getById(id);
        if (event.getHandleStatus() != null && event.getHandleStatus() == 1) {
            throw new BusinessException("事件已处理，请勿重复操作");
        }
        event.setHandleStatus(1);
        event.setHandleUserId(userId);
        event.setHandleTime(LocalDateTime.now());
        event.setHandleRemark(handleRemark);
        aiCaptureEventMapper.updateById(event);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void ignoreEvent(Long id, Long userId) {
        AiCaptureEvent event = getById(id);
        if (event.getHandleStatus() != null && event.getHandleStatus() == 1) {
            throw new BusinessException("事件已处理，无法忽略");
        }
        event.setHandleStatus(2);
        event.setHandleUserId(userId);
        event.setHandleTime(LocalDateTime.now());
        event.setHandleRemark("忽略事件");
        aiCaptureEventMapper.updateById(event);
    }

    @Override
    public List<AiCaptureEvent> getUnhandledList(Long enterpriseId) {
        LambdaQueryWrapper<AiCaptureEvent> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiCaptureEvent::getHandleStatus, 0);
        if (enterpriseId != null) {
            wrapper.eq(AiCaptureEvent::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(AiCaptureEvent::getCaptureTime);
        return aiCaptureEventMapper.selectList(wrapper);
    }

    @Override
    public List<AiCaptureEvent> listByEnterpriseId(Long enterpriseId) {
        LambdaQueryWrapper<AiCaptureEvent> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(AiCaptureEvent::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(AiCaptureEvent::getCaptureTime);
        return aiCaptureEventMapper.selectList(wrapper);
    }

    @Override
    public Map<String, Object> getStatistics(Long enterpriseId) {
        Map<String, Object> result = new HashMap<>();

        LambdaQueryWrapper<AiCaptureEvent> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(AiCaptureEvent::getEnterpriseId, enterpriseId);
        }
        List<AiCaptureEvent> allEvents = aiCaptureEventMapper.selectList(wrapper);

        int totalCount = allEvents.size();
        int unhandledCount = 0;
        int handledCount = 0;
        int ignoredCount = 0;

        Map<String, Integer> typeCount = new HashMap<>();
        Map<String, Integer> categoryCount = new HashMap<>();

        for (AiCaptureEvent event : allEvents) {
            if (event.getHandleStatus() == null || event.getHandleStatus() == 0) {
                unhandledCount++;
            } else if (event.getHandleStatus() == 1) {
                handledCount++;
            } else if (event.getHandleStatus() == 2) {
                ignoredCount++;
            }

            if (StrUtil.isNotBlank(event.getEventType())) {
                typeCount.put(event.getEventType(),
                        typeCount.getOrDefault(event.getEventType(), 0) + 1);
            }
            if (StrUtil.isNotBlank(event.getEventCategory())) {
                categoryCount.put(event.getEventCategory(),
                        categoryCount.getOrDefault(event.getEventCategory(), 0) + 1);
            }
        }

        result.put("totalCount", totalCount);
        result.put("unhandledCount", unhandledCount);
        result.put("handledCount", handledCount);
        result.put("ignoredCount", ignoredCount);
        result.put("typeCount", typeCount);
        result.put("categoryCount", categoryCount);

        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchAddFromAi(List<AiCaptureEvent> events) {
        for (AiCaptureEvent event : events) {
            if (event.getCaptureTime() == null) {
                event.setCaptureTime(LocalDateTime.now());
            }
            if (StrUtil.isBlank(event.getEventNo())) {
                event.setEventNo("AIE" + System.currentTimeMillis() + "_" + event.getCameraId());
            }
            if (event.getHandleStatus() == null) {
                event.setHandleStatus(0);
            }
            if (event.getPushStatus() == null) {
                event.setPushStatus(0);
            }
            aiCaptureEventMapper.insert(event);
        }
    }

    private LambdaQueryWrapper<AiCaptureEvent> buildQueryWrapper(AiCaptureEvent event, Long enterpriseId) {
        LambdaQueryWrapper<AiCaptureEvent> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(AiCaptureEvent::getEnterpriseId, enterpriseId);
        }
        if (event != null) {
            if (StrUtil.isNotBlank(event.getEventNo())) {
                wrapper.like(AiCaptureEvent::getEventNo, event.getEventNo());
            }
            if (event.getCameraId() != null) {
                wrapper.eq(AiCaptureEvent::getCameraId, event.getCameraId());
            }
            if (StrUtil.isNotBlank(event.getCameraCode())) {
                wrapper.eq(AiCaptureEvent::getCameraCode, event.getCameraCode());
            }
            if (StrUtil.isNotBlank(event.getEventType())) {
                wrapper.eq(AiCaptureEvent::getEventType, event.getEventType());
            }
            if (StrUtil.isNotBlank(event.getEventCategory())) {
                wrapper.eq(AiCaptureEvent::getEventCategory, event.getEventCategory());
            }
            if (event.getHandleStatus() != null) {
                wrapper.eq(AiCaptureEvent::getHandleStatus, event.getHandleStatus());
            }
        }
        return wrapper;
    }
}
