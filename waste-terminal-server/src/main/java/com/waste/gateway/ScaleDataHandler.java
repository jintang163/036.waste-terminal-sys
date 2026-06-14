package com.waste.gateway;

import cn.hutool.core.util.StrUtil;
import com.waste.gateway.ScaleGatewayService.ScaleDevice;
import com.waste.gateway.ScaleGatewayService.ScaleWeightData;
import com.waste.gateway.ScaleProtocolDecoder.DecodedFrame;
import com.waste.mq.WasteMqProducer;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.handler.timeout.IdleState;
import io.netty.handler.timeout.IdleStateEvent;
import lombok.extern.slf4j.Slf4j;

import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Slf4j
public class ScaleDataHandler extends SimpleChannelInboundHandler<DecodedFrame> {

    private static final Map<String, ChannelHandlerContext> CHANNEL_MAP = new ConcurrentHashMap<>();
    private static final Map<String, AtomicInteger> HEARTBEAT_COUNTERS = new ConcurrentHashMap<>();

    private final ScaleGatewayService gatewayService;
    private final WasteMqProducer mqProducer;
    private final int heartbeatThreshold;

    private String deviceId;
    private ScaleDevice device;

    public ScaleDataHandler(ScaleGatewayService gatewayService, WasteMqProducer mqProducer, int heartbeatThreshold) {
        this.gatewayService = gatewayService;
        this.mqProducer = mqProducer;
        this.heartbeatThreshold = heartbeatThreshold;
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        InetSocketAddress address = (InetSocketAddress) ctx.channel().remoteAddress();
        String host = address.getAddress().getHostAddress();
        int port = address.getPort();
        deviceId = "SCALE-" + host.replace(".", "") + "-" + port;

        log.info("地磅设备连接接入, deviceId={}, host={}, port={}", deviceId, host, port);

        device = new ScaleDevice();
        device.setDeviceId(deviceId);
        device.setDeviceName("地磅设备-" + host);
        device.setProtocolType("STANDARD");
        device.setHost(host);
        device.setPort(port);
        device.setConnectTime(LocalDateTime.now());
        device.setLastActiveTime(LocalDateTime.now());
        device.setConnected(true);

        gatewayService.getConnectedDevices().put(deviceId, device);
        CHANNEL_MAP.put(deviceId, ctx);
        HEARTBEAT_COUNTERS.put(deviceId, new AtomicInteger(0));

        super.channelActive(ctx);
    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        if (deviceId != null) {
            log.info("地磅设备连接断开, deviceId={}", deviceId);

            ScaleDevice connectedDevice = gatewayService.getConnectedDevices().get(deviceId);
            if (connectedDevice != null) {
                connectedDevice.setConnected(false);
                connectedDevice.setLastActiveTime(LocalDateTime.now());
            }

            CHANNEL_MAP.remove(deviceId);
            HEARTBEAT_COUNTERS.remove(deviceId);
        }

        super.channelInactive(ctx);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        log.error("地磅设备通信异常, deviceId={}, error={}", deviceId, cause.getMessage(), cause);

        if (device != null) {
            device.setLastActiveTime(LocalDateTime.now());
        }

        if (!ctx.channel().isActive()) {
            ctx.close();
        }
    }

    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        if (evt instanceof IdleStateEvent) {
            IdleStateEvent event = (IdleStateEvent) evt;

            if (event.state() == IdleState.READER_IDLE) {
                handleReaderIdle(ctx);
            } else if (event.state() == IdleState.WRITER_IDLE) {
                handleWriterIdle(ctx);
            } else if (event.state() == IdleState.ALL_IDLE) {
                handleAllIdle(ctx);
            }
        }

