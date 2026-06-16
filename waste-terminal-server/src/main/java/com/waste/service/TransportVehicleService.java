package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.TransportVehicleDTO;
import com.waste.entity.TransportVehicle;

import java.util.List;

public interface TransportVehicleService {

    IPage<TransportVehicle> page(PageQuery pageQuery, TransportVehicle transportVehicle, Long enterpriseId);

    TransportVehicle getById(Long id);

    void add(TransportVehicleDTO dto, Long enterpriseId);

    void update(Long id, TransportVehicleDTO dto);

    void delete(Long id);

    List<TransportVehicle> listForCache(Long enterpriseId);

    void batchSync(List<TransportVehicleDTO> list, Long enterpriseId);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    List<TransportVehicle> queryList(TransportVehicle transportVehicle, Long enterpriseId);
}
