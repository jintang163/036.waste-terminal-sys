package com.waste.controller;

import com.waste.common.Result;
import com.waste.gateway.ScaleGatewayService;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import io.swagger.annotations.ApiParam;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@Api(tags = "地磅网关管理")
@RestController
@RequestMapping("/scale/gateway")
public class ScaleGatewayController {

    @Autowired
    private ScaleGatewayService scaleGatewayService;

    @ApiOperation("获取网关状态")
    @GetMapping("/status")
    public Result<ScaleGatewayService.GatewayStatus> getStatus() {
        return Result.success(scaleGatewayService.getGatewayStatus());
    }

    @ApiOperation("获取已连接设备列表")
    @GetMapping("/devices")
    public Result<List<ScaleGatewayService.ScaleDevice>> getConnectedDevices() {
        return Result.success(scaleGatewayService.getConnectedDevices());
    }

    @ApiOperation("获取指定设备信息")
    @GetMapping("/device/{deviceId}")
    public Result<ScaleGatewayService.ScaleDevice> getDevice(
            @ApiParam("设备ID") @PathVariable String deviceId) {
        ScaleGatewayService.ScaleDevice device = scaleGatewayService.getDevice(deviceId);
        if (device == null) {
            return Result.error("设备不存在");
        }
        return Result.success(device);
    }

    @ApiOperation("向设备发送指令")
    @PostMapping("/device/{deviceId}/command")
    public Result<Void> sendCommand(
            @ApiParam("设备ID") @PathVariable String deviceId,
            @ApiParam("指令内容") @RequestBody Map<String, String> params) {
        String command = params.get("command");
        if (command == null || command.trim().isEmpty()) {
            return Result.error("指令不能为空");
        }
        scaleGatewayService.sendCommand(deviceId, command.trim());
        return Result.success();
    }

    @ApiOperation("断开设备连接")
    @PostMapping("/device/{deviceId}/disconnect")
    public Result<Void> disconnectDevice(
            @ApiParam("设备ID") @PathVariable String deviceId) {
        scaleGatewayService.disconnectDevice(deviceId);
        return Result.success();
    }

    @ApiOperation("重启网关服务")
    @PostMapping("/restart")
    public Result<Void> restartGateway() {
        log.info("收到重启地磅网关请求");
        new Thread(() -> {
            try {
                Thread.sleep(1000);
                scaleGatewayService.restartGateway();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }).start();
        return Result.success();
    }
}
