package com.waste.video;

import com.waste.config.VideoProperties;
import com.waste.entity.Camera;
import com.waste.mapper.CameraMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import java.io.File;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class RtspProxyService {

    @Autowired
    private VideoProperties videoProperties;

    @Autowired
    private CameraMapper cameraMapper;

    private final Map<String, RtspStreamSession> sessions = new ConcurrentHashMap<>();

    private ScheduledExecutorService idleChecker;

    @PostConstruct
    public void init() {
        if (!videoProperties.getRtsp().isProxyEnabled()) {
            log.info("RTSP代理服务未启用");
            return;
        }

        String hlsBasePath = videoProperties.getRtsp().getHlsStoragePath();
        String snapshotBasePath = videoProperties.getLocalRecord().getStoragePath() + "/snapshots";

        new File(hlsBasePath).mkdirs();
        new File(snapshotBasePath).mkdirs();

        idleChecker = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "rtsp-idle-checker");
            t.setDaemon(true);
            return t;
        });

        int idleTimeout = videoProperties.getRtsp().getIdleTimeout();
        idleChecker.scheduleAtFixedRate(
                this::checkIdleSessions, idleTimeout, idleTimeout / 2, TimeUnit.MILLISECONDS
        );

        log.info("RTSP代理服务初始化完成, HLS路径: {}, 空闲超时: {}ms", hlsBasePath, idleTimeout);
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onApplicationReady() {
        log.info("RTSP代理服务就绪");
    }

    @PreDestroy
    public void destroy() {
        log.info("关闭RTSP代理服务");
        if (idleChecker != null) {
            idleChecker.shutdownNow();
        }
        for (RtspStreamSession session : sessions.values()) {
            try {
                session.stop();
            } catch (Exception e) {
                log.error("关闭流会话失败: {}", session.getCameraCode(), e);
            }
        }
        sessions.clear();
    }

    public synchronized RtspStreamSession getSession(String cameraCode) {
        RtspStreamSession session = sessions.get(cameraCode);
        if (session != null) {
            session.updateAccessTime();
        }
        return session;
    }

    public synchronized RtspStreamSession openStream(String cameraCode) throws Exception {
        RtspStreamSession session = sessions.get(cameraCode);

        if (session != null && session.isAlive()) {
            session.updateAccessTime();
            return session;
        }

        if (session != null) {
            try {
                session.stop();
            } catch (Exception e) {
                log.warn("关闭旧会话失败: {}", cameraCode);
            }
            sessions.remove(cameraCode);
        }

        Camera camera = cameraMapper.selectOne(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<Camera>()
                        .eq(Camera::getCameraCode, cameraCode)
        );

        if (camera == null) {
            throw new RuntimeException("摄像头不存在: " + cameraCode);
        }

        if (camera.getStatus() != null && camera.getStatus() == 0) {
            throw new RuntimeException("摄像头已停用: " + cameraCode);
        }

        String rtspUrl = buildRtspUrl(camera);
        String hlsPath = videoProperties.getRtsp().getHlsStoragePath() + "/" + cameraCode;
        String snapshotPath = videoProperties.getLocalRecord().getStoragePath() + "/snapshots/" + cameraCode;

        session = new RtspStreamSession(cameraCode, rtspUrl, hlsPath, snapshotPath);
        session.start();

        sessions.put(cameraCode, session);

        log.info("摄像头 {} 的RTSP流已打开, 当前在线流数量: {}", cameraCode, sessions.size());
        return session;
    }

    private String buildRtspUrl(Camera camera) {
        String rtspUrl = camera.getRtspUrl();
        if (rtspUrl != null && rtspUrl.startsWith("rtsp://")) {
            if (rtspUrl.contains("@") || (camera.getUsername() == null || camera.getUsername().isEmpty())) {
                return rtspUrl;
            }
        }

        if (rtspUrl == null || rtspUrl.isEmpty()) {
            String brand = camera.getBrand() != null ? camera.getBrand().toLowerCase() : "hikvision";
            String ip = extractIpFromUrl(camera.getHttpUrl());
            String port = "554";
            String username = camera.getUsername() != null ? camera.getUsername() : "admin";
            String password = camera.getPassword() != null ? camera.getPassword() : "admin123";
            String stream = camera.getStreamType() != null && camera.getStreamType() == 1 ? "stream2" : "stream1";

            if ("dahua".equals(brand)) {
                rtspUrl = String.format("rtsp://%s:%s@%s:%s/cam/realmonitor?channel=1&subtype=%d",
                        username, password, ip, port, camera.getStreamType() != null ? camera.getStreamType() : 0);
            } else {
                rtspUrl = String.format("rtsp://%s:%s@%s:%s/%s",
                        username, password, ip, port, stream);
            }
        }

        return rtspUrl;
    }

    private String extractIpFromUrl(String url) {
        if (url == null || url.isEmpty()) {
            return "192.168.1.64";
        }
        try {
            int start = url.indexOf("://");
            if (start >= 0) {
                start += 3;
            } else {
                start = 0;
            }
            int end = url.indexOf(':', start);
            if (end < 0) {
                end = url.indexOf('/', start);
            }
            if (end < 0) {
                end = url.length();
            }
            return url.substring(start, end);
        } catch (Exception e) {
            return "192.168.1.64";
        }
    }

    public synchronized void closeStream(String cameraCode) {
        RtspStreamSession session = sessions.remove(cameraCode);
        if (session != null) {
            try {
                session.stop();
                log.info("摄像头 {} 的RTSP流已关闭", cameraCode);
            } catch (Exception e) {
                log.error("关闭RTSP流失败: {}", cameraCode, e);
            }
        }
    }

    public String getHlsPlayUrl(String cameraCode) {
        String basePath = videoProperties.getRtsp().getHlsStoragePath();
        return "/video/hls/" + cameraCode + "/stream.m3u8";
    }

    public String takeSnapshot(String cameraCode) throws Exception {
        RtspStreamSession session = openStream(cameraCode);
        return session.takeSnapshot();
    }

    private void checkIdleSessions() {
        int idleTimeout = videoProperties.getRtsp().getIdleTimeout();
        int removedCount = 0;

        for (Map.Entry<String, RtspStreamSession> entry : sessions.entrySet()) {
            RtspStreamSession session = entry.getValue();
            if (session.isIdle(idleTimeout)) {
                try {
                    session.stop();
                    sessions.remove(entry.getKey());
                    removedCount++;
                    log.info("空闲超时，自动关闭RTSP流: {}", entry.getKey());
                } catch (Exception e) {
                    log.error("关闭空闲RTSP流失败: {}", entry.getKey(), e);
                }
            }
        }

        if (removedCount > 0) {
            log.info("空闲检查完成，移除了 {} 个空闲流，当前在线流数量: {}", removedCount, sessions.size());
        }
    }

    public int getActiveStreamCount() {
        return sessions.size();
    }

    public Map<String, RtspStreamSession> getAllSessions() {
        return sessions;
    }
}
