package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import cn.hutool.http.HttpRequest;
import cn.hutool.http.HttpResponse;
import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.waste.config.WasteAiRecognitionConfig;
import com.waste.service.HuaweiImageTaggingService;
import com.waste.utils.HuaweiApigwSigner;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class HuaweiImageTaggingServiceImpl implements HuaweiImageTaggingService {

    @Override
    public List<ImageTag> tagImage(byte[] imageBytes,
                                    WasteAiRecognitionConfig.WasteAiRecognitionProperties properties) {
        try {
            String base64Image = Base64.getEncoder().encodeToString(imageBytes);
            JSONObject requestBody = new JSONObject();
            requestBody.set("image", base64Image);
            requestBody.set("limit", 20);
            requestBody.set("threshold", 0.1);

            return executeTagging(properties, requestBody.toString());
        } catch (Exception e) {
            log.error("华为云图像标签识别失败", e);
            throw new RuntimeException("图像标签识别失败: " + e.getMessage(), e);
        }
    }

    @Override
    public List<ImageTag> tagImageByUrl(String imageUrl,
                                         WasteAiRecognitionConfig.WasteAiRecognitionProperties properties) {
        try {
            JSONObject requestBody = new JSONObject();
            requestBody.set("url", imageUrl);
            requestBody.set("limit", 20);
            requestBody.set("threshold", 0.1);

            return executeTagging(properties, requestBody.toString());
        } catch (Exception e) {
            log.error("华为云图像标签识别失败 URL: {}", imageUrl, e);
            throw new RuntimeException("图像标签识别失败: " + e.getMessage(), e);
        }
    }

    private List<ImageTag> executeTagging(
            WasteAiRecognitionConfig.WasteAiRecognitionProperties properties,
            String requestBody) {

        String endpoint = properties.getEndpoint();
        String ak = properties.getAk();
        String sk = properties.getSk();
        int connectTimeout = properties.getConnectionTimeout();
        int readTimeout = properties.getReadTimeout();

        if (StrUtil.isBlank(endpoint) || StrUtil.isBlank(ak) || StrUtil.isBlank(sk)) {
            throw new RuntimeException("华为云AI配置不完整，请检查 endpoint/ak/sk 配置");
        }

        if (!endpoint.startsWith("http://") && !endpoint.startsWith("https://")) {
            endpoint = "https://" + endpoint;
        }

        String uri = "/v2/" + (StrUtil.isNotBlank(properties.getModelId())
                ? properties.getModelId() : "general") + "/image/tagging";
        String url = endpoint + uri;

        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");

        String authorization = HuaweiApigwSigner.sign(
                ak, sk, "POST", url, headers, requestBody);
        headers.put("Authorization", authorization);

        HttpResponse response = HttpRequest.post(url)
                .addHeaders(headers)
                .body(requestBody)
                .timeout(connectTimeout + readTimeout)
                .execute();

        String respBody = response.body();
        if (response.getStatus() != 200) {
            log.error("华为云图像标签API调用失败, status={}, body={}", response.getStatus(), respBody);
            throw new RuntimeException("图像识别API调用失败: " + respBody);
        }

        return parseTags(respBody);
    }

    private List<ImageTag> parseTags(String respBody) {
        List<ImageTag> tags = new ArrayList<>();
        try {
            JSONObject resp = JSONUtil.parseObj(respBody);
            JSONArray resultArray = resp.getJSONArray("result");
            if (resultArray != null) {
                for (int i = 0; i < resultArray.size(); i++) {
                    JSONObject item = resultArray.getJSONObject(i);
                    String tag = item.getStr("tag");
                    Double confidence = item.getDouble("confidence");
                    String category = item.getStr("category", "");
                    if (StrUtil.isNotBlank(tag) && confidence != null) {
                        tags.add(new ImageTag(tag, confidence, category));
                    }
                }
            }
            log.info("华为云图像标签识别成功，标签数量: {}", tags.size());
        } catch (Exception e) {
            log.error("解析图像标签结果失败", e);
        }
        return tags;
    }
}
