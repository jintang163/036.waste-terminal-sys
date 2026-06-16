package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.TransportTrackDTO;
import com.waste.entity.TransportTrack;
import com.waste.entity.TransportTrackPoint;
import com.waste.entity.TransportVehicle;
import com.waste.mapper.TransportTrackMapper;
import com.waste.mapper.TransportTrackPointMapper;
import com.waste.mapper.TransportVehicleMapper;
import com.waste.service.TransportTrackService;
import com.waste.utils.IdGeneratorUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class TransportTrackServiceImpl implements TransportTrackService {

    @Autowired
    private TransportTrackMapper transportTrackMapper;

    @Autowired
    private TransportTrackPointMapper transportTrackPointMapper;

    @Autowired
    private TransportVehicleMapper transportVehicleMapper;

    @Autowired
    private com.waste.service.AmapTrackService amapTrackService;

    @Override
    public IPage<TransportTrack> page(PageQuery pageQuery, TransportTrack transportTrack, Long enterpriseId) {
        Page<TransportTrack> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<TransportTrack> wrapper = buildQueryWrapper(transportTrack, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(TransportTrack::getCreateTime);
        }
        return transportTrackMapper.selectPage(page, wrapper);
    }

    @Override
    public TransportTrack getById(Long id) {
        TransportTrack track = transportTrackMapper.selectById(id);
        if (track == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return track;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public TransportTrack createTrack(TransportTrackDTO dto, Long enterpriseId) {
        if (dto.getVehicleId() == null) {
            throw new BusinessException("车辆ID不能为空");
        }
        TransportVehicle vehicle = transportVehicleMapper.selectById(dto.getVehicleId());
        if (vehicle == null) {
            throw new BusinessException(ResultCode.NOT_FOUND, "车辆不存在");
        }

        TransportTrack currentTrack = getCurrentTrack(dto.getVehicleId(), enterpriseId);
        if (currentTrack != null && currentTrack.getStatus() == 1) {
            throw new BusinessException("该车辆当前有未完成的运输任务");
        }

        TransportTrack track = new TransportTrack();
        BeanUtils.copyProperties(dto, track);
        track.setTrackNo(IdGeneratorUtils.generateTrackNo());
        track.setVehicleNo(vehicle.getVehicleNo());
        track.setAmapServiceId(vehicle.getAmapServiceId());
        track.setAmapTerminalId(vehicle.getAmapTerminalId());
        track.setStatus(0);
        track.setPointCount(0);
        track.setTotalDistance(BigDecimal.ZERO);
        track.setTotalDuration(0);
        track.setOfflinePoints(0);
        track.setSyncedToAmap(0);
        if (track.getExpectedDurationHours() == null
                || track.getExpectedDurationHours().compareTo(BigDecimal.ZERO) <= 0) {
            track.setExpectedDurationHours(BigDecimal.valueOf(24));
        }
        if (enterpriseId != null) {
            track.setEnterpriseId(enterpriseId);
        }
        transportTrackMapper.insert(track);

        return track;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void startTransport(Long trackId, TransportTrackDTO.TrackPointDTO startPoint) {
        TransportTrack track = getById(trackId);
        if (track.getStatus() == 1) {
            throw new BusinessException("运输已开始，请勿重复操作");
        }
        if (track.getStatus() == 2) {
            throw new BusinessException("运输已结束，无法重新开始");
        }

        if (startPoint != null) {
            track.setStartTime(startPoint.getGpsTime() != null ? startPoint.getGpsTime() : LocalDateTime.now());
            track.setStartLocation(startPoint.getLocation());
            track.setStartLng(startPoint.getLng());
            track.setStartLat(startPoint.getLat());
            track.setCurrentLocation(startPoint.getLocation());
            track.setCurrentLng(startPoint.getLng());
            track.setCurrentLat(startPoint.getLat());
            track.setLastGpsTime(startPoint.getGpsTime());
            track.setLastUpdateSource(startPoint.getSourceType());

            addTrackPointInternal(track, startPoint);
        } else {
            track.setStartTime(LocalDateTime.now());
        }
        track.setStatus(1);
        if (track.getExpectedDurationHours() == null
                || track.getExpectedDurationHours().compareTo(BigDecimal.ZERO) <= 0) {
            track.setExpectedDurationHours(BigDecimal.valueOf(24));
        }
        if (track.getExpectedArrivalTime() == null && track.getStartTime() != null) {
            long hoursToAdd = Math.max(1L, track.getExpectedDurationHours().longValue());
            track.setExpectedArrivalTime(track.getStartTime().plusHours(hoursToAdd));
        }
        transportTrackMapper.updateById(track);

        if (StrUtil.isNotBlank(track.getAmapServiceId()) && StrUtil.isNotBlank(track.getAmapTerminalId())) {
            try {
                String amapTrackId = amapTrackService.createTrack(
                        track.getAmapServiceId(),
                        track.getAmapTerminalId(),
                        track.getTrackNo()
                );
                if (StrUtil.isNotBlank(amapTrackId)) {
                    track.setAmapTrackId(amapTrackId);
                    transportTrackMapper.updateById(track);
                }
            } catch (Exception e) {
                log.error("创建高德猎鹰轨迹失败, trackId={}, trackNo={}", track.getId(), track.getTrackNo(), e);
            }
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void endTransport(Long trackId, TransportTrackDTO.TrackPointDTO endPoint) {
        TransportTrack track = getById(trackId);
        if (track.getStatus() == 0) {
            throw new BusinessException("运输尚未开始");
        }
        if (track.getStatus() == 2) {
            throw new BusinessException("运输已结束，请勿重复操作");
        }

        if (endPoint != null) {
            track.setEndTime(endPoint.getGpsTime() != null ? endPoint.getGpsTime() : LocalDateTime.now());
            track.setEndLocation(endPoint.getLocation());
            track.setEndLng(endPoint.getLng());
            track.setEndLat(endPoint.getLat());
            track.setCurrentLocation(endPoint.getLocation());
            track.setCurrentLng(endPoint.getLng());
            track.setCurrentLat(endPoint.getLat());
            track.setLastGpsTime(endPoint.getGpsTime());
            track.setLastUpdateSource(endPoint.getSourceType());

            addTrackPointInternal(track, endPoint);
        } else {
            track.setEndTime(LocalDateTime.now());
        }
        track.setStatus(2);

        if (track.getStartTime() != null && track.getEndTime() != null) {
            long duration = java.time.Duration.between(track.getStartTime(), track.getEndTime()).getSeconds();
            track.setTotalDuration((int) duration);
        }

        transportTrackMapper.updateById(track);

        syncOfflinePoints(trackId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void addTrackPoint(Long trackId, TransportTrackDTO.TrackPointDTO pointDTO) {
        TransportTrack track = getById(trackId);
        if (track.getStatus() != 1) {
            throw new BusinessException("运输未进行中，无法添加轨迹点");
        }

        addTrackPointInternal(track, pointDTO);

        track.setCurrentLocation(pointDTO.getLocation());
        track.setCurrentLng(pointDTO.getLng());
        track.setCurrentLat(pointDTO.getLat());
        track.setLastGpsTime(pointDTO.getGpsTime());
        track.setLastUpdateSource(pointDTO.getSourceType());
        if (pointDTO.getIsOffline() != null && pointDTO.getIsOffline() == 1) {
            track.setOfflinePoints(track.getOfflinePoints() + 1);
        }
        transportTrackMapper.updateById(track);

        if (StrUtil.isNotBlank(track.getAmapTrackId()) && (pointDTO.getIsOffline() == null || pointDTO.getIsOffline() == 0)) {
            try {
                amapTrackService.uploadPoint(
                        track.getAmapServiceId(),
                        track.getAmapTerminalId(),
                        track.getAmapTrackId(),
                        pointDTO
                );
            } catch (Exception e) {
                log.error("上报轨迹点到高德猎鹰失败, trackId={}", trackId, e);
            }
        }
    }

    @Override
    public List<TransportTrackPoint> getTrackPoints(Long trackId) {
        LambdaQueryWrapper<TransportTrackPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportTrackPoint::getTrackId, trackId);
        wrapper.orderByAsc(TransportTrackPoint::getGpsTime);
        return transportTrackPointMapper.selectList(wrapper);
    }

    @Override
    public List<TransportTrackPoint> replayTrack(Long trackId) {
        TransportTrack track = getById(trackId);
        if (track == null) {
            return new ArrayList<>();
        }

        List<TransportTrackPoint> amapPoints = fetchAmapTrackPoints(track);
        if (CollUtil.isNotEmpty(amapPoints)) {
            log.info("轨迹回放使用高德猎鹰数据, trackId={}, 点数={}", trackId, amapPoints.size());
            return amapPoints;
        }

        log.info("轨迹回放使用本地数据库数据, trackId={}", trackId);
        return getTrackPoints(trackId);
    }

    private List<TransportTrackPoint> fetchAmapTrackPoints(TransportTrack track) {
        List<TransportTrackPoint> result = new ArrayList<>();
        if (StrUtil.isBlank(track.getAmapServiceId())
                || StrUtil.isBlank(track.getAmapTerminalId())) {
            return result;
        }

        try {
            Long startTime = null;
            Long endTime = null;
            if (track.getStartTime() != null) {
                startTime = track.getStartTime().atZone(ZoneId.systemDefault()).toInstant().getEpochSecond();
            }
            if (track.getEndTime() != null) {
                endTime = track.getEndTime().atZone(ZoneId.systemDefault()).toInstant().getEpochSecond();
            }

            List<Map<String, Object>> amapPoints;
            if (StrUtil.isNotBlank(track.getAmapTrackId())) {
                amapPoints = amapTrackService.queryTrack(
                        track.getAmapServiceId(),
                        track.getAmapTerminalId(),
                        track.getAmapTrackId(),
                        startTime,
                        endTime
                );
            } else {
                amapPoints = amapTrackService.queryTerminalTrack(
                        track.getAmapServiceId(),
                        track.getAmapTerminalId(),
                        startTime,
                        endTime
                );
            }

            if (CollUtil.isNotEmpty(amapPoints)) {
                int seq = 0;
                for (Map<String, Object> pointMap : amapPoints) {
                    TransportTrackPoint point = convertAmapPoint(pointMap, track, ++seq);
                    if (point != null) {
                        result.add(point);
                    }
                }
            }
        } catch (Exception e) {
            log.error("从高德猎鹰获取轨迹数据异常, trackId={}", track.getId(), e);
        }
        return result;
    }

    private TransportTrackPoint convertAmapPoint(Map<String, Object> pointMap, TransportTrack track, int seq) {
        try {
            TransportTrackPoint point = new TransportTrackPoint();
            point.setPointNo("AMAP" + track.getId() + "_" + seq);
            point.setTrackId(track.getId());
            point.setTrackNo(track.getTrackNo());
            point.setTransferOrderId(track.getTransferOrderId());
            point.setVehicleId(track.getVehicleId());
            point.setVehicleNo(track.getVehicleNo());
            point.setDriverId(track.getDriverId());
            point.setSourceType("AMAP");
            point.setIsOffline(0);
            point.setSynced(1);
            point.setSyncedToAmap(1);
            point.setEnterpriseId(track.getEnterpriseId());

            Object lng = pointMap.get("x");
            Object lat = pointMap.get("y");
            if (lng != null) {
                point.setLng(new BigDecimal(lng.toString()));
            }
            if (lat != null) {
                point.setLat(new BigDecimal(lat.toString()));
            }

            Object locTime = pointMap.get("locTime");
            if (locTime != null) {
                long time = Long.parseLong(locTime.toString());
                if (time > 10000000000L) {
                    time = time / 1000;
                }
                point.setGpsTime(LocalDateTime.ofInstant(Instant.ofEpochSecond(time), ZoneId.systemDefault()));
            } else {
                Object time = pointMap.get("time");
                if (time != null) {
                    long t = Long.parseLong(time.toString());
                    if (t > 10000000000L) {
                        t = t / 1000;
                    }
                    point.setGpsTime(LocalDateTime.ofInstant(Instant.ofEpochSecond(t), ZoneId.systemDefault()));
                }
            }

            Object speed = pointMap.get("speed");
            if (speed != null) {
                point.setSpeed(new BigDecimal(speed.toString()));
            }
            Object direction = pointMap.get("direction");
            if (direction != null) {
                point.setDirection(Integer.parseInt(direction.toString()));
            }
            Object height = pointMap.get("height");
            if (height != null) {
                point.setAltitude(new BigDecimal(height.toString()));
            }
            Object accuracy = pointMap.get("accuracy");
            if (accuracy != null) {
                point.setAccuracy(new BigDecimal(accuracy.toString()));
            }

            return point;
        } catch (Exception e) {
            log.warn("转换高德猎鹰轨迹点失败, data={}", pointMap, e);
            return null;
        }
    }

    @Override
    public TransportTrack getCurrentTrack(Long vehicleId, Long enterpriseId) {
        LambdaQueryWrapper<TransportTrack> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportTrack::getVehicleId, vehicleId);
        wrapper.eq(TransportTrack::getStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(TransportTrack::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByDesc(TransportTrack::getCreateTime);
        wrapper.last("LIMIT 1");
        return transportTrackMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void syncOfflinePoints(Long trackId) {
        TransportTrack track = getById(trackId);
        if (track.getOfflinePoints() == null || track.getOfflinePoints() == 0) {
            return;
        }
        if (StrUtil.isBlank(track.getAmapTrackId())) {
            return;
        }

        LambdaQueryWrapper<TransportTrackPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TransportTrackPoint::getTrackId, trackId);
        wrapper.eq(TransportTrackPoint::getIsOffline, 1);
        wrapper.eq(TransportTrackPoint::getSyncedToAmap, 0);
        wrapper.orderByAsc(TransportTrackPoint::getGpsTime);
        List<TransportTrackPoint> offlinePoints = transportTrackPointMapper.selectList(wrapper);

        if (CollUtil.isEmpty(offlinePoints)) {
            track.setOfflinePoints(0);
            track.setSyncedToAmap(1);
            transportTrackMapper.updateById(track);
            return;
        }

        int syncSuccessCount = 0;
        for (TransportTrackPoint point : offlinePoints) {
            try {
                TransportTrackDTO.TrackPointDTO pointDTO = new TransportTrackDTO.TrackPointDTO();
                BeanUtils.copyProperties(point, pointDTO);
                amapTrackService.uploadPoint(
                        track.getAmapServiceId(),
                        track.getAmapTerminalId(),
                        track.getAmapTrackId(),
                        pointDTO
                );
                point.setSyncedToAmap(1);
                transportTrackPointMapper.updateById(point);
                syncSuccessCount++;
            } catch (Exception e) {
                log.error("同步离线轨迹点失败, pointId={}", point.getId(), e);
            }
        }

        track.setOfflinePoints(track.getOfflinePoints() - syncSuccessCount);
        if (track.getOfflinePoints() <= 0) {
            track.setOfflinePoints(0);
            track.setSyncedToAmap(1);
        }
        transportTrackMapper.updateById(track);
    }

    private void addTrackPointInternal(TransportTrack track, TransportTrackDTO.TrackPointDTO pointDTO) {
        TransportTrackPoint point = new TransportTrackPoint();
        BeanUtils.copyProperties(pointDTO, point);
        point.setPointNo(IdGeneratorUtils.generatePointNo());
        point.setTrackId(track.getId());
        point.setTrackNo(track.getTrackNo());
        point.setTransferOrderId(track.getTransferOrderId());
        point.setVehicleId(track.getVehicleId());
        point.setVehicleNo(track.getVehicleNo());
        point.setDriverId(track.getDriverId());
        point.setSynced(1);
        point.setSyncedToAmap(0);
        if (point.getIsOffline() == null) {
            point.setIsOffline(0);
        }
        if (point.getGpsTime() == null) {
            point.setGpsTime(LocalDateTime.now());
        }
        if (point.getSourceType() == null) {
            point.setSourceType("GPS");
        }
        if (track.getEnterpriseId() != null) {
            point.setEnterpriseId(track.getEnterpriseId());
        }
        transportTrackPointMapper.insert(point);

        track.setPointCount(track.getPointCount() + 1);
    }

    private LambdaQueryWrapper<TransportTrack> buildQueryWrapper(TransportTrack transportTrack, Long enterpriseId) {
        LambdaQueryWrapper<TransportTrack> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(TransportTrack::getEnterpriseId, enterpriseId);
        }
        if (transportTrack != null) {
            if (StrUtil.isNotBlank(transportTrack.getTrackNo())) {
                wrapper.like(TransportTrack::getTrackNo, transportTrack.getTrackNo());
            }
            if (StrUtil.isNotBlank(transportTrack.getTransferOrderNo())) {
                wrapper.like(TransportTrack::getTransferOrderNo, transportTrack.getTransferOrderNo());
            }
            if (transportTrack.getVehicleId() != null) {
                wrapper.eq(TransportTrack::getVehicleId, transportTrack.getVehicleId());
            }
            if (StrUtil.isNotBlank(transportTrack.getVehicleNo())) {
                wrapper.like(TransportTrack::getVehicleNo, transportTrack.getVehicleNo());
            }
            if (transportTrack.getDriverId() != null) {
                wrapper.eq(TransportTrack::getDriverId, transportTrack.getDriverId());
            }
            if (transportTrack.getStatus() != null) {
                wrapper.eq(TransportTrack::getStatus, transportTrack.getStatus());
            }
            if (transportTrack.getTransferOrderId() != null) {
                wrapper.eq(TransportTrack::getTransferOrderId, transportTrack.getTransferOrderId());
            }
        }
        return wrapper;
    }
}
