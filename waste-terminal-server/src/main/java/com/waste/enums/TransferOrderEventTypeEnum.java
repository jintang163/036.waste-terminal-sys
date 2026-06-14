package com.waste.enums;

import lombok.Getter;

@Getter
public enum TransferOrderEventTypeEnum {

    CREATE(1, "创建联单", "创建转移联单"),
    SUBMIT(2, "提交联单", "提交联单，进入待上报状态"),
    REPORT_SUCCESS(3, "上报成功", "成功上报国家平台"),
    REPORT_FAIL(4, "上报失败", "上报国家平台失败"),
    START_TRANSPORT(5, "开始运输", "车辆起运，进入运输中状态"),
    ARRIVE(6, "到达", "到达接收单位"),
    SIGN(7, "签收", "接收单位签收"),
    UPLOAD_RECEIPT(8, "上传回执", "上传签收回执照片"),
    COMPLETE(9, "完成", "联单流程完成"),
    CANCEL(10, "取消", "取消联单"),
    STATUS_SYNC(11, "状态同步", "从国家平台同步状态"),
    WEBHOOK_NOTIFY(12, "Webhook通知", "接收国家平台Webhook通知");

    private final Integer code;
    private final String name;
    private final String description;

    TransferOrderEventTypeEnum(Integer code, String name, String description) {
        this.code = code;
        this.name = name;
        this.description = description;
    }

    public static TransferOrderEventTypeEnum getByCode(Integer code) {
        if (code == null) {
            return null;
        }
        for (TransferOrderEventTypeEnum event : values()) {
            if (event.getCode().equals(code)) {
                return event;
            }
        }
        return null;
    }

    public static String getNameByCode(Integer code) {
        TransferOrderEventTypeEnum event = getByCode(code);
        return event != null ? event.getName() : "未知";
    }
}
