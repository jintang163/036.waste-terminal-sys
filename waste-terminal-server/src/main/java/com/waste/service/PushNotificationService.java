package com.waste.service;

import com.waste.entity.WarningRecord;

import java.util.List;
import java.util.Map;

public interface PushNotificationService {

    boolean pushToApp(WarningRecord warningRecord, String title, String content);

    boolean pushToAppByUserIds(List<Long> userIds, String title, String content, Map<String, String> extras);

    boolean pushToAppByEnterprise(Long enterpriseId, String title, String content, Map<String, String> extras);

    boolean sendSms(String phone, String templateCode, Map<String, String> params);

    boolean sendWarningSms(WarningRecord warningRecord, String title, String content);
}
