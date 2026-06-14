package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import cn.hutool.http.HttpRequest;
import cn.hutool.http.HttpResponse;
import cn.hutool.http.HttpStatus;
import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteTransferOrder;
import com.waste.service.NationalPlatformService;
import com.waste.utils.JsonUtils;
import com.waste.utils.SmUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class NationalPlatformServiceImpl implements NationalPlatformService {

    @Value("${waste.national-platform.url:https://api.ep.gov.cn/waste}")
    private String platformUrl;

    @Value("${waste.national-platform.app-id:}")
    private String appId;

    @Value("${waste.national-platform.app-secret:}")
    private String appSecret;

    @Value("${waste.national-platform.mock-enabled:true}")
    private boolean mockEnabled;

    @Value("${waste.national-platform.connection-timeout:10000}")
    private int connectionTimeout;

    @Value("${waste.national-platform.read-timeout:30000}")
    private int readTimeout;

    @Value("${waste.national-platform.retry-times:3}")
    private int retryTimes;

    @Value("${sm.sm4.key:0123456789abcdeffedcba9876543210}")
    private String sm4Key;

    @Value("${sm.sm2.public-key:}")
    private String sm2PublicKey;

    @Value("${sm.sm2.private-key:}")
    private String sm2PrivateKey;

    private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
    private static final int HTTP_SUCCESS = 200;
    private static final String RESP_CODE_SUCCESS = "0";
    private static final String RESP_CODE_DUPLICATE = "1001";

    @Override
    public boolean reportTransferOrder(WasteTransferOrder order) {
        log.info("开始上报转移联单到国家环保平台, orderNo={}", order.getOrderNo());
        try {
            Map<String, Object> bizData = buildTransferOrderData(order);
            return doReport("/transfer/report", bizData, order.getOrderNo());
        } catch (Exception e) {
            log.error("上报转移联单异常, orderNo={}", order.getOrderNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportWasteIn(WasteInRecord record) {
        log.info("开始上报入库记录到国家环保平台, inNo={}", record.getInNo());
        try {
            Map<String, Object> bizData = buildWasteInData(record);
            return doReport("/wasteIn/report", bizData, record.getInNo());
        } catch (Exception e) {
            log.error("上报入库记录异常, inNo={}", record.getInNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportWasteOut(WasteOutRecord record) {
        log.info("开始上报出库记录到国家环保平台, outNo={}", record.getOutNo());
        try {
            Map<String, Object> bizData = buildWasteOutData(record);
            return doReport("/wasteOut/report", bizData, record.getOutNo());
        } catch (Exception e) {
            log.error("上报出库记录异常, outNo={}", record.getOutNo(), e);
            return false;
        }
    }

    @Override
    public boolean reportTransferOrderCompletion(WasteTransferOrder order) {
        log.info("开始上报转移联单完成信息到国家环保平台, orderNo={}", order.getOrderNo());
        try {
            Map<String, Object> bizData = buildTransferOrderCompletionData(order);
            return doReport("/transfer/complete", bizData, order.getOrderNo());
        } catch (Exception e) {
            log.error("上报转移联单完成信息异常, orderNo={}", order.getOrderNo(), e);
            return false;
        }
    }

    @Override
    public Map<String, Object> queryReportStatus(String bizType, String bizNo) {
        log.info("查询上报状态, bizType={}, bizNo={}", bizType, bizNo);
        Map<String, Object> result = new HashMap<>();
        try {
            Map<String, Object> bizData = new LinkedHashMap<>();
            bizData.put("bizType", bizType);
            bizData.put("bizNo", bizNo);
            boolean success = doReport("/report/query", bizData, bizNo);
            result.put("success", success);
            result.put("bizNo", bizNo);
            result.put("queryTime", LocalDateTime.now());
        } catch (Exception e) {
            log.error("查询上报状态异常, bizType={}, bizNo={}", bizType, bizNo, e);
            result.put("success", false);
            result.put("error", e.getMessage());
        }
        return result;
    }

    @Override
    public String getNationalPlatformBizNo(String localBizNo) {
        return "GJ" + System.currentTimeMillis();
    }

    private boolean doReport(String apiPath, Map<String, Object> bizData, String bizNo) {
        String requestId = StrUtil.uuid().replace("-", "");
        String timestamp = LocalDateTime.now().format(FORMATTER);

        Map<String, Object> requestBody = buildRequestBody(bizData, requestId, timestamp);
        String requestJson = JsonUtils.toJson(requestBody);
        String fullUrl = platformUrl + apiPath;

        log.info("上报国家平台请求, url={}, bizNo={}", fullUrl, bizNo);
        log.debug("上报请求报文, bizNo={}, data={}", bizNo, requestJson);

        if (mockEnabled || StrUtil.isBlank(appId) || StrUtil.isBlank(appSecret)) {
            log.info("使用模拟模式上报国家平台, bizNo={}", bizNo);
            return mockPlatformCall(fullUrl, requestJson, bizNo);
        }

        return doRealHttpCall(fullUrl, requestJson, bizNo);
    }

    private Map<String, Object> buildRequestBody(Map<String, Object> bizData, String requestId, String timestamp) {
        Map<String, Object> requestBody = new LinkedHashMap<>();
        requestBody.put("appId", appId);
        requestBody.put("requestId", requestId);
        requestBody.put("timestamp", timestamp);
        requestBody.put("version", "1.0");

        String bizJson = JsonUtils.toJson(bizData);
        log.debug("上报业务明文数据, requestId={}, data={}", requestId, bizJson);

        String encryptedData = SmUtils.sm4Encrypt(sm4Key, bizJson);
        requestBody.put("data", encryptedData);

        TreeMap<String, String> signParams = new TreeMap<>();
        signParams.put("appId", appId);
        signParams.put("requestId", requestId);
        signParams.put("timestamp", timestamp);
        signParams.put("version", "1.0");
        signParams.put("data", encryptedData);
        String signContent = buildSignContent(signParams);

        String signature;
        if (StrUtil.isNotBlank(sm2PrivateKey)) {
            signature = SmUtils.sm2Sign(sm2PrivateKey, signContent);
            requestBody.put("signType", "SM2");
        } else {
            signature = SmUtils.sm3(signContent);
            requestBody.put("signType", "SM3");
        }
        requestBody.put("sign", signature);

        return requestBody;
    }

    private boolean doRealHttpCall(String url, String requestJson, String bizNo) {
        int retryCount = 0;
        Exception lastException = null;

        while (retryCount < retryTimes) {
            try {
                log.info("调用国家环保平台接口, 第{}次尝试, bizNo={}", retryCount + 1, bizNo);

                HttpResponse response = HttpRequest.post(url)
                        .header("Content-Type", "application/json;charset=UTF-8")
                        .header("Accept", "application/json")
                        .header("appId", appId)
                        .timeout(connectionTimeout)
                        .setConnectionTimeout(connectionTimeout)
                        .body(requestJson)
                        .execute();

                int httpStatus = response.getStatus();
                String responseBody = response.body();

                log.info("国家平台响应, httpStatus={}, bizNo={}, response={}", httpStatus, bizNo, responseBody);

                if (httpStatus == HTTP_SUCCESS) {
                    return parseResponse(responseBody, bizNo);
                } else {
                    log.warn("国家平台返回非200状态码, httpStatus={}, bizNo={}", httpStatus, bizNo);
                }

            } catch (Exception e) {
                lastException = e;
                log.error("调用国家平台接口失败, 第{}次尝试, bizNo={}", retryCount + 1, bizNo, e);
            }

            retryCount++;
            if (retryCount < retryTimes) {
                try {
                    long delay = (long) Math.pow(2, retryCount) * 1000;
                    log.info("等待{}ms后进行第{}次重试, bizNo={}", delay, retryCount + 1, bizNo);
                    TimeUnit.MILLISECONDS.sleep(delay);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }

        log.error("调用国家平台接口最终失败, 已重试{}次, bizNo={}", retryTimes, bizNo, lastException);
        return false;
    }

    private boolean parseResponse(String responseBody, String bizNo) {
        try {
            Map<String, Object> responseMap = JsonUtils.parseMap(responseBody);
            String code = responseMap.get("code") != null ? responseMap.get("code").toString() : null;
            String message = responseMap.get("message") != null ? responseMap.get("message").toString() : null;

            if (RESP_CODE_SUCCESS.equals(code)) {
                log.info("国家平台上报成功, bizNo={}, message={}", bizNo, message);
                return true;
            } else if (RESP_CODE_DUPLICATE.equals(code)) {
                log.warn("国家平台返回重复上报, bizNo={}, message={}", bizNo, message);
                return true;
            } else {
                log.error("国家平台返回错误, bizNo={}, code={}, message={}", bizNo, code, message);
                return false;
            }
        } catch (Exception e) {
            log.error("解析国家平台响应失败, bizNo={}, response={}", bizNo, responseBody, e);
            return false;
        }
    }

    private boolean mockPlatformCall(String url, String requestJson, String bizNo) {
        log.info("【模拟对接】调用国家环保平台API, url={}, request={}", url, requestJson);

        try {
            Thread.sleep(200L);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        boolean success = true;
        Map<String, Object> response = new HashMap<>();
        response.put("code", success ? "0" : "9999");
        response.put("message", success ? "success" : "系统繁忙");
        response.put("requestId", StrUtil.uuid().replace("-", ""));
        response.put("timestamp", LocalDateTime.now().format(FORMATTER));

        if (success) {
            Map<String, Object> data = new HashMap<>();
            data.put("bizNo", bizNo);
            data.put("platformBizNo", "GJ" + System.currentTimeMillis());
            data.put("reportTime", LocalDateTime.now().format(FORMATTER));
            response.put("data", data);
        }

        String responseJson = JsonUtils.toJson(response);
        log.info("【模拟对接】国家环保平台响应, bizNo={}, response={}", bizNo, responseJson);

        return success;
    }

    private Map<String, Object> buildTransferOrderData(WasteTransferOrder order) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("orderNo", order.getOrderNo());
        data.put("orderType", order.getOrderType());
        data.put("generatorUnitCode", order.getGeneratorUnitCode());
        data.put("generatorUnitName", order.getGeneratorUnitName());
        data.put("receiverUnitCode", order.getReceiverUnitCode());
        data.put("receiverUnitName", order.getReceiverUnitName());
        data.put("receiverLicenseNo", order.getReceiverLicenseNo());
        data.put("transporterName", order.getTransporterName());
        data.put("transporterLicenseNo", order.getTransporterLicenseNo());
        data.put("vehicleNo", order.getVehicleNo());
        data.put("driverName", order.getDriverName());
        data.put("driverLicense", order.getDriverLicense());
        data.put("escortName", order.getEscortName());
        data.put("totalWeight", order.getTotalWeight());
        data.put("totalContainers", order.getTotalContainers());
        data.put("wasteDetails", order.getWasteDetails());
        data.put("route", order.getRoute());
        data.put("emergencyContact", order.getEmergencyContact());
        data.put("emergencyPhone", order.getEmergencyPhone());
        if (order.getStartTime() != null) {
            data.put("startTime", order.getStartTime().format(FORMATTER));
        }
        if (order.getEstimateArriveTime() != null) {
            data.put("estimateArriveTime", order.getEstimateArriveTime().format(FORMATTER));
        }
        data.put("status", order.getStatus());
        data.put("remark", order.getRemark());
        return data;
    }

    private Map<String, Object> buildWasteInData(WasteInRecord record) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("inNo", record.getInNo());
        data.put("containerCode", record.getContainerCode());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("wasteCategory", record.getWasteCategory());
        data.put("hazardCode", record.getHazardCode());
        data.put("weight", record.getWeight());
        data.put("weightSource", record.getWeightSource());
        data.put("scaleDevice", record.getScaleDevice());
        if (record.getProduceDate() != null) {
            data.put("produceDate", record.getProduceDate().format(DateTimeFormatter.ofPattern("yyyyMMdd")));
        }
        data.put("produceDepartment", record.getProduceDepartment());
        data.put("storageLocation", record.getStorageLocation());
        data.put("operatorId", record.getOperatorId());
        data.put("operatorName", record.getOperatorName());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("remark", record.getRemark());
        return data;
    }

    private Map<String, Object> buildWasteOutData(WasteOutRecord record) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("outNo", record.getOutNo());
        data.put("transferOrderId", record.getTransferOrderId());
        data.put("containerCode", record.getContainerCode());
        data.put("wasteCode", record.getWasteCode());
        data.put("wasteName", record.getWasteName());
        data.put("weight", record.getWeight());
        data.put("receiverUnitId", record.getReceiverUnitId());
        data.put("receiverUnitName", record.getReceiverUnitName());
        data.put("transporterId", record.getTransporterId());
        data.put("transporterName", record.getTransporterName());
        data.put("vehicleNo", record.getVehicleNo());
        data.put("driverName", record.getDriverName());
        data.put("driverPhone", record.getDriverPhone());
        if (record.getOutTime() != null) {
            data.put("outTime", record.getOutTime().format(FORMATTER));
        }
        data.put("operatorId", record.getOperatorId());
        data.put("operatorName", record.getOperatorName());
        data.put("enterpriseId", record.getEnterpriseId());
        data.put("remark", record.getRemark());
        return data;
    }

    private Map<String, Object> buildTransferOrderCompletionData(WasteTransferOrder order) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("orderNo", order.getOrderNo());
        data.put("nationalOrderNo", order.getNationalOrderNo());
        data.put("status", order.getStatus());
        data.put("signStatus", order.getSignStatus());
        if (order.getSignTime() != null) {
            data.put("signTime", order.getSignTime().format(FORMATTER));
        }
        data.put("signPhoto", order.getSignPhoto());
        data.put("receiptPhoto", order.getReceiptPhoto());
        if (order.getCompleteTime() != null) {
            data.put("completeTime", order.getCompleteTime().format(FORMATTER));
        }
        if (order.getActualArriveTime() != null) {
            data.put("actualArriveTime", order.getActualArriveTime().format(FORMATTER));
        }
        data.put("totalWeight", order.getTotalWeight());
        data.put("totalContainers", order.getTotalContainers());
        data.put("wasteDetails", order.getWasteDetails());
        data.put("receiverUnitCode", order.getReceiverUnitCode());
        data.put("receiverUnitName", order.getReceiverUnitName());
        data.put("remark", order.getRemark());
        return data;
    }

    private String buildSignContent(TreeMap<String, String> params) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> entry : params.entrySet()) {
            if (sb.length() > 0) {
                sb.append("&");
            }
            sb.append(entry.getKey()).append("=").append(entry.getValue() == null ? "" : entry.getValue());
        }
        if (StrUtil.isNotBlank(appSecret)) {
            sb.append("&appSecret=").append(appSecret);
        }
        return sb.toString();
    }
}
