package com.waste.controller;

import cn.hutool.core.util.StrUtil;
import com.waste.common.Result;
import com.waste.config.VideoProperties;
import com.waste.dto.HuaweiAiCallbackDTO;
import com.waste.entity.AiCaptureEvent;
import com.waste.entity.Camera;
import com.waste.mapper.CameraMapper;
import com.waste.service.AiCaptureEventService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/ai-capture")
public class HuaweiAiCallbackController {

    @Autowired
    private AiCaptureEventService aiCaptureEventService;

    @Autowired
    private CameraMapper cameraMapper;

    @Autowired
    private VideoProperties videoProperties;

    @PostMapping("/callback")
    public Result<Void> aiCallback(@RequestBody HuaweiAiCallbackDTO callbackDTO) {
        try {
            log.info("收到华为云AI回调: taskId={}, cameraCode={}, eventCount={}",
                    callbackDTO.getTaskId(),
                    callbackDTO.getCameraCode(),
                    callbackDTO.getResults() != null ? callbackDTO.getResults().size() : 0);

            if (!verifySignature(callbackDTO)) {
                log.warn("AI回调签名验证失败");
                return Result.error("签名验证失败");
            }

            String cameraCode = callbackDTO.getCameraCode();
            if (StrUtil.isBlank(cameraCode)) {
                cameraCode = extractCameraCode(callbackDTO.getStreamName());
            }

            Camera camera = null;
            if (StrUtil.isNotBlank(cameraCode)) {
                camera = cameraMapper.selectOne(
                        new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<Camera>()
                                .eq(Camera::getCameraCode, cameraCode)
                );
            }

            int threshold = videoProperties.getHuaweiAi().getCaptureConfidenceThreshold();

            List<AiCaptureEvent> events = new ArrayList<>();

            if (callbackDTO.getResults() != null && !callbackDTO.getResults().isEmpty()) {
                for (HuaweiAiCallbackDTO.AiEventResult result : callbackDTO.getResults()) {
                    if (result.getConfidence() == null || result.getConfidence() < threshold) {
                        log.debug("置信度低于阈值，跳过: type={}, confidence={}", result.getEventType(), result.getConfidence());
                        continue;
                    }

                    AiCaptureEvent event = new AiCaptureEvent();
                    event.setEventNo(UUID.randomUUID().toString().replace("-", ""));
                    event.setEventType(result.getEventType());
                    event.setEventCategory(result.getEventCategory());
                    event.setConfidence(result.getConfidence());
                    event.setSnapshotPath(callbackDTO.getSnapshotUrl());
                    event.setVideoClipPath(callbackDTO.getVideoUrl());
                    event.setDetail(result.getDetail());
                    event.setHandleStatus(0);
                    event.setPushStatus(0);

                    if (callbackDTO.getTimestamp() != null) {
                        event.setCaptureTime(LocalDateTime.ofInstant(
                                java.time.Instant.ofEpochMilli(callbackDTO.getTimestamp()),
                                ZoneId.systemDefault()
                        ));
                    } else {
                        event.setCaptureTime(LocalDateTime.now());
                    }

                    if (camera != null) {
                        event.setCameraId(camera.getId());
                        event.setCameraCode(camera.getCameraCode());
                        event.setCameraName(camera.getCameraName());
                        event.setEnterpriseId(camera.getEnterpriseId());
                    } else if (StrUtil.isNotBlank(cameraCode)) {
                        event.setCameraCode(cameraCode);
                    }

                    events.add(event);
                }
            }

            if (!events.isEmpty()) {
                aiCaptureEventService.batchAddFromAi(events);
                log.info("AI事件入库完成，数量: {}", events.size());
            } else {
                log.info("没有符合条件的AI事件");
            }

            return Result.success();
        } catch (Exception e) {
            log.error("处理AI回调失败: {}", e.getMessage(), e);
            return Result.error("处理AI回调失败: " + e.getMessage());
        }
    }

    private boolean verifySignature(HuaweiAiCallbackDTO dto) {
        if (StrUtil.isBlank(videoProperties.getHuaweiAi().getSk())) {
            return true;
        }
        return true;
    }

    private String extractCameraCode(String streamName) {
        if (StrUtil.isBlank(streamName)) {
            return null;
        }
        return streamName;
    }

    @GetMapping("/test/callback")
    public Result<Void> testCallback(@RequestParam String cameraCode,
                                      @RequestParam(defaultValue = "no_goggles") String eventType,
                                      @RequestParam(defaultValue = "85") Integer confidence) {
        try {
            HuaweiAiCallbackDTO dto = new HuaweiAiCallbackDTO();
            dto.setTaskId("test-task-001");
            dto.setCameraCode(cameraCode);
            dto.setStreamName(cameraCode);
            dto.setTimestamp(System.currentTimeMillis());
            dto.setSnapshotUrl("/video/snapshot/" + cameraCode);

            HuaweiAiCallbackDTO.AiEventResult result = new HuaweiAiCallbackDTO.AiEventResult();
            result.setEventType(eventType);
            result.setEventCategory("safety_violation");
            result.setEventName(getEventName(eventType));
            result.setConfidence(confidence);
            result.setDetail("检测到违规行为: " + getEventName(eventType));

            dto.setResults(java.util.Collections.singletonList(result));

            return aiCallback(dto);
        } catch (Exception e) {
            return Result.error("测试失败: " + e.getMessage());
        }
    }

    private String getEventName(String eventType) {
        switch (eventType) {
            case "no_goggles":
                return "未戴护目镜";
            case "forklift_speeding":
                return "叉车超速";
            case "no_helmet":
                return "未戴安全帽";
            case "no_safety_shoes":
                return "未穿安全鞋";
            case "smoking":
                return "吸烟";
            case "intrusion":
                return "违规闯入";
            case "fight":
                return "打架斗殴";
            default:
                return eventType;
        }
    }
}
