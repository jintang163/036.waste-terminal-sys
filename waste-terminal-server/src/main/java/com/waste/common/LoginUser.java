package com.waste.common;

import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
public class LoginUser implements Serializable {

    private static final long serialVersionUID = 1L;

    private Long userId;

    private String username;

    private String realName;

    private String phone;

    private String role;

    private Long deptId;

    private Long enterpriseId;

    private String token;

    private LocalDateTime loginTime;

    private String ipAddress;
}
