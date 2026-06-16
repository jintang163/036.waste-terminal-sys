package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.DeviceHeartbeatLog;
import com.waste.entity.DeviceInfo;
import com.waste.entity.WarningRecord;
import com.waste.mapper.DeviceHeartbeatLogMapper;
import com.waste.mapper.DeviceInfoMapper;
import com.waste.mapper.WarningRecordMapper;
import com.waste.service.DeviceInfoService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class DeviceInfoServiceImpl implements DeviceInfoService {

    @Autowired
    private DeviceInfoMapper deviceInfoMapper;

    @Autowired
    private DeviceHeartbeatLogMapper heartbeatLogMapper;

    @Autowired
    private WarningRecordMapper warningRecordMapper;

    private LambdaQueryWrapper<DeviceInfo> buildQueryWrapper(DeviceInfo deviceInfo, Long enterpriseId) {
        LambdaQueryWrapper<DeviceInfo> wrapper = new LambdaQueryWrapper<>();
        if (StrUtil.isNotBlank(deviceInfo.getDeviceNo())) {
            wrapper.like(DeviceInfo::getDeviceNo, deviceInfo.getDeviceNo());
        }
        if (StrUtil.isNotBlank(deviceInfo.getDeviceName())) {
            wrapper.like(DeviceInfo::getDeviceName, deviceInfo.getDeviceName());
        }
        if (StrUtil.isNotBlank(deviceInfo.getDeviceType())) {
            wrapper.eq(DeviceInfo::getDeviceType, deviceInfo.getDeviceType());
        }
        if (deviceInfo.getStatus() != null) {
            wrapper.eq(DeviceInfo::getStatus, deviceInfo.getStatus());
        }
        if (enterpriseId != null) {
            wrapper.eq(DeviceInfo::getEnterpriseId, enterpriseId);
        }
        return wrapper;
    }

    @Override
    public IPage<DeviceInfo> page(PageQuery pageQuery, DeviceInfo deviceInfo, Long enterpriseId) {
        Page<DeviceInfo> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<DeviceInfo> wrapper = buildQueryWrapper(deviceInfo, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(DeviceInfo::getCreateTime);
        }
        return deviceInfoMapper.selectPage(page, wrapper);
    }

    @Override
    public DeviceInfo getById(Long id) {
        DeviceInfo device = deviceInfoMapper.selectById(id);
        if (device == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return device;
    }

    @Override
    public DeviceInfo getByDeviceNo(String deviceNo, Long enterpriseId) {
        LambdaQueryWrapper<DeviceInfo> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(DeviceInfo::getDeviceNo, deviceNo);
        if (enterpriseId != null) {
            wrapper.eq(DeviceInfo::getEnterpriseId, enterpriseId);
        }
        return deviceInfoMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(DeviceInfo deviceInfo, Long enterpriseId) {
        if (StrUtil.isBlank(deviceInfo.getDeviceNo())) {
            throw new BusinessException("设备编号不能为空");
        }
        if (deviceInfo.getStatus() == null) {
            deviceInfo.setStatus(0);
        }
        if (enterpriseId != null) {
            deviceInfo.setEnterpriseId(enterpriseId);
        }

        LambdaQueryWrapper<DeviceInfo> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(DeviceInfo::getDeviceNo, deviceInfo.getDeviceNo());
        if (enterpriseId != null) {
            existWrapper.eq(DeviceInfo::getEnterpriseId, enterpriseId);
        }
        if (deviceInfoMapper.selectCount(existWrapper) > 0) {
            throw new BusinessException("设备编号已存在");
        }

        deviceInfoMapper.insert(deviceInfo);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, DeviceInfo deviceInfo) {
        DeviceInfo exist = getById(id);

        if (deviceInfo.getDeviceName() != null) exist.setDeviceName(deviceInfo.getDeviceName());
        if (deviceInfo.getDeviceType() != null) exist.setDeviceType(deviceInfo.getDeviceType());
        if (deviceInfo.getDeviceModel() != null) exist.setDeviceModel(deviceInfo.getDeviceModel());
        if (deviceInfo.getManufacturer() != null) exist.setManufacturer(deviceInfo.getManufacturer());
        if (deviceInfo.getConnectType() != null) exist.setConnectType(deviceInfo.getConnectType());
        if (deviceInfo.getMacAddress() != null) exist.setMacAddress(deviceInfo.getMacAddress());
        if (deviceInfo.getSerialPort() != null) exist.setSerialPort(deviceInfo.getSerialPort());
        if (deviceInfo.getBaudRate() != null) exist.setBaudRate(deviceInfo.getBaudRate());
        if (deviceInfo.getStatus() != null) exist.setStatus(deviceInfo.getStatus());
        if (deviceInfo.getRemark() != null) exist.setRemark(deviceInfo.getRemark());

        deviceInfoMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        getById(id);
        deviceInfoMapper.deleteById(id);
    }

    @Override
    public List<DeviceInfo> listByEnterpriseId(Long enterpriseId) {
        LambdaQueryWrapper<DeviceInfo> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(DeviceInfo::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(DeviceInfo::getDeviceNo);
        return deviceInfoMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateStatus(Long id, Integer status) {
        DeviceInfo exist = getById(id);
        exist.setStatus(status);
        deviceInfoMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> heartbeat(Map<String, Object> heartbeatData) {
        Map<String, Object> result = new HashMap<>();
        try {
            String deviceId = (String) heartbeatData.get("deviceId");
            if (StrUtil.isBlank(deviceId)) {
                throw new BusinessException("设备ID不能为空");
            }

            Long enterpriseId = null;
            Object enterpriseIdObj = heartbeatData.get("enterpriseId");
            if (enterpriseIdObj != null) {
                if (enterpriseIdObj instanceof Number) {
                    enterpriseId = ((Number) enterpriseIdObj).longValue();
                } else if (enterpriseIdObj instanceof String) {
                    try {
                        enterpriseId = Long.parseLong((String) enterpriseIdObj);
                    } catch (NumberFormatException ignored) {}
                }
            }

            Long userId = null;
            Object userIdObj = heartbeatData.get("userId");
            if (userIdObj != null) {
                if (userIdObj instanceof Number) {
                    userId = ((Number) userIdObj).longValue();
                } else if (userIdObj instanceof String) {
                    try {
                        userId = Long.parseLong((String) userIdObj);
                    } catch (NumberFormatException ignored) {}
                }
            }

            LocalDateTime now = LocalDateTime.now();

            DeviceInfo deviceInfo = getByDeviceNo(deviceId, enterpriseId);
            boolean isNew = false;
            if (deviceInfo == null) {
                deviceInfo = new DeviceInfo();
                deviceInfo.setDeviceNo(deviceId);
                deviceInfo.setStatus(1);
                deviceInfo.setCreateTime(now);
                isNew = true;
            }

            deviceInfo.setDeviceName((String) heartbeatData.get("deviceName"));
            deviceInfo.setDeviceModel((String) heartbeatData.get("deviceModel"));
            deviceInfo.setPlatform((String) heartbeatData.get("platform"));
            deviceInfo.setOsVersion((String) heartbeatData.get("osVersion"));
            deviceInfo.setNetworkType((String) heartbeatData.get("networkType"));

            Object batteryObj = heartbeatData.get("batteryLevel");
            if (batteryObj != null) {
                if (batteryObj instanceof Number) {
                    deviceInfo.setBatteryLevel(((Number) batteryObj).intValue());
                }
            }

            Object storageObj = heartbeatData.get("storage");
            if (storageObj instanceof Map) {
                @SuppressWarnings("unchecked")
                Map<String, Object> storageMap = (Map<String, Object>) storageObj;
                deviceInfo.setStorageInfo(storageMap);
            }

            Object bluetoothObj = heartbeatData.get("bluetooth");
            if (bluetoothObj instanceof Map) {
                @SuppressWarnings("unchecked")
                Map<String, Object> bluetoothMap = (Map<String, Object>) bluetoothObj;
                deviceInfo.setBluetoothInfo(bluetoothMap);
            }

            deviceInfo.setAppVersion((String) heartbeatData.get("appVersion"));
            deviceInfo.setBuildNumber((String) heartbeatData.get("buildNumber"));
            deviceInfo.setCurrentUserId(userId);
            deviceInfo.setCurrentUsername((String) heartbeatData.get("username"));
            if (enterpriseId != null) {
                deviceInfo.setEnterpriseId(enterpriseId);
            }
            deviceInfo.setLastHeartbeatTime(now);
            deviceInfo.setLastConnectTime(now);
            deviceInfo.setStatus(1);
            deviceInfo.setUpdateTime(now);

            if (isNew) {
                deviceInfoMapper.insert(deviceInfo);
                log.info("新设备首次心跳注册: deviceId={}, deviceName={}", deviceId, deviceInfo.getDeviceName());
            } else {
                deviceInfoMapper.updateById(deviceInfo);
            }

            DeviceHeartbeatLog heartbeatLog = new DeviceHeartbeatLog();
            heartbeatLog.setDeviceId(deviceId);
            heartbeatLog.setDeviceName(deviceInfo.getDeviceName());
            heartbeatLog.setDeviceModel(deviceInfo.getDeviceModel());
            heartbeatLog.setPlatform(deviceInfo.getPlatform());
            heartbeatLog.setOsVersion(deviceInfo.getOsVersion());
            heartbeatLog.setUserId(userId);
            heartbeatLog.setUsername(deviceInfo.getCurrentUsername());
            heartbeatLog.setEnterpriseId(enterpriseId);
            heartbeatLog.setNetworkType(deviceInfo.getNetworkType());
            heartbeatLog.setBatteryLevel(deviceInfo.getBatteryLevel());
            heartbeatLog.setStorageInfo(deviceInfo.getStorageInfo());
            heartbeatLog.setBluetoothInfo(deviceInfo.getBluetoothInfo());
            heartbeatLog.setAppVersion(deviceInfo.getAppVersion());
            heartbeatLog.setBuildNumber(deviceInfo.getBuildNumber());
            heartbeatLog.setHeartbeatTime(now);
            heartbeatLog.setCreateTime(now);
            heartbeatLog.setUpdateTime(now);
            heartbeatLogMapper.insert(heartbeatLog);

            result.put("success", true);
            result.put("serverTime", now.toString());
            result.put("deviceRegistered", isNew);

            log.debug("心跳处理成功: deviceId={}", deviceId);

        } catch (Exception e) {
            log.error("心跳处理失败: {}", e.getMessage(), e);
            result.put("success", false);
            result.put("message", e.getMessage());
            throw new BusinessException("心跳处理失败: " + e.getMessage());
        }
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public int markAbnormalDevices(int thresholdHours) {
        LocalDateTime thresholdTime = LocalDateTime.now().minusHours(thresholdHours);
        LocalDateTime now = LocalDateTime.now();

        LambdaQueryWrapper<DeviceInfo> queryWrapper = new LambdaQueryWrapper<>();
        queryWrapper.ne(DeviceInfo::getStatus, 2);
        queryWrapper.and(w ->
                w.isNull(DeviceInfo::getLastHeartbeatTime)
                        .or().lt(DeviceInfo::getLastHeartbeatTime, thresholdTime)
        );
        List<DeviceInfo> abnormalDevices = deviceInfoMapper.selectList(queryWrapper);
        if (abnormalDevices.isEmpty()) {
            log.info("设备异常检测完成，无异常设备");
            return 0;
        }

        LambdaUpdateWrapper<DeviceInfo> updateWrapper = new LambdaUpdateWrapper<>();
        updateWrapper.ne(DeviceInfo::getStatus, 2);
        updateWrapper.and(w ->
                w.isNull(DeviceInfo::getLastHeartbeatTime)
                        .or().lt(DeviceInfo::getLastHeartbeatTime, thresholdTime)
        );
        updateWrapper.set(DeviceInfo::getStatus, 2);
        updateWrapper.set(DeviceInfo::getUpdateTime, now);

        int updated = deviceInfoMapper.update(null, updateWrapper);

        log.info("设备异常检测完成，检测到{}台异常设备，已标记{}台为故障状态",
                abnormalDevices.size(), updated);

        int warningCount = 0;
        for (DeviceInfo device : abnormalDevices) {
            log.warn("设备状态异常: deviceNo={}, deviceName={}, lastHeartbeat={}",
                    device.getDeviceNo(), device.getDeviceName(), device.getLastHeartbeatTime());

            try {
                WarningRecord warning = createDeviceAbnormalWarning(device, thresholdHours);
                if (warning != null) {
                    warningRecordMapper.insert(warning);
                    warningCount++;
                }
            } catch (Exception e) {
                log.error("创建设备异常预警失败: deviceNo={}", device.getDeviceNo(), e);
            }
        }

        if (warningCount > 0) {
            log.info("已为{}台异常设备生成预警记录", warningCount);
        }

        return updated;
    }

    private WarningRecord createDeviceAbnormalWarning(DeviceInfo device, int thresholdHours) {
        String deviceNo = device.getDeviceNo();
        LocalDateTime todayStart = LocalDateTime.now().withHour(0).withMinute(0).withSecond(0).withNano(0);

        LambdaQueryWrapper<WarningRecord> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(WarningRecord::getWarningType, "device");
        existWrapper.eq(WarningRecord::getContainerCode, deviceNo);
        existWrapper.ge(WarningRecord::getTriggerTime, todayStart);
        existWrapper.eq(WarningRecord::getHandleStatus, 0);
        Long existCount = warningRecordMapper.selectCount(existWrapper);
        if (existCount != null && existCount > 0) {
            log.debug("设备今日已有未处理异常预警，跳过重复创建: deviceNo={}", deviceNo);
            return null;
        }

        String lastHeartbeatStr = device.getLastHeartbeatTime() != null
                ? device.getLastHeartbeatTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
                : "从未上报";

        WarningRecord warning = new WarningRecord();
        warning.setWarningNo("DEV" + System.currentTimeMillis());
        warning.setWarningType("device");
        warning.setWarningLevel(2);
        warning.setContainerCode(deviceNo);
        warning.setWarningContent(String.format(
                "设备[%s(%s)]心跳超时，超过%d小时未上报心跳，最后心跳时间: %s",
                device.getDeviceName() != null ? device.getDeviceName() : "未知设备",
                deviceNo,
                thresholdHours,
                lastHeartbeatStr
        ));
        warning.setTriggerTime(LocalDateTime.now());
        warning.setHandleStatus(0);
        warning.setPushStatus(0);
        warning.setEnterpriseId(device.getEnterpriseId());
        warning.setCreateTime(LocalDateTime.now());
        warning.setUpdateTime(LocalDateTime.now());
        warning.setDeleted(0);

        return warning;
    }
}
