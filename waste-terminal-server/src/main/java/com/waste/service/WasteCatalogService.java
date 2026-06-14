package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.WasteCatalog;

import java.util.List;

public interface WasteCatalogService {

    IPage<WasteCatalog> page(PageQuery pageQuery, WasteCatalog wasteCatalog, Long enterpriseId);

    WasteCatalog getById(Long id);

    WasteCatalog getByWasteCode(String wasteCode, Long enterpriseId);

    List<WasteCatalog> listAll(Long enterpriseId);

    void add(WasteCatalog wasteCatalog, Long enterpriseId);

    void update(WasteCatalog wasteCatalog);

    void delete(Long id);
}
