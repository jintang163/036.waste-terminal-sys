package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.FaceAuthRecord;

import java.util.List;

public interface FaceAuthRecordService {

    IPage<FaceAuthRecord> page(PageQuery pageQuery, FaceAuthRecord record, Long enterpriseId);

    FaceAuthRecord getById(Long id);

    FaceAuthRecord getByAuthId(String authId, Long enterpriseId);

    void add(FaceAuthRecord record, Long enterpriseId);

    List<FaceAuthRecord> listByBusiness(String businessType, String businessId, Long enterpriseId);

    List<FaceAuthRecord> listByUserId(Long userId, Long enterpriseId);
}
