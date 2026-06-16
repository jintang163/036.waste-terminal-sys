package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.TransportWarningDTO;
import com.waste.entity.TransportWarning;

import java.util.List;

public interface TransportWarningService {

    IPage<TransportWarning> page(PageQuery pageQuery, TransportWarning transportWarning, Long enterpriseId);

    TransportWarning getById(Long id);

    void createWarning(TransportWarningDTO dto, Long enterpriseId);

    void handleWarning(Long id, TransportWarningDTO dto);

    List<TransportWarning> checkTransportTimeout();
}
