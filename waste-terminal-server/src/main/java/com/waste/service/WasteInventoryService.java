package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.WasteInventory;
import com.waste.vo.WasteInventoryVO;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public interface WasteInventoryService {

    IPage<WasteInventoryVO> page(PageQuery pageQuery, WasteInventory wasteInventory, Long enterpriseId);

    WasteInventory getById(Long id);

    void add(WasteInventory wasteInventory, Long enterpriseId);

    void update(Long id, WasteInventory wasteInventory);

    void delete(Long id);

    WasteInventory getByContainerCode(String containerCode, Long enterpriseId);

    List<Map<String, Object>> statByWasteCode(Long enterpriseId);

    Map<String, Object> getStatistics(Long enterpriseId);

    BigDecimal getCapacityRate(Long enterpriseId);

    List<WasteInventory> listForCache(Long enterpriseId);

    Map<String, Object> getHomeDashboard(Long enterpriseId);
}
