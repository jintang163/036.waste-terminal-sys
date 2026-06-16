package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.OperationLog;

import java.util.List;
import java.util.Map;

public interface OperationLogService {

    IPage<OperationLog> page(PageQuery pageQuery, OperationLog log, Long enterpriseId);

    OperationLog getById(Long id);

    void add(OperationLog log);

    Map<String, Object> batchUpload(List<Map<String, Object>> logDataList);
}
