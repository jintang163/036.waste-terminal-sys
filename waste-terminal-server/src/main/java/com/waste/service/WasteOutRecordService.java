package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.WasteOutRecordDTO;
import com.waste.entity.WasteOutRecord;

import java.util.List;

public interface WasteOutRecordService {

    IPage<WasteOutRecord> page(PageQuery pageQuery, WasteOutRecord wasteOutRecord, Long enterpriseId);

    WasteOutRecord getById(Long id);

    void add(WasteOutRecordDTO dto, Long enterpriseId);

    void update(Long id, WasteOutRecordDTO dto);

    void delete(Long id);

    void batchSync(List<WasteOutRecordDTO> list, Long enterpriseId);

    void confirm(Long id);

    void sign(Long id, String signPhoto, String receiptPhoto);

    void cancel(Long id);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    List<WasteOutRecord> getPendingSyncList(Long enterpriseId);

    WasteOutRecord addWasteOutRecord(WasteOutRecordDTO dto);

    List<WasteOutRecord> queryList(WasteOutRecord wasteOutRecord, Long enterpriseId);

    IPage<WasteOutRecord> queryPage(PageQuery pageQuery, WasteOutRecord wasteOutRecord, Long enterpriseId);

    Map<String, Object> checkDoubleReviewRequired(Long wasteId);
}
