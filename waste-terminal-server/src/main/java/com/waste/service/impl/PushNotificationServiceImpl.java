package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import cn.hutool.http.HttpRequest;
import cn.hutool.http.HttpResponse;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.entity.SysUser;
import com.waste.entity.WarningRecord;
import com.waste.mapper.SysUserMapper;
import com.waste.service.PushNotificationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class PushNotificationServiceImpl implements PushNotificationService {

    @Autowired
    private SysUserMapper sysUserMapper;

    @Value("${push.jpush.app-key:}")
    private String jpushAppKey;

    @Value("${push.jpush.master-secret:}")
    private String jpushMasterSecret;

    @Value("${push.jpush.url:https://api.jpush.cn/v3/push}")
    private String jpushUrl;

    @Value("${push.jpush.mock-enabled:true}")
    private boolean jpushMockEnabled;

    @Value("${sms.aliyun.access-key-id:}")
    private String smsAccessKeyId;

    @Value("${sms.aliyun.access-key-secret:}")
    private String smsAccessKeySecret;

    @Value("${sms.aliyun.sign-name:危废智能终端}")
    private String smsSignName;

    @Value("${sms.aliyun.template-code-warning:SMS_001}")
    private String smsTemplateCodeWarning;

    @Value("${sms.aliyun.mock-enabled:true}")
    private boolean smsMockEnabled;

    @Override
    public boolean pushToApp(WarningRecord warningRecord, String title, String content) {
        if (warningRecord.getEnterpriseId() == null) {
            log.warn("预警记录缺少企业ID, 无法推送, warningNo={}", warningRecord.getWarningNo());
            return false;
        }
        Map<String, String> extras = new HashMap<>();
        extras.put("warningId", String.valueOf(warningRecord.getId()));
        extras.put("warningNo", warningRecord.getWarningNo());
        extras.put("warningType", warningRecord.getWarningType());
        extras.put("warningLevel", String.valueOf(warningRecord.getWarningLevel()));
        return pushToAppByEnterprise(warningRecord.getEnterpriseId(), title, content, extras);
    }

    @Override
    public boolean pushToAppByUserIds(List<Long> userIds, String title, String content, Map<String, String> extras) {
        if (userIds == null || userIds.isEmpty()) {
            log.warn("推送用户ID列表为空, 跳过推送");
            return false;
        }
        if (jpushMockEnabled || StrUtil.isBlank(jpushAppKey) || StrUtil.isBlank(jpushMasterSecret)) {
            return mockJpush(userIds.toString(), title, content, extras);
        }
        return doJpushSend(buildAudienceByAlias(userIds), title, content, extras);
    }

    @Override
    public boolean pushToAppByEnterprise(Long enterpriseId, String title, String content, Map<String, String> extras) {
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysUser::getStatus, 1);
        List<SysUser> users = sysUserMapper.selectList(wrapper);
        if (users == null || users.isEmpty()) {
            log.warn("企业下无有效用户, 跳过推送, enterpriseId={}", enterpriseId);
            return false;
        }
        List<Long> userIds = new ArrayList<>();
        for (SysUser user : users) {
            userIds.add(user.getId());
        }
        return pushToAppByUserIds(userIds, title, content, extras);
    }

    @Override
    public boolean sendSms(String phone, String templateCode, Map<String, String> params) {
        if (StrUtil.isBlank(phone)) {
            log.warn("手机号码为空, 跳过短信发送");
            return false;
        }
        if (smsMockEnabled || StrUtil.isBlank(smsAccessKeyId) || StrUtil.isBlank(smsAccessKeySecret)) {
            return mockSmsSend(phone, templateCode, params);
        }
        return doSmsSend(phone, templateCode, params);
    }

    @Override
    public boolean sendWarningSms(WarningRecord warningRecord, String title, String content) {
        if (warningRecord.getEnterpriseId() == null) {
            log.warn("预警记录缺少企业ID, 无法发送短信, warningNo={}", warningRecord.getWarningNo());
            return false;
        }
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysUser::getStatus, 1);
        wrapper.isNotNull(SysUser::getPhone);
        wrapper.ne(SysUser::getPhone, "");
        List<SysUser> users = sysUserMapper.selectList(wrapper);
        if (users == null || users.isEmpty()) {
            log.warn("企业下无有效手机号用户, 跳过短信发送, enterpriseId={}", warningRecord.getEnterpriseId());
            return false;
        }
        Map<String, String> params = new HashMap<>();
        params.put("title", title);
        params.put("content", content);
        params.put("warningNo", warningRecord.getWarningNo());
        boolean allSuccess = true;
        for (SysUser user : users) {
            try {
                boolean success = sendSms(user.getPhone(), smsTemplateCodeWarning, params);
                if (!success) {
                    allSuccess = false;
                }
            } catch (Exception e) {
                log.error("发送预警短信失败, phone={}, warningNo={}", user.getPhone(), warningRecord.getWarningNo(), e);
                allSuccess = false;
            }
        }
        return allSuccess;
    }

    private boolean doJpushSend(Map<String, Object> audience, String title, String content, Map<String, String> extras) {
        try {
            JSONObject payload = buildJpushPayload(audience, title, content, extras);
            String auth = Base64.getEncoder().encodeToString((jpushAppKey + ":" + jpushMasterSecret).getBytes(StandardCharsets.UTF_8));
            HttpResponse response = HttpRequest.post(jpushUrl)
                    .header("Authorization", "Basic " + auth)
                    .header("Content-Type", "application/json")
                    .body(payload.toString())
                    .timeout(10000)
                    .execute();
            log.info("极光推送请求响应, status={}, body={}", response.getStatus(), response.body());
            if (response.getStatus() == 200) {
                JSONObject respJson = JSONUtil.parseObj(response.body());
                return respJson.getJSONObject("msg_id") != null || "0".equals(respJson.getStr("error", new JSONObject()).getStr("code", ""));
            }
            return false;
        } catch (Exception e) {
            log.error("极光推送异常", e);
            return false;
        }
    }

    private JSONObject buildJpushPayload(Map<String, Object> audience, String title, String content, Map<String, String> extras) {
        JSONObject payload = new JSONObject();
        payload.set("platform", "all");
        payload.set("audience", audience);
        JSONObject notification = new JSONObject();
        JSONObject android = new JSONObject();
        android.set("alert", content);
        android.set("title", title);
        if (extras != null && !extras.isEmpty()) {
            android.set("extras", extras);
        }
        notification.set("android", android);
        JSONObject ios = new JSONObject();
        ios.set("alert", content);
        if (extras != null && !extras.isEmpty()) {
            ios.set("extras", extras);
        }
        ios.set("sound", "default");
        ios.set("badge", "+1");
        notification.set("ios", ios);
        payload.set("notification", notification);
        JSONObject options = new JSONObject();
        options.set("time_to_live", 86400);
        options.set("apns_production", true);
        payload.set("options", options);
        return payload;
    }

    private Map<String, Object> buildAudienceByAlias(List<Long> userIds) {
        Map<String, Object> audience = new HashMap<>();
        List<String> aliases = new ArrayList<>();
        for (Long userId : userIds) {
            aliases.add("user_" + userId);
        }
        audience.put("alias", aliases);
        return audience;
    }

    private boolean mockJpush(String target, String title, String content, Map<String, String> extras) {
        log.info("【极光推送-模拟】发送APP推送, target={}, title={}, content={}, extras={}",
                target, title, content, extras);
        return true;
    }

    private boolean doSmsSend(String phone, String templateCode, Map<String, String> params) {
        try {
            String templateParam = params != null ? JSONUtil.toJsonStr(params) : "{}";
            Map<String, String> smsParams = new HashMap<>();
            smsParams.put("PhoneNumbers", phone);
            smsParams.put("SignName", smsSignName);
            smsParams.put("TemplateCode", templateCode);
            smsParams.put("TemplateParam", templateParam);
            smsParams.put("AccessKeyId", smsAccessKeyId);
            smsParams.put("Action", "SendSms");
            smsParams.put("Version", "2017-05-25");
            smsParams.put("RegionId", "cn-hangzhou");
            smsParams.put("Timestamp", String.valueOf(System.currentTimeMillis()));
            smsParams.put("SignatureNonce", StrUtil.uuid());
            smsParams.put("SignatureMethod", "HMAC-SHA1");
            smsParams.put("SignatureVersion", "1.0");
            smsParams.put("Format", "JSON");
            String signature = generateSignature(smsParams);
            smsParams.put("Signature", signature);
            HttpResponse response = HttpRequest.post("https://dysmsapi.aliyuncs.com/")
                    .form(smsParams)
                    .timeout(10000)
                    .execute();
            log.info("阿里云短信请求响应, status={}, body={}", response.getStatus(), response.body());
            if (response.getStatus() == 200) {
                JSONObject respJson = JSONUtil.parseObj(response.body());
                return "OK".equals(respJson.getStr("Code"));
            }
            return false;
        } catch (Exception e) {
            log.error("阿里云短信发送异常", e);
            return false;
        }
    }

    private String generateSignature(Map<String, String> params) {
        try {
            List<String> keys = new ArrayList<>(params.keySet());
            java.util.Collections.sort(keys);
            StringBuilder query = new StringBuilder();
            for (String key : keys) {
                if (query.length() > 0) {
                    query.append("&");
                }
                query.append(percentEncode(key)).append("=").append(percentEncode(params.get(key)));
            }
            String stringToSign = "POST&" + percentEncode("/") + "&" + percentEncode(query.toString());
            Mac mac = Mac.getInstance("HmacSHA1");
            SecretKeySpec keySpec = new SecretKeySpec((smsAccessKeySecret + "&").getBytes(StandardCharsets.UTF_8), "HmacSHA1");
            mac.init(keySpec);
            byte[] signData = mac.doFinal(stringToSign.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(signData);
        } catch (Exception e) {
            log.error("生成短信签名失败", e);
            return "";
        }
    }

    private String percentEncode(String value) {
        try {
            String encoded = java.net.URLEncoder.encode(value, "UTF-8");
            return encoded.replace("+", "%20")
                    .replace("*", "%2A")
                    .replace("%7E", "~");
        } catch (Exception e) {
            return value;
        }
    }

    private boolean mockSmsSend(String phone, String templateCode, Map<String, String> params) {
        log.info("【阿里云短信-模拟】发送短信, phone={}, templateCode={}, params={}",
                phone, templateCode, params);
        return true;
    }
}
