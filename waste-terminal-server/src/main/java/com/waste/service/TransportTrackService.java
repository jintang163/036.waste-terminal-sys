package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.TransportTrackDTO;
import com.waste.entity.TransportTrack;
import com.waste.entity.TransportTrackPoint;

import java.util.List;

public interface TransportTrackService {

    IPage<TransportTrack> page(PageQuery pageQuery, TransportTrack transportTrack, Long enterpriseId);

    TransportTrack getById(Long id);

    TransportTrack createTrack(TransportTrackDTO dto, Long enterpriseId);

    void startTransport(Long trackId, TransportTrackDTO.TrackPointDTO startPoint);

    void endTransport(Long trackId, TransportTrackDTO.TrackPointDTO endPoint);

    void addTrackPoint(Long trackId, TransportTrackDTO.TrackPointDTO pointDTO);

    List<TransportTrackPoint> getTrackPoints(Long trackId);

    TransportTrack getCurrentTrack(Long vehicleId, Long enterpriseId);

    void syncOfflinePoints(Long trackId);
}
