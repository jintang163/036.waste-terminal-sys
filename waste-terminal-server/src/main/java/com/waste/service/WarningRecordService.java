package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.WarningRecord;

import java.util.List;
import java.util.Map;

public interface WarningRecordService {

    IPage<WarningRecord> page(PageQuery pageQuery, WarningRecord warningRecord, Long enterpriseId);

    WarningRecord getById(Long id);

    void add(WarningRecord warningRecord, Long enterpriseId);

    void update(Long id, WarningRecord warningRecord);

    void delete(Long id);

    void handleWarning(Long id, String handleRemark, Long userId);

    void ignoreWarning(Long id, Long userId);

    List<WarningRecord> batchSyncList(Long enterpriseId);

    Map<String, Object> getStatistics(Long enterpriseId);

    List<WarningRecord> getUnhandledList(Long enterpriseId);
}
