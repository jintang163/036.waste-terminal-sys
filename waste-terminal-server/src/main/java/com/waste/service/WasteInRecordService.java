package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.WasteInRecordDTO;
import com.waste.entity.WasteInRecord;

import java.util.List;
import java.util.Map;

public interface WasteInRecordService {

    IPage<WasteInRecord> page(PageQuery pageQuery, WasteInRecord wasteInRecord, Long enterpriseId);

    WasteInRecord getById(Long id);

    void add(WasteInRecordDTO dto, Long enterpriseId);

    void update(Long id, WasteInRecordDTO dto);

    void delete(Long id);

    void batchSync(List<WasteInRecordDTO> list, Long enterpriseId);

    void confirm(Long id);

    void cancel(Long id);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    List<WasteInRecord> getPendingSyncList(Long enterpriseId);

    WasteInRecord addWasteInRecord(WasteInRecordDTO dto);

    Map<String, Integer> batchAddWasteInRecord(List<WasteInRecordDTO> dtoList);

    List<WasteInRecord> queryList(WasteInRecord wasteInRecord, Long enterpriseId);

    IPage<WasteInRecord> queryPage(PageQuery pageQuery, WasteInRecord wasteInRecord, Long enterpriseId);
}
