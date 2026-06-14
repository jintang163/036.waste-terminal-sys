package com.waste.gateway;

import cn.hutool.core.util.HexUtil;
import cn.hutool.core.util.NumberUtil;
import cn.hutool.core.util.StrUtil;
import com.waste.mq.WasteMqProducer;
import lombok.Data;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

@Slf4j
@Service
public class ScaleGatewayService {

    @Value("${scale.gateway.port:8899}")
    private int gatewayPort;

    @Value("${scale.gateway.boss-threads:1}")
    private int bossThreads;

    @Value("${scale.gateway.worker-threads:8}")
    private int workerThreads;

    @Value("${scale.gateway.reader-idle-seconds:30}")
    private int readerIdleSeconds;

    @Value("${scale.gateway.writer-idle-seconds:0}")
    private int writerIdleSeconds;

    @Value("${scale.gateway.all-idle-seconds:0}")
    private int allIdleSeconds;

    @Value("${scale.gateway.heartbeat-threshold:3}")
    private int heartbeatThreshold;

    @Value("${scale.gateway.mock-enabled:true}")
    private boolean mockEnabled;

    @Value("${scale.gateway.mock-interval-seconds:5}")
    private int mockIntervalSeconds;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    @Getter
    private final Map<String, ScaleDevice> connectedDevices = new ConcurrentHashMap<>();

    @Getter
    private final List<Consumer<ScaleWeightData>> weightCallbacks = new ArrayList<>();

    private final AtomicBoolean running = new AtomicBoolean(false);

    private ScaleGatewayServer gatewayServer;

    private ScheduledExecutorService mockExecutor;

    public interface ScaleWeightCallback {
        void onWeightReceived(ScaleWeightData data);
    }

    @Data
    public static class ScaleWeightData {
        private String deviceId;
        private String deviceName;
        private BigDecimal weight;
        private String unit;
        private boolean stable;
        private LocalDateTime measureTime;
        private String rawData;
        private String protocolType;
    }

    @Data
    public static class ScaleDevice {
        private String deviceId;
        private String deviceName;
        private String protocolType;
        private String host;
        private int port;
        private LocalDateTime connectTime;
        private LocalDateTime lastActiveTime;
        private boolean connected;
    }

    @PostConstruct
    public void init() {
        startNettyGateway();
        if (mockEnabled) {
            startMockData();
        }
        log.info("地磅串口网关服务初始化完成, port={}, mockEnabled={}", gatewayPort, mockEnabled);
    }

    @PreDestroy
    public void destroy() {
        stopNettyGateway();
        stopMockData();
        log.info("地磅串口网关服务已关闭");
    }

    private void startNettyGateway() {
        if (running.compareAndSet(false, true)) {
            gatewayServer = new ScaleGatewayServer(
                    gatewayPort,
                    readerIdleSeconds,
                    writerIdleSeconds,
                    allIdleSeconds,
                    heartbeatThreshold,
                    bossThreads,
                    workerThreads,
                    this,
                    wasteMqProducer
            );
            gatewayServer.start();
        }
    }

    private void stopNettyGateway() {
        running.set(false);
        if (gatewayServer != null) {
            gatewayServer.stop();
        }
        connectedDevices.values().forEach(d -> d.setConnected(false));
    }

    public void restartGateway() {
        log.info("正在重启地磅网关服务...");
        stopNettyGateway();
        try {
            TimeUnit.SECONDS.sleep(2);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        startNettyGateway();
        log.info("地磅网关服务重启完成");
    }

    public void registerWeightCallback(Consumer<ScaleWeightData> callback) {
        if (callback != null) {
            weightCallbacks.add(callback);
        }
    }

    public void removeWeightCallback(Consumer<ScaleWeightData> callback) {
        weightCallbacks.remove(callback);
    }

    public List<ScaleDevice> getConnectedDevices() {
        return new ArrayList<>(connectedDevices.values());
    }

    public ScaleDevice getDevice(String deviceId) {
        return connectedDevices.get(deviceId);
    }

    public void sendCommand(String deviceId, String command) {
        ScaleDevice device = connectedDevices.get(deviceId);
        if (device == null || !device.isConnected()) {
            log.warn("设备未连接, deviceId={}", deviceId);
            return;
        }
        ScaleDataHandler.sendCommand(deviceId, command);
    }

    public void disconnectDevice(String deviceId) {
        ScaleDevice device = connectedDevices.get(deviceId);
        if (device == null) {
            log.warn("设备不存在, deviceId={}", deviceId);
            return;
        }
        ScaleDataHandler.closeChannel(deviceId);
        log.info("已断开设备连接, deviceId={}", deviceId);
    }

    public GatewayStatus getGatewayStatus() {
        GatewayStatus status = new GatewayStatus();
        status.setPort(gatewayPort);
        status.setRunning(gatewayServer != null && gatewayServer.isRunning());
        status.setConnectedCount(ScaleDataHandler.getConnectedCount());
        status.setDeviceCount(connectedDevices.size());
        status.setMockEnabled(mockEnabled);
        status.setStartTime(null);
        return status;
    }

    @Data
    public static class GatewayStatus {
        private int port;
        private boolean running;
        private int connectedCount;
        private int deviceCount;
        private boolean mockEnabled;
        private LocalDateTime startTime;
    }

    public ScaleWeightData parseScaleFrame(ScaleDevice device, String frameHex) {
        ScaleWeightData data = new ScaleWeightData();
        data.setDeviceId(device.getDeviceId());
        data.setDeviceName(device.getDeviceName());
        data.setProtocolType(device.getProtocolType());
        data.setRawData(frameHex);
        data.setMeasureTime(LocalDateTime.now());

        try {
            byte[] frameBytes = HexUtil.decodeHex(frameHex);
            String ascii = new String(frameBytes);

            String weightStr = extractWeightFromAscii(ascii);
            if (weightStr != null) {
                data.setWeight(new BigDecimal(weightStr));
                data.setUnit("kg");
                data.setStable(true);
                return data;
            }

            if (frameBytes.length >= 8) {
                int weightOffset = Math.max(0, frameBytes.length - 6);
                StringBuilder sb = new StringBuilder();
                for (int i = weightOffset; i < frameBytes.length; i++) {
                    int b = frameBytes[i] & 0xFF;
                    if (b >= 0x30 && b <= 0x39) {
                        sb.append((char) b);
                    } else if (b == 0x2E) {
                        sb.append('.');
                    }
                }
                String num = sb.toString();
                if (NumberUtil.isNumber(num)) {
                    data.setWeight(new BigDecimal(num));
                    data.setUnit("kg");
                    data.setStable(true);
                    return data;
                }
            }

            log.debug("无法解析地磅数据帧, deviceId={}, frame={}", device.getDeviceId(), frameHex);
            return null;
        } catch (Exception e) {
            log.warn("解析地磅帧异常, frame={}", frameHex, e);
            return null;
        }
    }

    private String extractWeightFromAscii(String ascii) {
        String[] patterns = {
                "ST,GS,(\\d+\\.?\\d*)",
                "ST,NT,(\\d+\\.?\\d*)",
                "WT:(\\d+\\.?\\d*)",
                "=([+-]?\\d+\\.?\\d*)\\s*kg",
                "([+-]?\\d+\\.\\d{3})"
        };
        for (String pattern : patterns) {
            java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern);
            java.util.regex.Matcher m = p.matcher(ascii);
            if (m.find()) {
                return m.group(1);
            }
        }
        return null;
    }

