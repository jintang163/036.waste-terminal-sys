package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.TransportTrackDTO;
import com.waste.entity.TransportTrack;
import com.waste.entity.TransportTrackPoint;
import com.waste.service.TransportTrackService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/transport-track")
public class TransportTrackController {

    @Autowired
    private TransportTrackService transportTrackService;

    @PostMapping("/create")
    @RequiresLogin
    public Result<TransportTrack> createTrack(@RequestBody @Validated TransportTrackDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        TransportTrack track = transportTrackService.createTrack(dto, enterpriseId);
        return Result.success(track);
    }

    @PostMapping("/start/{trackId}")
    @RequiresLogin
    public Result<Void> startTransport(@PathVariable Long trackId,
                                        @RequestBody(required = false) TransportTrackDTO.TrackPointDTO startPoint) {
        transportTrackService.startTransport(trackId, startPoint);
        return Result.success();
    }

    @PostMapping("/end/{trackId}")
    @RequiresLogin
    public Result<Void> endTransport(@PathVariable Long trackId,
                                      @RequestBody(required = false) TransportTrackDTO.TrackPointDTO endPoint) {
        transportTrackService.endTransport(trackId, endPoint);
        return Result.success();
    }

    @PostMapping("/point/{trackId}")
    @RequiresLogin
    public Result<Void> addTrackPoint(@PathVariable Long trackId,
                                       @RequestBody @Validated TransportTrackDTO.TrackPointDTO pointDTO) {
        transportTrackService.addTrackPoint(trackId, pointDTO);
        return Result.success();
    }

    @PostMapping("/points/{trackId}")
    @RequiresLogin
    public Result<Void> addTrackPoints(@PathVariable Long trackId,
                                        @RequestBody @Validated List<TransportTrackDTO.TrackPointDTO> points) {
        if (points != null && !points.isEmpty()) {
            for (TransportTrackDTO.TrackPointDTO point : points) {
                transportTrackService.addTrackPoint(trackId, point);
            }
        }
        return Result.success();
    }

    @GetMapping("/points/{trackId}")
    @RequiresLogin
    public Result<List<TransportTrackPoint>> getTrackPoints(@PathVariable Long trackId) {
        List<TransportTrackPoint> points = transportTrackService.getTrackPoints(trackId);
        return Result.success(points);
    }

    @GetMapping("/replay/{trackId}")
    @RequiresLogin
    public Result<List<TransportTrackPoint>> replayTrack(@PathVariable Long trackId) {
        List<TransportTrackPoint> points = transportTrackService.getTrackPoints(trackId);
        return Result.success(points);
    }

    @GetMapping("/current/{vehicleId}")
    @RequiresLogin
    public Result<TransportTrack> getCurrentTrack(@PathVariable Long vehicleId,
                                                   @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        TransportTrack track = transportTrackService.getCurrentTrack(vehicleId, enterpriseId);
        return Result.success(track);
    }

    @PostMapping("/sync-offline/{trackId}")
    @RequiresLogin
    public Result<Void> syncOfflinePoints(@PathVariable Long trackId) {
        transportTrackService.syncOfflinePoints(trackId);
        return Result.success();
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<TransportTrack>> page(PageQuery pageQuery, TransportTrack transportTrack,
                                                    @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<TransportTrack> page = transportTrackService.page(pageQuery, transportTrack, enterpriseId);
        PageResult<TransportTrack> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<TransportTrack> detail(@PathVariable Long id) {
        TransportTrack track = transportTrackService.getById(id);
        return Result.success(track);
    }

    @GetMapping("/{id}")
    public Result<TransportTrack> getById(@PathVariable Long id) {
        TransportTrack track = transportTrackService.getById(id);
        return Result.success(track);
    }
}
