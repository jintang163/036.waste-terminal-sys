package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.TransportWarningDTO;
import com.waste.entity.TransportTrack;
import com.waste.entity.TransportWarning;
import com.waste.mapper.TransportTrackMapper;
import com.waste.mapper.TransportWarningMapper;
import com.waste.service.TransportWarningService;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.UserContext;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class TransportWarningServiceImpl implements TransportWarningService {

    @Autowired
    private TransportWarningMapper transportWarningMapper;

    @Autowired
    private TransportTrackMapper transportTrackMapper;

    @Override
    public IPage<TransportWarning> page(PageQuery pageQuery, TransportWarning transportWarning, Long enterpriseId) {
        Page<TransportWarning> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<TransportWarning> wrapper = buildQueryWrapper(transportWarning, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(TransportWarning::getCreateTime);
        }
        return transportWarningMapper.selectPage(page, wrapper);
    }

    @Override
    public TransportWarning getById(Long id) {
        TransportWarning warning = transportWarningMapper.selectById(id);
        if (warning == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return warning;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void createWarning(TransportWarningDTO dto, Long enterpriseId) {
        TransportWarning warning = new TransportWarning();
        BeanUtils.copyProperties(dto, warning);
        warning.setWarningNo(IdGeneratorUtils.generateWarningNo());
        warning.setTriggerTime(dto.getTriggerTime() != null ? dto.getTriggerTime() : LocalDateTime.now());
        warning.setHandleStatus(0);
        warning.setPushStatus(0);
        warning.setWarningCount(1);
        warning.setLastWarningTime(warning.getTriggerTime());
        if (enterpriseId != null) {
            warning.setEnterpriseId(enterpriseId);
        }
        transportWarningMapper.insert(warning);

        try {
            pushWarning(warning);
        } catch (Exception e) {
            log.error("推送告警失败, warningId={}", warning.getId(), e);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void handleWarning(Long id, TransportWarningDTO dto) {
        TransportWarning warning = getById(id);
        if (warning.getHandleStatus() == 1) {
            throw new BusinessException("告警已处理，请勿重复操作");
        }

        warning.setHandleStatus(1);
        warning.setHandleTime(LocalDateTime.now());
        warning.setHandleRemark(dto.getHandleRemark());

        Long currentUserId = UserContext.getCurrentUserId();
        String currentUserName = UserContext.getCurrentUsername();
        if (dto.getHandleUserId() != null) {
            warning.setHandleUserId(dto.getHandleUserId());
        } else if (currentUserId != null) {
            warning.setHandleUserId(currentUserId);
        }
        if (dto.getHandleUserName() != null) {
            warning.setHandleUserName(dto.getHandleUserName());
        } else if (currentUserName != null) {
            warning.setHandleUserName(currentUserName);
        }

        transportWarningMapper.updateById(warning);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public List<TransportWarning> checkTransportTimeout() {
        log.info("开始执行运输超时检测");
        List<TransportWarning> warnings = new ArrayList<>();

        LambdaQueryWrapper<TransportTrack> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportTrack::getStatus, 1);
        wrapper.isNotNull(TransportTrack::getStartTime);
        List<TransportTrack> activeTracks = transportTrackMapper.selectList(wrapper);

        if (activeTracks == null || activeTracks.isEmpty()) {
            log.info("没有进行中的运输任务");
            return warnings;
        }

        LocalDateTime now = LocalDateTime.now();
        for (TransportTrack track : activeTracks) {
            try {
                BigDecimal thresholdHours = resolveThresholdHours(track);
                boolean isTimeoutByDuration = false;
                boolean isTimeoutByArrival = false;
                long hoursElapsed = 0;
                String timeoutReason = "";

                if (track.getExpectedArrivalTime() != null) {
                    if (now.isAfter(track.getExpectedArrivalTime())) {
                        isTimeoutByArrival = true;
                        Duration d = Duration.between(track.getExpectedArrivalTime(), now);
                        hoursElapsed = Math.max(1L, d.toHours());
                        timeoutReason = "超过预计到达时间" + hoursElapsed + "小时";
                    }
                }

                if (!isTimeoutByArrival && track.getStartTime() != null) {
                    Duration duration = Duration.between(track.getStartTime(), now);
                    hoursElapsed = duration.toHours();
                    BigDecimal elapsed = BigDecimal.valueOf(hoursElapsed);
                    if (elapsed.compareTo(thresholdHours) >= 0) {
                        isTimeoutByDuration = true;
                        timeoutReason = "运输时长已达" + hoursElapsed + "小时，超过预计"
                                + (thresholdHours.compareTo(BigDecimal.valueOf(24)) == 0 ? "默认24小时" : thresholdHours.stripTrailingZeros().toPlainString() + "小时");
                    }
                }

                if (isTimeoutByDuration || isTimeoutByArrival) {
                    boolean existingWarning = checkExistingWarning(track.getId(), "TIMEOUT", thresholdHours);

                    if (!existingWarning) {
                        TransportWarning warning = new TransportWarning();
                        warning.setWarningNo(IdGeneratorUtils.generateWarningNo());
                        warning.setWarningType("TIMEOUT");
                        warning.setWarningLevel(2);
                        warning.setTransferOrderId(track.getTransferOrderId());
                        warning.setTransferOrderNo(track.getTransferOrderNo());
                        warning.setVehicleId(track.getVehicleId());
                        warning.setVehicleNo(track.getVehicleNo());
                        warning.setDriverId(track.getDriverId());
                        warning.setDriverName(track.getDriverName());
                        warning.setTrackId(track.getId());
                        warning.setWarningContent("运输任务已超时，" + timeoutReason);
                        warning.setTriggerTime(now);
                        warning.setTriggerValue(BigDecimal.valueOf(hoursElapsed));
                        warning.setThresholdValue(thresholdHours);
                        warning.setHandleStatus(0);
                        warning.setPushStatus(0);
                        warning.setWarningCount(1);
                        warning.setLastWarningTime(now);
                        warning.setEnterpriseId(track.getEnterpriseId());
                        transportWarningMapper.insert(warning);

                        try {
                            pushWarning(warning);
                        } catch (Exception e) {
                            log.error("推送超时告警失败, trackId={}", track.getId(), e);
                        }

                        warnings.add(warning);
                        log.info("生成运输超时告警, trackId={}, trackNo={}, 已用时长={}h, 阈值={}h",
                                track.getId(), track.getTrackNo(), hoursElapsed, thresholdHours);
                    } else {
                        incrementWarningCount(track.getId(), "TIMEOUT", thresholdHours);
                    }
                }
            } catch (Exception e) {
                log.error("检测运输超时失败, trackId={}", track.getId(), e);
            }
        }

        log.info("运输超时检测完成，生成{}条告警", warnings.size());
        return warnings;
    }

    private BigDecimal resolveThresholdHours(TransportTrack track) {
        if (track.getExpectedDurationHours() != null
                && track.getExpectedDurationHours().compareTo(BigDecimal.ZERO) > 0) {
            return track.getExpectedDurationHours();
        }
        return BigDecimal.valueOf(24);
    }

    private boolean checkExistingWarning(Long trackId, String warningType, BigDecimal thresholdValue) {
        LambdaQueryWrapper<TransportWarning> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportWarning::getTrackId, trackId);
        wrapper.eq(TransportWarning::getWarningType, warningType);
        wrapper.eq(TransportWarning::getThresholdValue, thresholdValue);
        wrapper.ge(TransportWarning::getCreateTime, LocalDateTime.now().minusHours(1));
        Long count = transportWarningMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    private void incrementWarningCount(Long trackId, String warningType, BigDecimal thresholdValue) {
        LambdaQueryWrapper<TransportWarning> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportWarning::getTrackId, trackId);
        wrapper.eq(TransportWarning::getWarningType, warningType);
        wrapper.eq(TransportWarning::getThresholdValue, thresholdValue);
        wrapper.orderByDesc(TransportWarning::getCreateTime);
        wrapper.last("LIMIT 1");
        TransportWarning warning = transportWarningMapper.selectOne(wrapper);
        if (warning != null) {
            warning.setWarningCount(warning.getWarningCount() + 1);
            warning.setLastWarningTime(LocalDateTime.now());
            transportWarningMapper.updateById(warning);
        }
    }

    private void pushWarning(TransportWarning warning) {
        warning.setPushStatus(1);
        warning.setPushTime(LocalDateTime.now());
        transportWarningMapper.updateById(warning);
        log.info("告警推送成功, warningNo={}, type={}", warning.getWarningNo(), warning.getWarningType());
    }

    private LambdaQueryWrapper<TransportWarning> buildQueryWrapper(TransportWarning transportWarning, Long enterpriseId) {
        LambdaQueryWrapper<TransportWarning> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(TransportWarning::getEnterpriseId, enterpriseId);
        }
        if (transportWarning != null) {
            if (StrUtil.isNotBlank(transportWarning.getWarningNo())) {
                wrapper.like(TransportWarning::getWarningNo, transportWarning.getWarningNo());
            }
            if (StrUtil.isNotBlank(transportWarning.getWarningType())) {
                wrapper.eq(TransportWarning::getWarningType, transportWarning.getWarningType());
            }
            if (transportWarning.getWarningLevel() != null) {
                wrapper.eq(TransportWarning::getWarningLevel, transportWarning.getWarningLevel());
            }
            if (StrUtil.isNotBlank(transportWarning.getVehicleNo())) {
                wrapper.like(TransportWarning::getVehicleNo, transportWarning.getVehicleNo());
            }
            if (StrUtil.isNotBlank(transportWarning.getDriverName())) {
                wrapper.like(TransportWarning::getDriverName, transportWarning.getDriverName());
            }
            if (transportWarning.getHandleStatus() != null) {
                wrapper.eq(TransportWarning::getHandleStatus, transportWarning.getHandleStatus());
            }
            if (transportWarning.getPushStatus() != null) {
                wrapper.eq(TransportWarning::getPushStatus, transportWarning.getPushStatus());
            }
            if (transportWarning.getTrackId() != null) {
                wrapper.eq(TransportWarning::getTrackId, transportWarning.getTrackId());
            }
            if (transportWarning.getTransferOrderId() != null) {
                wrapper.eq(TransportWarning::getTransferOrderId, transportWarning.getTransferOrderId());
            }
        }
        return wrapper;
    }
}
