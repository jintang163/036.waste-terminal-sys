package com.waste.controller;

import com.waste.common.Result;
import com.waste.config.VideoProperties;
import com.waste.video.RtspProxyService;
import com.waste.video.RtspStreamSession;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.io.File;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/video")
public class VideoStreamController {

    @Autowired
    private RtspProxyService rtspProxyService;

    @Autowired
    private VideoProperties videoProperties;

    @GetMapping("/hls/{cameraCode}/stream.m3u8")
    public ResponseEntity<Resource> getHlsPlaylist(@PathVariable String cameraCode,
                                                    HttpServletRequest request) {
        try {
            RtspStreamSession session = rtspProxyService.openStream(cameraCode);
            if (session == null || !session.isAlive()) {
                return ResponseEntity.notFound().build();
            }

            String hlsPath = videoProperties.getRtsp().getHlsStoragePath() + "/" + cameraCode + "/stream.m3u8";
            File file = new File(hlsPath);
            if (!file.exists()) {
                log.warn("[{}] HLS播放列表文件不存在，等待生成...", cameraCode);
                Thread.sleep(2000);
                if (!file.exists()) {
                    return ResponseEntity.notFound().build();
                }
            }

            Resource resource = new FileSystemResource(file);

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType("application/vnd.apple.mpegurl"))
                    .header(HttpHeaders.CACHE_CONTROL, "no-cache")
                    .body(resource);
        } catch (Exception e) {
            log.error("[{}] 获取HLS播放列表失败: {}", cameraCode, e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    @GetMapping("/hls/{cameraCode}/{segment}.ts")
    public ResponseEntity<Resource> getHlsSegment(@PathVariable String cameraCode,
                                                   @PathVariable String segment) {
        try {
            String segmentPath = videoProperties.getRtsp().getHlsStoragePath() + "/" + cameraCode + "/" + segment + ".ts";
            File file = new File(segmentPath);
            if (!file.exists()) {
                return ResponseEntity.notFound().build();
            }

            Resource resource = new FileSystemResource(file);

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType("video/mp2t"))
                    .header(HttpHeaders.CACHE_CONTROL, "max-age=60")
                    .body(resource);
        } catch (Exception e) {
            log.error("[{}] 获取HLS分片失败: {}", cameraCode, e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    @GetMapping("/preview/{cameraCode}")
    public Result<Map<String, Object>> getPreviewUrl(@PathVariable String cameraCode) {
        try {
            RtspStreamSession session = rtspProxyService.openStream(cameraCode);

            Map<String, Object> data = new HashMap<>();
            data.put("cameraCode", cameraCode);
            data.put("hlsUrl", "/video/hls/" + cameraCode + "/stream.m3u8");
            data.put("rtspUrl", session.getRtspUrl());
            data.put("status", session.isAlive() ? "online" : "offline");
            data.put("width", session.getWidth());
            data.put("height", session.getHeight());
            data.put("frameRate", session.getFrameRate());

            return Result.success(data);
        } catch (Exception e) {
            log.error("[{}] 获取预览地址失败: {}", cameraCode, e.getMessage());
            return Result.error("获取预览地址失败: " + e.getMessage());
        }
    }

    @GetMapping("/snapshot/{cameraCode}")
    public ResponseEntity<Resource> getSnapshot(@PathVariable String cameraCode) {
        try {
            String snapshotPath = rtspProxyService.takeSnapshot(cameraCode);
            File file = new File(snapshotPath);
            if (!file.exists()) {
                return ResponseEntity.notFound().build();
            }

            Resource resource = new FileSystemResource(file);

            return ResponseEntity.ok()
                    .contentType(MediaType.IMAGE_JPEG)
                    .header(HttpHeaders.CACHE_CONTROL, "no-cache")
                    .body(resource);
        } catch (Exception e) {
            log.error("[{}] 获取抓拍图片失败: {}", cameraCode, e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    @PostMapping("/stream/open/{cameraCode}")
    public Result<Void> openStream(@PathVariable String cameraCode) {
        try {
            rtspProxyService.openStream(cameraCode);
            return Result.success();
        } catch (Exception e) {
            log.error("[{}] 打开RTSP流失败: {}", cameraCode, e.getMessage());
            return Result.error("打开RTSP流失败: " + e.getMessage());
        }
    }

    @PostMapping("/stream/close/{cameraCode}")
    public Result<Void> closeStream(@PathVariable String cameraCode) {
        try {
            rtspProxyService.closeStream(cameraCode);
            return Result.success();
        } catch (Exception e) {
            log.error("[{}] 关闭RTSP流失败: {}", cameraCode, e.getMessage());
            return Result.error("关闭RTSP流失败: " + e.getMessage());
        }
    }

    @GetMapping("/stream/status")
    public Result<Map<String, Object>> getStreamStatus() {
        Map<String, Object> data = new HashMap<>();
        data.put("activeCount", rtspProxyService.getActiveStreamCount());
        data.put("sessions", rtspProxyService.getAllSessions().keySet());
        return Result.success(data);
    }
}
