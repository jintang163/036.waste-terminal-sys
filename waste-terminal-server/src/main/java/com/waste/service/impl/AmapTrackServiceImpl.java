package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import cn.hutool.http.HttpRequest;
import cn.hutool.http.HttpResponse;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.waste.config.AmapTrackConfig;
import com.waste.dto.TransportTrackDTO;
import com.waste.service.AmapTrackService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class AmapTrackServiceImpl implements AmapTrackService {

    @Autowired
    private AmapTrackConfig amapTrackConfig;

    private static final int ERRCODE_SUCCESS = 10000;

    @Override
    public String createTerminal(String serviceId, String terminalName, String terminalDesc) {
        if (amapTrackConfig.getMockEnabled()) {
            log.info("Mock创建高德猎鹰终端, serviceId={}, terminalName={}", serviceId, terminalName);
            return "mock_terminal_" + System.currentTimeMillis();
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("name", terminalName);
            if (StrUtil.isNotBlank(terminalDesc)) {
                params.put("desc", terminalDesc);
            }

            String url = amapTrackConfig.getApiUrl() + "/terminal/add";
            HttpResponse response = HttpRequest.post(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == result.getInt("errcode")) {
                    JSONObject data = result.getJSONObject("data");
                    return data.getStr("tid");
                } else {
                    log.error("创建高德猎鹰终端失败, errcode={}, errmsg={}",
                            result.getInt("errcode"), result.getStr("errmsg"));
                }
            }
        } catch (Exception e) {
            log.error("创建高德猎鹰终端异常, serviceId={}, terminalName={}", serviceId, terminalName, e);
        }
        return null;
    }

    @Override
    public boolean deleteTerminal(String serviceId, String terminalId) {
        if (amapTrackConfig.getMockEnabled()) {
            log.info("Mock删除高德猎鹰终端, serviceId={}, terminalId={}", serviceId, terminalId);
            return true;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);

            String url = amapTrackConfig.getApiUrl() + "/terminal/delete";
            HttpResponse response = HttpRequest.post(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                return ERRCODE_SUCCESS == result.getInt("errcode");
            }
        } catch (Exception e) {
            log.error("删除高德猎鹰终端异常, serviceId={}, terminalId={}", serviceId, terminalId, e);
        }
        return false;
    }

    @Override
    public Map<String, Object> getTerminal(String serviceId, String terminalId) {
        if (amapTrackConfig.getMockEnabled()) {
            Map<String, Object> mock = new HashMap<>();
            mock.put("tid", terminalId);
            mock.put("name", "mock_terminal");
            return mock;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);

            String url = amapTrackConfig.getApiUrl() + "/terminal/list";
            HttpResponse response = HttpRequest.get(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == result.getInt("errcode")) {
                    JSONObject data = result.getJSONObject("data");
                    if (data != null && CollUtil.isNotEmpty(data.getJSONArray("terminals"))) {
                        return data.getJSONArray("terminals").getJSONObject(0);
                    }
                }
            }
        } catch (Exception e) {
            log.error("查询高德猎鹰终端异常, serviceId={}, terminalId={}", serviceId, terminalId, e);
        }
        return null;
    }

    @Override
    public List<Map<String, Object>> listTerminals(String serviceId, Integer page, Integer pageSize) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (amapTrackConfig.getMockEnabled()) {
            return result;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            if (page != null) {
                params.put("page", page);
            }
            if (pageSize != null) {
                params.put("pagesize", pageSize);
            }

            String url = amapTrackConfig.getApiUrl() + "/terminal/list";
            HttpResponse response = HttpRequest.get(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject json = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == json.getInt("errcode")) {
                    JSONObject data = json.getJSONObject("data");
                    if (data != null && CollUtil.isNotEmpty(data.getJSONArray("terminals"))) {
                        for (int i = 0; i < data.getJSONArray("terminals").size(); i++) {
                            result.add(data.getJSONArray("terminals").getJSONObject(i));
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.error("查询高德猎鹰终端列表异常, serviceId={}", serviceId, e);
        }
        return result;
    }

    @Override
    public String createTrack(String serviceId, String terminalId, String trackName) {
        if (amapTrackConfig.getMockEnabled()) {
            log.info("Mock创建高德猎鹰轨迹, serviceId={}, terminalId={}, trackName={}",
                    serviceId, terminalId, trackName);
            return "mock_track_" + System.currentTimeMillis();
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            params.put("trname", trackName);

            String url = amapTrackConfig.getApiUrl() + "/trace/add";
            HttpResponse response = HttpRequest.post(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == result.getInt("errcode")) {
                    JSONObject data = result.getJSONObject("data");
                    return data.getStr("trid");
                } else {
                    log.error("创建高德猎鹰轨迹失败, errcode={}, errmsg={}",
                            result.getInt("errcode"), result.getStr("errmsg"));
                }
            }
        } catch (Exception e) {
            log.error("创建高德猎鹰轨迹异常, serviceId={}, terminalId={}, trackName={}",
                    serviceId, terminalId, trackName, e);
        }
        return null;
    }

    @Override
    public boolean deleteTrack(String serviceId, String terminalId, String trackId) {
        if (amapTrackConfig.getMockEnabled()) {
            log.info("Mock删除高德猎鹰轨迹, serviceId={}, terminalId={}, trackId={}",
                    serviceId, terminalId, trackId);
            return true;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            params.put("trid", trackId);

            String url = amapTrackConfig.getApiUrl() + "/trace/delete";
            HttpResponse response = HttpRequest.post(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                return ERRCODE_SUCCESS == result.getInt("errcode");
            }
        } catch (Exception e) {
            log.error("删除高德猎鹰轨迹异常, serviceId={}, terminalId={}, trackId={}",
                    serviceId, terminalId, trackId, e);
        }
        return false;
    }

    @Override
    public boolean uploadPoint(String serviceId, String terminalId, String trackId, TransportTrackDTO.TrackPointDTO point) {
        if (amapTrackConfig.getMockEnabled()) {
            log.debug("Mock上报轨迹点, serviceId={}, terminalId={}, trackId={}, lng={}, lat={}",
                    serviceId, terminalId, trackId, point.getLng(), point.getLat());
            return true;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            params.put("trid", trackId);

            List<Map<String, Object>> points = new ArrayList<>();
            Map<String, Object> pointMap = buildPointMap(point);
            points.add(pointMap);
            params.put("points", JSONUtil.toJsonStr(points));

            String url = amapTrackConfig.getApiUrl() + "/point/upload";
            HttpResponse response = HttpRequest.post(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                return ERRCODE_SUCCESS == result.getInt("errcode");
            }
        } catch (Exception e) {
            log.error("上报轨迹点到高德猎鹰异常, serviceId={}, terminalId={}, trackId={}",
                    serviceId, terminalId, trackId, e);
        }
        return false;
    }

    @Override
    public boolean uploadPoints(String serviceId, String terminalId, String trackId, List<TransportTrackDTO.TrackPointDTO> points) {
        if (CollUtil.isEmpty(points)) {
            return true;
        }

        if (amapTrackConfig.getMockEnabled()) {
            log.debug("Mock批量上报轨迹点, serviceId={}, terminalId={}, trackId={}, count={}",
                    serviceId, terminalId, trackId, points.size());
            return true;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            params.put("trid", trackId);

            List<Map<String, Object>> pointList = new ArrayList<>();
            for (TransportTrackDTO.TrackPointDTO point : points) {
                pointList.add(buildPointMap(point));
            }
            params.put("points", JSONUtil.toJsonStr(pointList));

            String url = amapTrackConfig.getApiUrl() + "/point/upload";
            HttpResponse response = HttpRequest.post(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                return ERRCODE_SUCCESS == result.getInt("errcode");
            }
        } catch (Exception e) {
            log.error("批量上报轨迹点到高德猎鹰异常, serviceId={}, terminalId={}, trackId={}, count={}",
                    serviceId, terminalId, trackId, points.size(), e);
        }
        return false;
    }

    @Override
    public List<Map<String, Object>> queryTrack(String serviceId, String terminalId, String trackId, Long startTime, Long endTime) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (amapTrackConfig.getMockEnabled()) {
            return result;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            params.put("trid", trackId);
            if (startTime != null) {
                params.put("starttime", startTime);
            }
            if (endTime != null) {
                params.put("endtime", endTime);
            }

            String url = amapTrackConfig.getApiUrl() + "/trace/search";
            HttpResponse response = HttpRequest.get(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject json = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == json.getInt("errcode")) {
                    JSONObject data = json.getJSONObject("data");
                    if (data != null && CollUtil.isNotEmpty(data.getJSONArray("points"))) {
                        for (int i = 0; i < data.getJSONArray("points").size(); i++) {
                            result.add(data.getJSONArray("points").getJSONObject(i));
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.error("查询高德猎鹰轨迹异常, serviceId={}, terminalId={}, trackId={}",
                    serviceId, terminalId, trackId, e);
        }
        return result;
    }

    @Override
    public List<Map<String, Object>> queryTerminalTrack(String serviceId, String terminalId, Long startTime, Long endTime) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (amapTrackConfig.getMockEnabled()) {
            return result;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            if (startTime != null) {
                params.put("starttime", startTime);
            }
            if (endTime != null) {
                params.put("endtime", endTime);
            }

            String url = amapTrackConfig.getApiUrl() + "/terminal/trace/search";
            HttpResponse response = HttpRequest.get(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject json = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == json.getInt("errcode")) {
                    JSONObject data = json.getJSONObject("data");
                    if (data != null && CollUtil.isNotEmpty(data.getJSONArray("traces"))) {
                        for (int i = 0; i < data.getJSONArray("traces").size(); i++) {
                            result.add(data.getJSONArray("traces").getJSONObject(i));
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.error("查询终端轨迹异常, serviceId={}, terminalId={}", serviceId, terminalId, e);
        }
        return result;
    }

    @Override
    public BigDecimal calculateDistance(String serviceId, String terminalId, String trackId) {
        if (amapTrackConfig.getMockEnabled()) {
            return BigDecimal.ZERO;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);
            params.put("trid", trackId);

            String url = amapTrackConfig.getApiUrl() + "/trace/search";
            HttpResponse response = HttpRequest.get(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == result.getInt("errcode")) {
                    JSONObject data = result.getJSONObject("data");
                    if (data != null) {
                        return new BigDecimal(data.getStr("distance", "0"));
                    }
                }
            }
        } catch (Exception e) {
            log.error("计算轨迹距离异常, serviceId={}, terminalId={}, trackId={}",
                    serviceId, terminalId, trackId, e);
        }
        return BigDecimal.ZERO;
    }

    @Override
    public Map<String, Object> getTerminalLastPoint(String serviceId, String terminalId) {
        if (amapTrackConfig.getMockEnabled()) {
            Map<String, Object> mock = new HashMap<>();
            mock.put("lng", "116.397428");
            mock.put("lat", "39.90923");
            mock.put("locTime", System.currentTimeMillis());
            return mock;
        }

        try {
            Map<String, Object> params = new HashMap<>();
            params.put("key", amapTrackConfig.getKey());
            params.put("sid", serviceId);
            params.put("tid", terminalId);

            String url = amapTrackConfig.getApiUrl() + "/terminal/latestpoint";
            HttpResponse response = HttpRequest.get(url)
                    .form(params)
                    .timeout(amapTrackConfig.getConnectionTimeout())
                    .execute();

            if (response.isOk()) {
                JSONObject result = JSONUtil.parseObj(response.body());
                if (ERRCODE_SUCCESS == result.getInt("errcode")) {
                    return result.getJSONObject("data");
                }
            }
        } catch (Exception e) {
            log.error("查询终端最后位置异常, serviceId={}, terminalId={}", serviceId, terminalId, e);
        }
        return null;
    }

    private Map<String, Object> buildPointMap(TransportTrackDTO.TrackPointDTO point) {
        Map<String, Object> pointMap = new HashMap<>();
        if (point.getLng() != null) {
            pointMap.put("x", point.getLng().doubleValue());
        }
        if (point.getLat() != null) {
            pointMap.put("y", point.getLat().doubleValue());
        }
        if (point.getGpsTime() != null) {
            long time = point.getGpsTime().atZone(ZoneId.systemDefault()).toInstant().getEpochSecond();
            pointMap.put("time", time);
        } else {
            pointMap.put("time", System.currentTimeMillis() / 1000);
        }
        if (point.getSpeed() != null) {
            pointMap.put("speed", point.getSpeed().doubleValue());
        }
        if (point.getDirection() != null) {
            pointMap.put("direction", point.getDirection());
        }
        if (point.getAltitude() != null) {
            pointMap.put("height", point.getAltitude().doubleValue());
        }
        if (point.getAccuracy() != null) {
            pointMap.put("accuracy", point.getAccuracy().doubleValue());
        }
        if (StrUtil.isNotBlank(point.getExtraData())) {
            pointMap.put("extra", point.getExtraData());
        }
        return pointMap;
    }
}
