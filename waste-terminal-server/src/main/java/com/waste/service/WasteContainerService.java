package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.WasteContainer;

import java.util.List;

public interface WasteContainerService {

    IPage<WasteContainer> page(PageQuery pageQuery, WasteContainer wasteContainer, Long enterpriseId);

    WasteContainer getById(Long id);

    WasteContainer getByCode(String containerCode, Long enterpriseId);

    List<WasteContainer> getAvailableList(Long enterpriseId);

    void add(WasteContainer wasteContainer, Long enterpriseId);

    void update(WasteContainer wasteContainer);

    void delete(Long id);

    void updateStatus(Long id, Integer status);
}
