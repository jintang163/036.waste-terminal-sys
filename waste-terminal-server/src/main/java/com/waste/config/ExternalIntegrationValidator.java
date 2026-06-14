package com.waste.config;

import cn.hutool.core.util.StrUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;

@Slf4j
@Configuration
@Order(1)
public class ExternalIntegrationValidator implements CommandLineRunner {

    @Value("${waste.national-platform.mock-enabled:false}")
    private boolean nationalPlatformMockEnabled;

    @Value("${waste.national-platform.app-id:}")
    private String nationalPlatformAppId;

    @Value("${waste.national-platform.app-secret:}")
    private String nationalPlatformAppSecret;

    @Value("${waste.national-platform.url:}")
    private String nationalPlatformUrl;

    @Value("${sm.sm4.key:}")
    private String sm4Key;

    @Value("${sm.sm2.public-key:}")
    private String sm2PublicKey;

    @Value("${sm.sm2.private-key:}")
    private String sm2PrivateKey;

    @Value("${push.jpush.mock-enabled:false}")
    private boolean jpushMockEnabled;

    @Value("${push.jpush.app-key:}")
    private String jpushAppKey;

    @Value("${push.jpush.master-secret:}")
    private String jpushMasterSecret;

    @Value("${sms.aliyun.mock-enabled:false}")
    private boolean smsMockEnabled;

    @Value("${sms.aliyun.access-key-id:}")
    private String smsAccessKeyId;

    @Value("${sms.aliyun.access-key-secret:}")
    private String smsAccessKeySecret;

    @Override
    public void run(String... args) {
        validateNationalPlatform();
        validatePushService();
        validateSmsService();
        validateSmCrypto();
    }

    private void validateNationalPlatform() {
        log.info("========================================");
        log.info("【国家环保平台对接配置校验】");
        log.info("模拟模式: {}", nationalPlatformMockEnabled ? "开启" : "关闭");
        log.info("平台地址: {}", nationalPlatformUrl);

        if (nationalPlatformMockEnabled) {
            log.warn("⚠️  国家环保平台当前为模拟模式，上报数据不会发送到真实平台！");
            return;
        }

        boolean hasError = false;
        if (StrUtil.isBlank(nationalPlatformAppId)) {
            log.error("❌ 国家环保平台 AppID 未配置");
            hasError = true;
        }
        if (StrUtil.isBlank(nationalPlatformAppSecret)) {
            log.error("❌ 国家环保平台 AppSecret 未配置");
            hasError = true;
        }
        if (StrUtil.isBlank(nationalPlatformUrl)) {
            log.error("❌ 国家环保平台 URL 未配置");
            hasError = true;
        }

        if (!hasError) {
            log.info("✅ 国家环保平台配置校验通过");
            log.info("   AppID: {}", maskSensitive(nationalPlatformAppId));
            log.info("   AppSecret: {}", maskSensitive(nationalPlatformAppSecret));
        }
    }

    private void validatePushService() {
        log.info("========================================");
        log.info("【极光推送配置校验】");
        log.info("模拟模式: {}", jpushMockEnabled ? "开启" : "关闭");

        if (jpushMockEnabled) {
            log.warn("⚠️  极光推送当前为模拟模式，推送消息不会发送到真实设备！");
            return;
        }

        boolean hasError = false;
        if (StrUtil.isBlank(jpushAppKey)) {
            log.error("❌ 极光推送 AppKey 未配置");
            hasError = true;
        }
        if (StrUtil.isBlank(jpushMasterSecret)) {
            log.error("❌ 极光推送 MasterSecret 未配置");
            hasError = true;
        }

        if (!hasError) {
            log.info("✅ 极光推送配置校验通过");
            log.info("   AppKey: {}", maskSensitive(jpushAppKey));
            log.info("   MasterSecret: {}", maskSensitive(jpushMasterSecret));
        }
    }

    private void validateSmsService() {
        log.info("========================================");
        log.info("【阿里云短信网关配置校验】");
        log.info("模拟模式: {}", smsMockEnabled ? "开启" : "关闭");

        if (smsMockEnabled) {
            log.warn("⚠️  阿里云短信当前为模拟模式，短信不会真实发送！");
            return;
        }

        boolean hasError = false;
        if (StrUtil.isBlank(smsAccessKeyId)) {
            log.error("❌ 阿里云短信 AccessKeyId 未配置");
            hasError = true;
        }
        if (StrUtil.isBlank(smsAccessKeySecret)) {
            log.error("❌ 阿里云短信 AccessKeySecret 未配置");
            hasError = true;
        }

        if (!hasError) {
            log.info("✅ 阿里云短信配置校验通过");
            log.info("   AccessKeyId: {}", maskSensitive(smsAccessKeyId));
            log.info("   AccessKeySecret: {}", maskSensitive(smsAccessKeySecret));
        }
    }

    private void validateSmCrypto() {
        log.info("========================================");
        log.info("【国密加密配置校验】");

        boolean hasError = false;
        if (StrUtil.isBlank(sm4Key)) {
            log.error("❌ SM4 加密密钥未配置");
            hasError = true;
        } else if (sm4Key.length() != 32) {
            log.error("❌ SM4 密钥长度不正确，需要32位16进制字符（128位）");
            hasError = true;
        }

        if (StrUtil.isBlank(sm2PublicKey)) {
            log.warn("⚠️  SM2 公钥未配置，将使用 SM3 摘要签名替代 SM2 签名");
        }
        if (StrUtil.isBlank(sm2PrivateKey)) {
            log.warn("⚠️  SM2 私钥未配置，将使用 SM3 摘要签名替代 SM2 签名");
        }

        if (!hasError) {
            log.info("✅ 国密加密配置校验通过");
            log.info("   SM4 密钥: {}", maskSensitive(sm4Key));
            log.info("   SM2 签名方式: {}", StrUtil.isNotBlank(sm2PrivateKey) ? "SM2" : "SM3");
        }
        log.info("========================================");
    }

    private String maskSensitive(String value) {
        if (StrUtil.isBlank(value)) {
            return value;
        }
        if (value.length() <= 8) {
            return value.substring(0, 4) + "****" + value.substring(value.length() - 4);
        }
        return value.substring(0, 2) + "****" + value.substring(value.length() - 2);
    }
}
