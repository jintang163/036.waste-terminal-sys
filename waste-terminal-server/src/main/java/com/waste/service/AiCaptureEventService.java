package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.AiCaptureEvent;

import java.util.List;
import java.util.Map;

public interface AiCaptureEventService {

    IPage<AiCaptureEvent> page(PageQuery pageQuery, AiCaptureEvent event, Long enterpriseId);

    AiCaptureEvent getById(Long id);

    void add(AiCaptureEvent event, Long enterpriseId);

    void handleEvent(Long id, String handleRemark, Long userId);

    void ignoreEvent(Long id, Long userId);

    List<AiCaptureEvent> getUnhandledList(Long enterpriseId);

    List<AiCaptureEvent> listByEnterpriseId(Long enterpriseId);

    Map<String, Object> getStatistics(Long enterpriseId);

    void batchAddFromAi(List<AiCaptureEvent> events);
}
