package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.DeviceInfo;
import com.waste.service.DeviceInfoService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/device")
public class DeviceInfoController {

    @Autowired
    private DeviceInfoService deviceInfoService;

    @GetMapping("/page")
    public Result<PageResult<DeviceInfo>> page(PageQuery pageQuery, DeviceInfo deviceInfo,
                                                @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) enterpriseId = 1L;
        IPage<DeviceInfo> page = deviceInfoService.page(pageQuery, deviceInfo, enterpriseId);
        return Result.success(PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords()));
    }

    @GetMapping("/{id}")
    public Result<DeviceInfo> getById(@PathVariable Long id) {
        return Result.success(deviceInfoService.getById(id));
    }

    @GetMapping("/code/{deviceNo}")
    public Result<DeviceInfo> getByDeviceNo(@PathVariable String deviceNo,
                                             @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) enterpriseId = 1L;
        return Result.success(deviceInfoService.getByDeviceNo(deviceNo, enterpriseId));
    }

    @PostMapping
    public Result<Void> add(@RequestBody DeviceInfo deviceInfo,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) enterpriseId = 1L;
        deviceInfoService.add(deviceInfo, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody DeviceInfo deviceInfo) {
        deviceInfoService.update(id, deviceInfo);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        deviceInfoService.delete(id);
        return Result.success();
    }

    @GetMapping("/list")
    public Result<List<DeviceInfo>> list(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) enterpriseId = 1L;
        return Result.success(deviceInfoService.listByEnterpriseId(enterpriseId));
    }

    @PutMapping("/status/{id}")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestParam Integer status) {
        deviceInfoService.updateStatus(id, status);
        return Result.success();
    }

    @PostMapping("/heartbeat")
    public Result<Map<String, Object>> heartbeat(@RequestBody Map<String, Object> heartbeatData) {
        log.debug("收到心跳请求: deviceId={}", heartbeatData.get("deviceId"));
        Map<String, Object> result = deviceInfoService.heartbeat(heartbeatData);
        return Result.success(result);
    }

    @PostMapping("/check-abnormal")
    public Result<Integer> checkAbnormalDevices(@RequestParam(defaultValue = "24") int thresholdHours) {
        int count = deviceInfoService.markAbnormalDevices(thresholdHours);
        return Result.success(count);
    }
}
