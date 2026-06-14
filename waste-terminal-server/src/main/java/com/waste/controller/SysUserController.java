package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.common.ResultCode;
import com.waste.entity.SysUser;
import com.waste.mapper.SysUserMapper;
import com.waste.utils.SmUtils;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

@Slf4j
@RestController
@RequestMapping("/user")
@RequiresLogin
public class SysUserController {

    @Autowired
    private SysUserMapper sysUserMapper;

    @Value("${sm.sm4.key}")
    private String sm4Key;

    @GetMapping("/page")
    public Result<PageResult<SysUser>> page(PageQuery pageQuery,
                                             @RequestParam(required = false) String username,
                                             @RequestParam(required = false) String realName,
                                             @RequestParam(required = false) String role,
                                             @RequestParam(required = false) Integer status) {
        Page<SysUser> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        if (username != null && !username.isEmpty()) {
            wrapper.like(SysUser::getUsername, username);
        }
        if (realName != null && !realName.isEmpty()) {
            wrapper.like(SysUser::getRealName, realName);
        }
        if (role != null && !role.isEmpty()) {
            wrapper.eq(SysUser::getRole, role);
        }
        if (status != null) {
            wrapper.eq(SysUser::getStatus, status);
        }
        wrapper.orderByDesc(SysUser::getCreateTime);
        IPage<SysUser> result = sysUserMapper.selectPage(page, wrapper);
        PageResult<SysUser> pageResult = PageResult.of(result.getTotal(), result.getCurrent(),
                result.getSize(), result.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<SysUser> getById(@PathVariable Long id) {
        SysUser user = sysUserMapper.selectById(id);
        return Result.success(user);
    }

    @PostMapping
    public Result<Void> add(@RequestBody @Valid SysUser user) {
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysUser::getUsername, user.getUsername());
        Long count = sysUserMapper.selectCount(wrapper);
        if (count > 0) {
            return Result.fail(ResultCode.PARAM_ERROR.getCode(), "用户名已存在");
        }
        user.setPassword(SmUtils.sm4Encrypt(sm4Key, user.getPassword()));
        if (user.getStatus() == null) {
            user.setStatus(1);
        }
        sysUserMapper.insert(user);
        return Result.success();
    }

    @PutMapping
    public Result<Void> update(@RequestBody SysUser user) {
        user.setPassword(null);
        sysUserMapper.updateById(user);
        return Result.success();
    }

    @PutMapping("/password")
    public Result<Void> changePassword(@RequestBody @Valid ChangePasswordDTO dto) {
        SysUser user = sysUserMapper.selectById(dto.getUserId());
        if (user == null) {
            return Result.fail(ResultCode.USER_NOT_FOUND.getCode(), ResultCode.USER_NOT_FOUND.getMessage());
        }
        String oldPassword = SmUtils.sm4Decrypt(sm4Key, user.getPassword());
        if (!oldPassword.equals(dto.getOldPassword())) {
            return Result.fail(ResultCode.USER_PASSWORD_ERROR.getCode(), ResultCode.USER_PASSWORD_ERROR.getMessage());
        }
        SysUser updateUser = new SysUser();
        updateUser.setId(dto.getUserId());
        updateUser.setPassword(SmUtils.sm4Encrypt(sm4Key, dto.getNewPassword()));
        sysUserMapper.updateById(updateUser);
        return Result.success();
    }

    @PutMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestParam Integer status) {
        SysUser user = new SysUser();
        user.setId(id);
        user.setStatus(status);
        sysUserMapper.updateById(user);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        sysUserMapper.deleteById(id);
        return Result.success();
    }

    @Data
    public static class ChangePasswordDTO {
        @NotNull
        private Long userId;
        @NotBlank
        private String oldPassword;
        @NotBlank
        private String newPassword;
    }
}
