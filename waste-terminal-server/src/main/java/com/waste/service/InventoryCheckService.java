package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.InventoryCheckDTO;
import com.waste.entity.InventoryCheck;
import com.waste.entity.InventoryCheckDetail;

import java.util.List;

public interface InventoryCheckService {

    IPage<InventoryCheck> page(PageQuery pageQuery, InventoryCheck inventoryCheck, Long enterpriseId);

    InventoryCheck getById(Long id);

    List<InventoryCheckDetail> getDetailsByCheckId(Long checkId);

    void createCheck(InventoryCheckDTO dto, Long enterpriseId);

    void update(Long id, InventoryCheckDTO dto);

    void delete(Long id);

    void cancel(Long id);

    void addDetail(Long checkId, InventoryCheckDTO.CheckDetailDTO detailDTO);

    void batchSync(List<InventoryCheckDTO> list, Long enterpriseId);

    void completeCheck(Long id);

    void auditCheck(Long id, Integer auditStatus, String auditRemark, Long userId);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    List<InventoryCheck> getPendingSyncList(Long enterpriseId);
}
