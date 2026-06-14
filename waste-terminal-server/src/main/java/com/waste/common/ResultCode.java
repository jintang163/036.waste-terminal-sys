package com.waste.common;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 响应状态码枚举
 */
@Getter
@AllArgsConstructor
public enum ResultCode {

    SUCCESS(200, "操作成功"),
    FAIL(500, "操作失败"),
    PARAM_ERROR(400, "参数错误"),
    UNAUTHORIZED(401, "未授权"),
    FORBIDDEN(403, "禁止访问"),
    NOT_FOUND(404, "资源不存在"),
    SYSTEM_ERROR(500, "系统错误"),

    // 业务错误码
    WASTE_CODE_EXIST(1001, "危废代码已存在"),
    CONTAINER_CODE_EXIST(1002, "容器编号已存在"),
    CONTAINER_NOT_FOUND(1003, "容器不存在"),
    CONTAINER_IN_USE(1004, "容器正在使用中"),
    WASTE_NOT_FOUND(1005, "危废名录不存在"),
    INVENTORY_NOT_ENOUGH(1006, "库存不足"),
    OFFLINE_ID_EXIST(1007, "离线数据已同步"),
    TRANSFER_ORDER_EXIST(1008, "转移联单已存在"),
    ENTERPRISE_NOT_FOUND(1009, "企业不存在"),
    USER_NOT_FOUND(1010, "用户不存在"),
    USER_PASSWORD_ERROR(1011, "用户名或密码错误"),
    USER_DISABLED(1012, "用户已禁用"),

    // 同步相关
    SYNC_DATA_ERROR(2001, "同步数据异常"),
    SYNC_DATA_EMPTY(2002, "同步数据为空"),

    // 文件相关
    FILE_UPLOAD_ERROR(3001, "文件上传失败"),
    FILE_NOT_FOUND(3002, "文件不存在"),
    FILE_SIZE_EXCEED(3003, "文件大小超出限制"),

    // 国家平台对接
    NATIONAL_PLATFORM_ERROR(4001, "国家平台对接异常"),
    NATIONAL_PLATFORM_REPORT_FAIL(4002, "上报国家平台失败");

    private final Integer code;
    private final String message;
}
