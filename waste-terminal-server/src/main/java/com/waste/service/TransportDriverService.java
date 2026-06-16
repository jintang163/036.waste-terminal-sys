package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.TransportDriverDTO;
import com.waste.entity.TransportDriver;

import java.util.List;

public interface TransportDriverService {

    IPage<TransportDriver> page(PageQuery pageQuery, TransportDriver transportDriver, Long enterpriseId);

    TransportDriver getById(Long id);

    void add(TransportDriverDTO dto, Long enterpriseId);

    void update(Long id, TransportDriverDTO dto);

    void delete(Long id);

    List<TransportDriver> listForCache(Long enterpriseId);

    void batchSync(List<TransportDriverDTO> list, Long enterpriseId);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    List<TransportDriver> queryList(TransportDriver transportDriver, Long enterpriseId);
}
