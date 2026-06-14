package com.waste.enums;

import lombok.Getter;

@Getter
public enum TransferOrderStatusEnum {

    DRAFT(0, "待提交", "草稿状态，可编辑"),
    PENDING_REPORT(1, "待上报", "已提交，待上报国家平台"),
    PENDING_TRANSPORT(2, "待运输", "已成功上报国家平台，待起运"),
    IN_TRANSIT(3, "运输中", "已起运，正在运输途中"),
    ARRIVED(4, "已到达", "已到达接收单位"),
    SIGNED(5, "已签收", "接收单位已签收"),
    COMPLETED(6, "已完成", "联单流程全部完成"),
    CANCELLED(-1, "已取消", "联单已取消");

    private final Integer code;
    private final String name;
    private final String description;

    TransferOrderStatusEnum(Integer code, String name, String description) {
        this.code = code;
        this.name = name;
        this.description = description;
    }

    public static TransferOrderStatusEnum getByCode(Integer code) {
        if (code == null) {
            return null;
        }
        for (TransferOrderStatusEnum status : values()) {
            if (status.getCode().equals(code)) {
                return status;
            }
        }
        return null;
    }

    public static String getNameByCode(Integer code) {
        TransferOrderStatusEnum status = getByCode(code);
        return status != null ? status.getName() : "未知";
    }

    public boolean canTransitionTo(TransferOrderStatusEnum targetStatus) {
        if (this == targetStatus) {
            return false;
        }
        if (this == CANCELLED || this == COMPLETED) {
            return false;
        }
        switch (this) {
            case DRAFT:
                return targetStatus == PENDING_REPORT || targetStatus == CANCELLED;
            case PENDING_REPORT:
                return targetStatus == PENDING_TRANSPORT || targetStatus == CANCELLED;
            case PENDING_TRANSPORT:
                return targetStatus == IN_TRANSIT || targetStatus == CANCELLED;
            case IN_TRANSIT:
                return targetStatus == ARRIVED;
            case ARRIVED:
                return targetStatus == SIGNED;
            case SIGNED:
                return targetStatus == COMPLETED;
            default:
                return false;
        }
    }
}
