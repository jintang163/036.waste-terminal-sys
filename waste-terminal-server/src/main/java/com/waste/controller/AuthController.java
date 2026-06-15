package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.annotation.RequiresLogin;
import com.waste.common.LoginUser;
import com.waste.common.Result;
import com.waste.common.ResultCode;
import com.waste.entity.SysUser;
import com.waste.entity.UserFace;
import com.waste.entity.FaceAuthRecord;
import com.waste.mapper.SysUserMapper;
import com.waste.service.UserFaceService;
import com.waste.service.FaceAuthRecordService;
import com.waste.utils.JwtUtils;
import com.waste.utils.SmUtils;
import com.waste.utils.UserContext;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import javax.validation.Valid;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/auth")
@Slf4j
public class AuthController {

    @Autowired
    private SysUserMapper sysUserMapper;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private UserFaceService userFaceService;

    @Autowired
    private FaceAuthRecordService faceAuthRecordService;

    @Value("${sm.sm4.key}")
    private String sm4Key;

    @PostMapping("/login")
    public Result<LoginUser> login(@RequestBody @Valid LoginDTO loginDTO, HttpServletRequest request) {
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysUser::getUsername, loginDTO.getUsername());
        SysUser user = sysUserMapper.selectOne(wrapper);

        if (user == null) {
            return Result.fail(ResultCode.USER_PASSWORD_ERROR);
        }

        if (user.getStatus() != 1) {
            return Result.fail(ResultCode.USER_DISABLED);
        }

        String decryptedPassword = SmUtils.sm4Decrypt(sm4Key, user.getPassword());
        if (!decryptedPassword.equals(loginDTO.getPassword())) {
            return Result.fail(ResultCode.USER_PASSWORD_ERROR);
        }

        LoginUser loginUser = new LoginUser();
        loginUser.setUserId(user.getId());
        loginUser.setUsername(user.getUsername());
        loginUser.setRealName(user.getRealName());
        loginUser.setPhone(user.getPhone());
        loginUser.setRole(user.getRole());
        loginUser.setDeptId(user.getDeptId());
        loginUser.setLoginTime(LocalDateTime.now());
        loginUser.setIpAddress(request.getRemoteAddr());

        String token = jwtUtils.generateToken(loginUser);
        loginUser.setToken(token);

        user.setLastLoginTime(LocalDateTime.now());
        user.setLastLoginIp(request.getRemoteAddr());
        sysUserMapper.updateById(user);

        return Result.success(loginUser);
    }

    @PostMapping("/face-login")
    public Result<LoginUser> faceLogin(@RequestBody @Valid FaceLoginDTO faceLoginDTO, HttpServletRequest request) {
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysUser::getUsername, faceLoginDTO.getUsername())
                .eq(SysUser::getId, faceLoginDTO.getUserId());
        SysUser user = sysUserMapper.selectOne(wrapper);

        if (user == null) {
            return Result.fail(ResultCode.USER_PASSWORD_ERROR);
        }

        if (user.getStatus() != 1) {
            return Result.fail(ResultCode.USER_DISABLED);
        }

        LambdaQueryWrapper<UserFace> faceWrapper = new LambdaQueryWrapper<>();
        faceWrapper.eq(UserFace::getUserId, user.getId())
                .eq(UserFace::getStatus, 1);
        UserFace userFace = userFaceService.getOne(faceWrapper, false);

        if (userFace == null) {
            return Result.fail(ResultCode.USER_PASSWORD_ERROR, "用户未录入人脸信息");
        }

        if (faceLoginDTO.getFaceAuthId() != null && !faceLoginDTO.getFaceAuthId().isEmpty()) {
            LambdaQueryWrapper<FaceAuthRecord> authWrapper = new LambdaQueryWrapper<>();
            authWrapper.eq(FaceAuthRecord::getAuthId, faceLoginDTO.getFaceAuthId())
                    .eq(FaceAuthRecord::getAuthStatus, 1);
            FaceAuthRecord authRecord = faceAuthRecordService.getOne(authWrapper, false);
            if (authRecord == null) {
                log.warn("人脸认证记录不存在或认证失败，faceAuthId: {}", faceLoginDTO.getFaceAuthId());
            }
        }

        LoginUser loginUser = new LoginUser();
        loginUser.setUserId(user.getId());
        loginUser.setUsername(user.getUsername());
        loginUser.setRealName(user.getRealName());
        loginUser.setPhone(user.getPhone());
        loginUser.setRole(user.getRole());
        loginUser.setDeptId(user.getDeptId());
        loginUser.setLoginTime(LocalDateTime.now());
        loginUser.setIpAddress(request.getRemoteAddr());

        String token = jwtUtils.generateToken(loginUser);
        loginUser.setToken(token);

        user.setLastLoginTime(LocalDateTime.now());
        user.setLastLoginIp(request.getRemoteAddr());
        sysUserMapper.updateById(user);

        log.info("人脸登录成功，用户: {}, faceAuthId: {}", user.getUsername(), faceLoginDTO.getFaceAuthId());

        return Result.success(loginUser);
    }

    @PostMapping("/logout")
    @RequiresLogin
    public Result<Void> logout() {
        return Result.success();
    }

    @PostMapping("/refresh")
    @RequiresLogin
    public Result<Map<String, String>> refresh() {
        LoginUser loginUser = UserContext.getCurrentUser();
        String newToken = jwtUtils.generateToken(loginUser);
        Map<String, String> result = new HashMap<>();
        result.put("token", newToken);
        return Result.success(result);
    }

    @GetMapping("/info")
    @RequiresLogin
    public Result<LoginUser> info() {
        LoginUser loginUser = UserContext.getCurrentUser();
        return Result.success(loginUser);
    }

    @Data
    public static class LoginDTO {

        @NotBlank(message = "用户名不能为空")
        private String username;

        @NotBlank(message = "密码不能为空")
        private String password;
    }

    @Data
    public static class FaceLoginDTO {

        @NotNull(message = "用户ID不能为空")
        private Long userId;

        @NotBlank(message = "用户名不能为空")
        private String username;

        private String faceAuthId;
    }
}
