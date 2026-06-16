package com.waste.service;

import com.waste.dto.TransportTrackDTO;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public interface AmapTrackService {

    String createTerminal(String serviceId, String terminalName, String terminalDesc);

    boolean deleteTerminal(String serviceId, String terminalId);

    Map<String, Object> getTerminal(String serviceId, String terminalId);

    List<Map<String, Object>> listTerminals(String serviceId, Integer page, Integer pageSize);

    String createTrack(String serviceId, String terminalId, String trackName);

    boolean deleteTrack(String serviceId, String terminalId, String trackId);

    boolean uploadPoint(String serviceId, String terminalId, String trackId, TransportTrackDTO.TrackPointDTO point);

    boolean uploadPoints(String serviceId, String terminalId, String trackId, List<TransportTrackDTO.TrackPointDTO> points);

    List<Map<String, Object>> queryTrack(String serviceId, String terminalId, String trackId, Long startTime, Long endTime);

    List<Map<String, Object>> queryTerminalTrack(String serviceId, String terminalId, Long startTime, Long endTime);

    BigDecimal calculateDistance(String serviceId, String terminalId, String trackId);

    Map<String, Object> getTerminalLastPoint(String serviceId, String terminalId);
}
