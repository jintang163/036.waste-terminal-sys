package com.waste.utils;

import cn.hutool.core.date.DateUtil;
import cn.hutool.core.util.StrUtil;
import cn.hutool.jwt.JWT;
import cn.hutool.jwt.JWTUtil;
import cn.hutool.jwt.signers.JWTSigner;
import cn.hutool.jwt.signers.JWTSignerUtil;
import com.waste.common.LoginUser;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Component
public class JwtUtils {

    private static final String USER_ID_KEY = "userId";
    private static final String USERNAME_KEY = "username";
    private static final String REAL_NAME_KEY = "realName";
    private static final String ROLE_KEY = "role";
    private static final String ENTERPRISE_ID_KEY = "enterpriseId";
    private static final String EXPIRE_TIME_KEY = "expireTime";

    @Value("${jwt.secret:waste-terminal-secret-key-2024}")
    private String secret;

    @Value("${jwt.expire-hours:24}")
    private int expireHours;

    public String generateToken(LoginUser loginUser) {
        Map<String, Object> claims = new HashMap<>();
        claims.put(USER_ID_KEY, loginUser.getUserId());
        claims.put(USERNAME_KEY, loginUser.getUsername());
        claims.put(REAL_NAME_KEY, loginUser.getRealName());
        claims.put(ROLE_KEY, loginUser.getRole());
        claims.put(ENTERPRISE_ID_KEY, loginUser.getEnterpriseId());

        Date now = new Date();
        Date expireTime = DateUtil.offsetHour(now, expireHours);
        claims.put(EXPIRE_TIME_KEY, expireTime.getTime());

        JWTSigner signer = JWTSignerUtil.hs256(secret.getBytes(StandardCharsets.UTF_8));
        return JWTUtil.createToken(claims, signer);
    }

    public LoginUser parseToken(String token) {
        if (StrUtil.isBlank(token)) {
            return null;
        }

        try {
            JWT jwt = JWTUtil.parseToken(token);
            JWTSigner signer = JWTSignerUtil.hs256(secret.getBytes(StandardCharsets.UTF_8));

            if (!jwt.verify(signer)) {
                return null;
            }

            Long expireTime = jwt.getPayload(EXPIRE_TIME_KEY) != null ?
                    Long.valueOf(jwt.getPayload(EXPIRE_TIME_KEY).toString()) : null;
            if (expireTime == null || System.currentTimeMillis() > expireTime) {
                return null;
            }

            LoginUser loginUser = new LoginUser();
            loginUser.setUserId(jwt.getPayload(USER_ID_KEY) != null ?
                    Long.valueOf(jwt.getPayload(USER_ID_KEY).toString()) : null);
            loginUser.setUsername(jwt.getPayload(USERNAME_KEY) != null ?
                    jwt.getPayload(USERNAME_KEY).toString() : null);
            loginUser.setRealName(jwt.getPayload(REAL_NAME_KEY) != null ?
                    jwt.getPayload(REAL_NAME_KEY).toString() : null);
            loginUser.setRole(jwt.getPayload(ROLE_KEY) != null ?
                    jwt.getPayload(ROLE_KEY).toString() : null);
            loginUser.setEnterpriseId(jwt.getPayload(ENTERPRISE_ID_KEY) != null ?
                    Long.valueOf(jwt.getPayload(ENTERPRISE_ID_KEY).toString()) : null);
            loginUser.setToken(token);

            return loginUser;
        } catch (Exception e) {
            return null;
        }
    }

    public boolean validateToken(String token) {
        if (StrUtil.isBlank(token)) {
            return false;
        }

        try {
            JWT jwt = JWTUtil.parseToken(token);
            JWTSigner signer = JWTSignerUtil.hs256(secret.getBytes(StandardCharsets.UTF_8));

            if (!jwt.verify(signer)) {
                return false;
            }

            Long expireTime = jwt.getPayload(EXPIRE_TIME_KEY) != null ?
                    Long.valueOf(jwt.getPayload(EXPIRE_TIME_KEY).toString()) : null;
            return expireTime != null && System.currentTimeMillis() <= expireTime;
        } catch (Exception e) {
            return false;
        }
    }

    public long getRemainingTime(String token) {
        if (StrUtil.isBlank(token)) {
            return 0;
        }

        try {
            JWT jwt = JWTUtil.parseToken(token);
            Long expireTime = jwt.getPayload(EXPIRE_TIME_KEY) != null ?
                    Long.valueOf(jwt.getPayload(EXPIRE_TIME_KEY).toString()) : null;
            if (expireTime == null) {
                return 0;
            }
            return Math.max(0, expireTime - System.currentTimeMillis());
        } catch (Exception e) {
            return 0;
        }
    }
}
