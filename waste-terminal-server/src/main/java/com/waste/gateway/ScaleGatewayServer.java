package com.waste.gateway;

import com.waste.mq.WasteMqProducer;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.handler.codec.string.StringEncoder;
import io.netty.handler.timeout.IdleStateHandler;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;

import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
public class ScaleGatewayServer {

    private final int port;
    private final int readerIdleSeconds;
    private final int writerIdleSeconds;
    private final int allIdleSeconds;
    private final int heartbeatThreshold;
    private final int bossThreads;
    private final int workerThreads;

    private final ScaleGatewayService gatewayService;
    private final WasteMqProducer mqProducer;

    private EventLoopGroup bossGroup;
    private EventLoopGroup workerGroup;
    private ChannelFuture channelFuture;

    @Getter
    private final AtomicBoolean running = new AtomicBoolean(false);

    public ScaleGatewayServer(int port, int readerIdleSeconds, int writerIdleSeconds,
                              int allIdleSeconds, int heartbeatThreshold,
                              int bossThreads, int workerThreads,
                              ScaleGatewayService gatewayService, WasteMqProducer mqProducer) {
        this.port = port;
        this.readerIdleSeconds = readerIdleSeconds;
        this.writerIdleSeconds = writerIdleSeconds;
        this.allIdleSeconds = allIdleSeconds;
        this.heartbeatThreshold = heartbeatThreshold;
        this.bossThreads = bossThreads;
        this.workerThreads = workerThreads;
        this.gatewayService = gatewayService;
        this.mqProducer = mqProducer;
    }

    public void start() {
        if (!running.compareAndSet(false, true)) {
            log.warn("地磅网关服务已在运行中");
            return;
        }

        try {
            bossGroup = new NioEventLoopGroup(bossThreads);
            workerGroup = new NioEventLoopGroup(workerThreads);

            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .option(ChannelOption.SO_BACKLOG, 1024)
                    .option(ChannelOption.SO_REUSEADDR, true)
                    .childOption(ChannelOption.SO_KEEPALIVE, true)
                    .childOption(ChannelOption.TCP_NODELAY, true)
                    .childOption(ChannelOption.SO_RCVBUF, 1024 * 64)
                    .childOption(ChannelOption.SO_SNDBUF, 1024 * 64)
                    .childHandler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            ch.pipeline().addLast("idleStateHandler",
                                    new IdleStateHandler(readerIdleSeconds, writerIdleSeconds,
                                            allIdleSeconds, TimeUnit.SECONDS));
                            ch.pipeline().addLast("decoder", new ScaleProtocolDecoder());
                            ch.pipeline().addLast("encoder", new StringEncoder(StandardCharsets.UTF_8));
                            ch.pipeline().addLast("handler",
                                    new ScaleDataHandler(gatewayService, mqProducer, heartbeatThreshold));
                        }
                    });

            channelFuture = bootstrap.bind(port).sync();
            log.info("地磅串口网关服务启动成功, 监听端口: {}, bossThreads={}, workerThreads={}",
                    port, bossThreads, workerThreads);
            log.info("心跳配置: readerIdle={}s, writerIdle={}s, allIdle={}s, threshold={}",
                    readerIdleSeconds, writerIdleSeconds, allIdleSeconds, heartbeatThreshold);

            channelFuture.channel().closeFuture().addListener(future -> {
                if (running.get()) {
                    log.warn("地磅网关服务意外关闭, 准备重启...");
                    scheduleRestart();
                }
            });

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("地磅网关服务启动被中断", e);
            stop();
        } catch (Exception e) {
            log.error("地磅网关服务启动失败, port={}", port, e);
            stop();
            scheduleRestart();
        }
    }

    public void stop() {
        if (!running.compareAndSet(true, false)) {
            return;
        }

        log.info("正在停止地磅网关服务...");

        if (channelFuture != null && channelFuture.channel() != null) {
            try {
                channelFuture.channel().close().syncUninterruptibly();
            } catch (Exception e) {
                log.warn("关闭服务器Channel异常", e);
            }
        }

        if (workerGroup != null) {
            workerGroup.shutdownGracefully(2, 5, TimeUnit.SECONDS);
        }

        if (bossGroup != null) {
            bossGroup.shutdownGracefully(2, 5, TimeUnit.SECONDS);
        }

        log.info("地磅网关服务已停止");
    }

    private void scheduleRestart() {
        if (running.get()) {
            return;
        }

        new Thread(() -> {
            try {
                int delay = 5;
                log.info("地磅网关服务将在{}秒后重启...", delay);
                TimeUnit.SECONDS.sleep(delay);

                if (!running.get()) {
                    log.info("开始重启地磅网关服务...");
                    start();
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                log.warn("地磅网关服务重启被中断");
            } catch (Exception e) {
                log.error("地磅网关服务重启失败", e);
            }
        }, "scale-gateway-restart").start();
    }

    public boolean isRunning() {
        return running.get() && channelFuture != null && channelFuture.channel().isActive();
    }

    public int getConnectedDeviceCount() {
        return ScaleDataHandler.getConnectedCount();
    }
}
