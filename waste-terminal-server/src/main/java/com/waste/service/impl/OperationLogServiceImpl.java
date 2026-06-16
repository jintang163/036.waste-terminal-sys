package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.OperationLog;
import com.waste.mapper.OperationLogMapper;
import com.waste.service.OperationLogService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class OperationLogServiceImpl implements OperationLogService {

    @Autowired
    private OperationLogMapper operationLogMapper;

    private LambdaQueryWrapper<OperationLog> buildQueryWrapper(OperationLog queryLog, Long enterpriseId) {
        LambdaQueryWrapper<OperationLog> wrapper = new LambdaQueryWrapper<>();
        if (StrUtil.isNotBlank(queryLog.getDeviceId())) {
            wrapper.eq(OperationLog::getDeviceId, queryLog.getDeviceId());
        }
        if (queryLog.getUserId() != null) {
            wrapper.eq(OperationLog::getUserId, queryLog.getUserId());
        }
        if (StrUtil.isNotBlank(queryLog.getLevel())) {
            wrapper.eq(OperationLog::getLevel, queryLog.getLevel());
        }
        if (StrUtil.isNotBlank(queryLog.getCategory())) {
            wrapper.eq(OperationLog::getCategory, queryLog.getCategory());
        }
        if (StrUtil.isNotBlank(queryLog.getModule())) {
            wrapper.eq(OperationLog::getModule, queryLog.getModule());
        }
        if (enterpriseId != null) {
            wrapper.eq(OperationLog::getEnterpriseId, enterpriseId);
        }
        return wrapper;
    }

    @Override
    public IPage<OperationLog> page(PageQuery pageQuery, OperationLog queryLog, Long enterpriseId) {
        Page<OperationLog> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<OperationLog> wrapper = buildQueryWrapper(queryLog, enterpriseId);
        wrapper.orderByDesc(OperationLog::getOperationTime);
        return operationLogMapper.selectPage(page, wrapper);
    }

    @Override
    public OperationLog getById(Long id) {
        OperationLog opLog = operationLogMapper.selectById(id);
        if (opLog == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return opLog;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(OperationLog operationLog) {
        LocalDateTime now = LocalDateTime.now();
        if (operationLog.getOperationTime() == null) {
            operationLog.setOperationTime(now);
        }
        if (operationLog.getSyncStatus() == null) {
            operationLog.setSyncStatus(2);
        }
        if (operationLog.getUploadTime() == null) {
            operationLog.setUploadTime(now);
        }
        if (operationLog.getCreateTime() == null) {
            operationLog.setCreateTime(now);
        }
        if (operationLog.getUpdateTime() == null) {
            operationLog.setUpdateTime(now);
        }
        operationLogMapper.insert(operationLog);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> batchUpload(List<Map<String, Object>> logDataList) {
        Map<String, Object> result = new HashMap<>();
        int successCount = 0;
        int failCount = 0;
        List<String> failedLogIds = new ArrayList<>();
        LocalDateTime uploadTime = LocalDateTime.now();
        DateTimeFormatter formatter = DateTimeFormatter.ISO_DATE_TIME;

        for (Map<String, Object> logData : logDataList) {
            try {
                OperationLog opLog = convertToEntity(logData, uploadTime, formatter);
                operationLogMapper.insert(opLog);
                successCount++;
            } catch (Exception e) {
                failCount++;
                Object logIdObj = logData.get("logId");
                if (logIdObj != null) {
                    failedLogIds.add(logIdObj.toString());
                }
                log.warn("单条日志上传失败: logId={}, error={}", logIdObj, e.getMessage());
            }
        }

        result.put("success", failCount == 0);
        result.put("totalCount", logDataList.size());
        result.put("successCount", successCount);
        result.put("failCount", failCount);
        result.put("uploadTime", uploadTime.toString());
        if (!failedLogIds.isEmpty()) {
            result.put("failedLogIds", failedLogIds);
        }

        log.info("运维日志批量上传完成: total={}, success={}, fail={}",
                logDataList.size(), successCount, failCount);

        return result;
    }

    private OperationLog convertToEntity(Map<String, Object> logData,
                                          LocalDateTime uploadTime,
                                          DateTimeFormatter formatter) {
        OperationLog opLog = new OperationLog();

        String clientLogId = getStrValue(logData, "logId");
        if (clientLogId == null) {
            clientLogId = getStrValue(logData, "id");
        }
        opLog.setLogId(clientLogId);
        opLog.setDeviceId(getStrValue(logData, "deviceId"));
        opLog.setDeviceName(getStrValue(logData, "deviceName"));
        opLog.setUsername(getStrValue(logData, "username"));

        Object userIdObj = logData.get("userId");
        if (userIdObj != null) {
            if (userIdObj instanceof Number) {
                opLog.setUserId(((Number) userIdObj).longValue());
            } else if (userIdObj instanceof String && StrUtil.isNotBlank((String) userIdObj)) {
                try {
                    opLog.setUserId(Long.parseLong((String) userIdObj));
                } catch (NumberFormatException ignored) {}
            }
        }

        Object enterpriseIdObj = logData.get("enterpriseId");
        if (enterpriseIdObj != null) {
            if (enterpriseIdObj instanceof Number) {
                opLog.setEnterpriseId(((Number) enterpriseIdObj).longValue());
            } else if (enterpriseIdObj instanceof String && StrUtil.isNotBlank((String) enterpriseIdObj)) {
                try {
                    opLog.setEnterpriseId(Long.parseLong((String) enterpriseIdObj));
                } catch (NumberFormatException ignored) {}
            }
        }

        opLog.setLevel(getStrValue(logData, "level", "info"));
        opLog.setCategory(getStrValue(logData, "category"));
        opLog.setModule(getStrValue(logData, "module"));
        opLog.setAction(getStrValue(logData, "action"));
        opLog.setMessage(getStrValue(logData, "message"));

        Object extraObj = logData.get("extra");
        if (extraObj instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> extraMap = (Map<String, Object>) extraObj;
            opLog.setExtra(extraMap);
        }

        Object isOfflineObj = logData.get("isOffline");
        if (isOfflineObj instanceof Boolean) {
            opLog.setIsOffline((Boolean) isOfflineObj ? 1 : 0);
        } else if (isOfflineObj instanceof Number) {
            opLog.setIsOffline(((Number) isOfflineObj).intValue());
        } else {
            opLog.setIsOffline(0);
        }

        opLog.setSyncStatus(2);
        opLog.setUploadTime(uploadTime);

        Object timestampObj = logData.get("timestamp");
        if (timestampObj != null) {
            try {
                LocalDateTime opTime;
                if (timestampObj instanceof Number) {
                    long millis = ((Number) timestampObj).longValue();
                    opTime = LocalDateTime.ofInstant(
                            java.time.Instant.ofEpochMilli(millis),
                            ZoneId.systemDefault()
                    );
                } else if (timestampObj instanceof String) {
                    String tsStr = (String) timestampObj;
                    try {
                        if (tsStr.endsWith("Z")) {
                            ZonedDateTime zdt = ZonedDateTime.parse(tsStr);
                            opTime = zdt.withZoneSameInstant(ZoneId.systemDefault()).toLocalDateTime();
                        } else {
                            opTime = LocalDateTime.parse(tsStr, formatter);
                        }
                    } catch (Exception e) {
                        opTime = uploadTime;
                    }
                } else {
                    opTime = uploadTime;
                }
                opLog.setOperationTime(opTime);
            } catch (Exception e) {
                opLog.setOperationTime(uploadTime);
            }
        } else {
            opLog.setOperationTime(uploadTime);
        }

        opLog.setCreateTime(uploadTime);
        opLog.setUpdateTime(uploadTime);

        return opLog;
    }

    private String getStrValue(Map<String, Object> map, String key) {
        return getStrValue(map, key, null);
    }

    private String getStrValue(Map<String, Object> map, String key, String defaultValue) {
        Object obj = map.get(key);
        if (obj == null) return defaultValue;
        String str = obj.toString();
        return StrUtil.isBlank(str) ? defaultValue : str;
    }
}
