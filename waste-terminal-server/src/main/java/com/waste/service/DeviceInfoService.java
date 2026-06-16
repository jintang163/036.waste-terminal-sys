package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.DeviceInfo;

import java.util.List;
import java.util.Map;

public interface DeviceInfoService {

    IPage<DeviceInfo> page(PageQuery pageQuery, DeviceInfo deviceInfo, Long enterpriseId);

    DeviceInfo getById(Long id);

    DeviceInfo getByDeviceNo(String deviceNo, Long enterpriseId);

    void add(DeviceInfo deviceInfo, Long enterpriseId);

    void update(Long id, DeviceInfo deviceInfo);

    void delete(Long id);

    List<DeviceInfo> listByEnterpriseId(Long enterpriseId);

    void updateStatus(Long id, Integer status);

    Map<String, Object> heartbeat(Map<String, Object> heartbeatData);

    int markAbnormalDevices(int thresholdHours);
}
