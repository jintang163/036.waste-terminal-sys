package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.LocalRecordTask;

import java.util.List;

public interface LocalRecordTaskService {

    IPage<LocalRecordTask> page(PageQuery pageQuery, LocalRecordTask task, Long enterpriseId);

    LocalRecordTask getById(Long id);

    void add(LocalRecordTask task, Long enterpriseId);

    void updateSyncStatus(Long id, Integer syncStatus);

    List<LocalRecordTask> getUnsyncedList(Long enterpriseId);

    List<LocalRecordTask> listByEnterpriseId(Long enterpriseId);

    void batchUpdateSyncStatus(List<Long> ids, Integer syncStatus);

    void createEventRecord(String cameraCode, String triggerType, String triggerId,
                           Integer preSeconds, Integer postSeconds, Long enterpriseId);
}