        super.userEventTriggered(ctx, evt);
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, DecodedFrame frame) throws Exception {
        if (frame == null || frame.getWeight() == null) {
            log.debug("收到无效地磅数据, deviceId={}, hex={}", deviceId, frame != null ? frame.getRawHex() : "null");
            return;
        }

        if (device != null) {
            device.setLastActiveTime(LocalDateTime.now());
            if (frame.getProtocolType() != null) {
                device.setProtocolType(frame.getProtocolType().name());
            }
        }

        AtomicInteger counter = HEARTBEAT_COUNTERS.get(deviceId);
        if (counter != null) {
            counter.set(0);
        }

        ScaleWeightData weightData = convertToWeightData(frame);
        processWeightData(weightData);
    }

    private ScaleWeightData convertToWeightData(DecodedFrame frame) {
        ScaleWeightData data = new ScaleWeightData();
        data.setDeviceId(deviceId);
        data.setDeviceName(device != null ? device.getDeviceName() : "未知设备");
        data.setWeight(frame.getWeight());
        data.setUnit(frame.getUnit());
        data.setStable(frame.isStable());
        data.setMeasureTime(frame.getMeasureTime());
        data.setRawData(frame.getRawHex());
        data.setProtocolType(frame.getProtocolType() != null ? frame.getProtocolType().name() : "UNKNOWN");
        return data;
    }

    private void processWeightData(ScaleWeightData weightData) {
        if (weightData.getWeight() == null) {
            return;
        }

        if (weightData.getWeight().compareTo(BigDecimal.ZERO) < 0) {
            weightData.setWeight(BigDecimal.ZERO);
        }

        log.info("接收到地磅重量数据, deviceId={}, weight={}{}, stable={}, protocol={}",
                weightData.getDeviceId(), weightData.getWeight(), weightData.getUnit(),
                weightData.isStable(), weightData.getProtocolType());

        gatewayService.getWeightCallbacks().forEach(callback -> {
            try {
                callback.accept(weightData);
            } catch (Exception e) {
                log.error("地磅数据回调处理异常", e);
            }
        });

        sendToMq(weightData);
    }

    private void sendToMq(ScaleWeightData weightData) {
        try {
            Map<String, Object> mqData = new LinkedHashMap<>();
            mqData.put("deviceId", weightData.getDeviceId());
            mqData.put("deviceName", weightData.getDeviceName());
            mqData.put("weight", weightData.getWeight());
            mqData.put("unit", weightData.getUnit());
            mqData.put("stable", weightData.isStable());
            mqData.put("measureTime", weightData.getMeasureTime()
                    .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
            mqData.put("rawData", weightData.getRawData());
            mqData.put("protocolType", weightData.getProtocolType());

            mqProducer.sendScaleData(mqData);
        } catch (Exception e) {
            log.error("发送地磅数据到MQ异常, deviceId={}", deviceId, e);
        }
    }

    private void handleReaderIdle(ChannelHandlerContext ctx) {
        if (deviceId == null) {
            return;
        }

        AtomicInteger counter = HEARTBEAT_COUNTERS.get(deviceId);
        if (counter == null) {
            return;
        }

        int count = counter.incrementAndGet();
        log.debug("地磅设备读空闲, deviceId={}, 连续空闲次数={}/{}", deviceId, count, heartbeatThreshold);

        if (device != null) {
            device.setLastActiveTime(LocalDateTime.now());
        }

        if (count >= heartbeatThreshold) {
            log.warn("地磅设备心跳超时, deviceId={}, 已连续{}次未收到数据, 关闭连接", deviceId, count);
            ctx.close();
        }
    }

    private void handleWriterIdle(ChannelHandlerContext ctx) {
        log.debug("地磅设备写空闲, deviceId={}", deviceId);

        try {
            ctx.writeAndFlush("\r\n");
        } catch (Exception e) {
            log.debug("发送心跳包失败, deviceId={}", deviceId, e);
        }
    }

    private void handleAllIdle(ChannelHandlerContext ctx) {
        log.debug("地磅设备读写空闲, deviceId={}", deviceId);
    }

    public static ChannelHandlerContext getChannel(String deviceId) {
        return StrUtil.isBlank(deviceId) ? null : CHANNEL_MAP.get(deviceId);
    }

    public static void sendCommand(String deviceId, String command) {
        if (StrUtil.isBlank(deviceId) || StrUtil.isBlank(command)) {
            return;
        }

        ChannelHandlerContext ctx = CHANNEL_MAP.get(deviceId);
        if (ctx == null || !ctx.channel().isActive()) {
            log.warn("设备未连接, 无法发送指令, deviceId={}", deviceId);
            return;
        }

        try {
            log.info("向设备发送指令, deviceId={}, command={}", deviceId, command);
            ctx.writeAndFlush(command + "\r\n");
        } catch (Exception e) {
            log.error("发送指令失败, deviceId={}", deviceId, e);
        }
    }

    public static void closeChannel(String deviceId) {
        if (StrUtil.isBlank(deviceId)) {
            return;
        }

        ChannelHandlerContext ctx = CHANNEL_MAP.get(deviceId);
        if (ctx != null) {
            try {
                ctx.close();
                log.info("已关闭设备连接, deviceId={}", deviceId);
            } catch (Exception e) {
                log.error("关闭设备连接失败, deviceId={}", deviceId, e);
            }
        }
    }

    public static int getConnectedCount() {
        return CHANNEL_MAP.size();
    }
}