    public void notifyWeightReceived(ScaleWeightData data) {
        log.info("接收到地磅重量数据, deviceId={}, weight={}{}, stable={}",
                data.getDeviceId(), data.getWeight(), data.getUnit(), data.isStable());

        for (Consumer<ScaleWeightData> callback : weightCallbacks) {
            try {
                callback.accept(data);
            } catch (Exception e) {
                log.error("地磅数据回调处理异常", e);
            }
        }

        try {
            Map<String, Object> mqData = new LinkedHashMap<>();
            mqData.put("deviceId", data.getDeviceId());
            mqData.put("deviceName", data.getDeviceName());
            mqData.put("weight", data.getWeight());
            mqData.put("unit", data.getUnit());
            mqData.put("stable", data.isStable());
            mqData.put("measureTime", data.getMeasureTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
            mqData.put("rawData", data.getRawData());
            mqData.put("protocolType", data.getProtocolType());
            wasteMqProducer.sendScaleData(mqData);
        } catch (Exception e) {
            log.error("发送地磅数据到MQ异常", e);
        }
    }

    private void startMockData() {
        mockExecutor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "scale-mock");
            t.setDaemon(true);
            return t;
        });

        ScaleDevice mockDevice = new ScaleDevice();
        mockDevice.setDeviceId("MOCK-SCALE-001");
        mockDevice.setDeviceName("模拟地磅设备-1号");
        mockDevice.setProtocolType("MOCK");
        mockDevice.setHost("127.0.0.1");
        mockDevice.setPort(0);
        mockDevice.setConnectTime(LocalDateTime.now());
        mockDevice.setLastActiveTime(LocalDateTime.now());
        mockDevice.setConnected(true);
        connectedDevices.put(mockDevice.getDeviceId(), mockDevice);

        final java.util.concurrent.atomic.AtomicInteger mockCounter = new java.util.concurrent.atomic.AtomicInteger(0);

        mockExecutor.scheduleAtFixedRate(() -> {
            try {
                mockDevice.setLastActiveTime(LocalDateTime.now());

                ScaleWeightData mockData = new ScaleWeightData();
                mockData.setDeviceId(mockDevice.getDeviceId());
                mockData.setDeviceName(mockDevice.getDeviceName());
                mockData.setProtocolType(mockDevice.getProtocolType());
                mockData.setMeasureTime(LocalDateTime.now());
                mockData.setUnit("kg");
                mockData.setStable(mockCounter.get() % 3 != 0);

                double baseWeight = 500 + Math.random() * 9500;
                if (!mockData.isStable()) {
                    baseWeight += (Math.random() - 0.5) * 200;
                }
                mockData.setWeight(new BigDecimal(String.format("%.3f", baseWeight)));

                String mockHex = buildMockHexFrame(mockData);
                mockData.setRawData(mockHex);

                notifyWeightReceived(mockData);
                mockCounter.incrementAndGet();
            } catch (Exception e) {
                log.error("生成模拟地磅数据异常", e);
            }
        }, 2, mockIntervalSeconds, TimeUnit.SECONDS);

        log.info("地磅模拟数据已启动, interval={}s", mockIntervalSeconds);
    }

    private String buildMockHexFrame(ScaleWeightData data) {
        String weightStr = String.format("%10s", data.getWeight().toPlainString()).replace(' ', '0');
        String frame = "ST," + (data.isStable() ? "GS" : "NT") + "," + weightStr + "kg\r\n";
        return HexUtil.encodeHexStr(frame.getBytes());
    }

    private void stopMockData() {
        if (mockExecutor != null) {
            mockExecutor.shutdownNow();
        }
    }
}
