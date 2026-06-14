package com.waste.interceptor;

import cn.hutool.core.util.StrUtil;
import com.waste.annotation.RequiresLogin;
import com.waste.annotation.RequiresPermissions;
import com.waste.common.LoginUser;
import com.waste.common.Result;
import com.waste.common.ResultCode;
import com.waste.utils.JwtUtils;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

@Component
public class AuthInterceptor implements HandlerInterceptor {

    @Autowired
    private JwtUtils jwtUtils;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if (!(handler instanceof HandlerMethod)) {
            return true;
        }

        HandlerMethod handlerMethod = (HandlerMethod) handler;

        RequiresLogin classLoginAnnotation = handlerMethod.getBeanType().getAnnotation(RequiresLogin.class);
        RequiresLogin methodLoginAnnotation = handlerMethod.getMethodAnnotation(RequiresLogin.class);

        boolean needLogin = false;
        if (methodLoginAnnotation != null) {
            needLogin = methodLoginAnnotation.required();
        } else if (classLoginAnnotation != null) {
            needLogin = classLoginAnnotation.required();
        }

        if (!needLogin) {
            return true;
        }

        String token = getTokenFromRequest(request);
        if (StrUtil.isBlank(token)) {
            writeUnauthorizedResponse(response, "未登录或token已过期");
            return false;
        }

        LoginUser loginUser = jwtUtils.parseToken(token);
        if (loginUser == null) {
            writeUnauthorizedResponse(response, "token无效或已过期");
            return false;
        }

        loginUser.setIpAddress(getIpAddress(request));
        UserContext.setCurrentUser(loginUser);

        if (!checkPermissions(handlerMethod, loginUser)) {
            writeForbiddenResponse(response, "权限不足");
            return false;
        }

        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) throws Exception {
        UserContext.clear();
    }

    private String getTokenFromRequest(HttpServletRequest request) {
        String token = request.getHeader("Authorization");
        if (StrUtil.isNotBlank(token) && token.startsWith("Bearer ")) {
            return token.substring(7);
        }

        token = request.getParameter("token");
        if (StrUtil.isNotBlank(token)) {
            return token;
        }

        return null;
    }

    private boolean checkPermissions(HandlerMethod handlerMethod, LoginUser loginUser) {
        RequiresPermissions classPermissionAnnotation = handlerMethod.getBeanType().getAnnotation(RequiresPermissions.class);
        RequiresPermissions methodPermissionAnnotation = handlerMethod.getMethodAnnotation(RequiresPermissions.class);

        RequiresPermissions permissionAnnotation = methodPermissionAnnotation != null ?
                methodPermissionAnnotation : classPermissionAnnotation;

        if (permissionAnnotation == null) {
            return true;
        }

        String[] requiredPermissions = permissionAnnotation.value();
        String logic = permissionAnnotation.logic();

        String userRole = loginUser.getRole();
        if (StrUtil.isBlank(userRole)) {
            return false;
        }

        if ("admin".equals(userRole)) {
            return true;
        }

        if ("OR".equals(logic)) {
            for (String permission : requiredPermissions) {
                if (hasPermission(userRole, permission)) {
                    return true;
                }
            }
            return false;
        } else {
            for (String permission : requiredPermissions) {
                if (!hasPermission(userRole, permission)) {
                    return false;
                }
            }
            return true;
        }
    }

    private boolean hasPermission(String userRole, String permission) {
        if ("admin".equals(userRole)) {
            return true;
        }

        switch (permission) {
            case "waste:in:view":
            case "waste:in:add":
            case "waste:in:edit":
            case "waste:in:delete":
            case "waste:out:view":
            case "waste:out:add":
            case "waste:out:edit":
            case "waste:out:delete":
            case "waste:order:view":
            case "waste:order:add":
            case "waste:order:edit":
            case "waste:order:delete":
            case "waste:check:view":
            case "waste:check:add":
            case "waste:check:edit":
            case "waste:check:delete":
            case "warning:view":
            case "warning:handle":
            case "sync:view":
            case "sync:upload":
            case "sync:download":
                return "operator".equals(userRole) || "manager".equals(userRole) || "admin".equals(userRole);
            default:
                return false;
        }
    }

    private String getIpAddress(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("Proxy-Client-IP");
        }
        if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("WL-Proxy-Client-IP");
        }
        if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_CLIENT_IP");
        }
        if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_X_FORWARDED_FOR");
        }
        if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        return ip;
    }

    private void writeUnauthorizedResponse(HttpServletResponse response, String message) throws IOException {
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        Result<Void> result = Result.fail(ResultCode.UNAUTHORIZED.getCode(), message);
        response.getWriter().write(com.alibaba.fastjson.JSON.toJSONString(result));
    }

    private void writeForbiddenResponse(HttpServletResponse response, String message) throws IOException {
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        Result<Void> result = Result.fail(ResultCode.FORBIDDEN.getCode(), message);
        response.getWriter().write(com.alibaba.fastjson.JSON.toJSONString(result));
    }
}
