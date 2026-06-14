package com.waste.dto;

import lombok.Data;

import javax.validation.constraints.NotBlank;

@Data
public class NationalPlatformWebhookDTO {

    @NotBlank(message = "联单编号不能为空")
    private String nationalOrderNo;

    private String orderNo;

    @NotBlank(message = "事件类型不能为空")
    private String eventType;

    private Integer status;

    private String statusName;

    private String eventTime;

    private String operator;

    private String location;

    private String remark;

    private String signPhoto;

    private String receiptPhoto;

    private String extraData;

    private String signature;

    private String timestamp;

    private String nonce;
}
