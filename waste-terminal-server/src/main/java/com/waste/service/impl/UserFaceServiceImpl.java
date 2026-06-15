package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.UserFace;
import com.waste.mapper.UserFaceMapper;
import com.waste.service.UserFaceService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class UserFaceServiceImpl implements UserFaceService {

    @Autowired
    private UserFaceMapper userFaceMapper;

    @Override
    public IPage<UserFace> page(PageQuery pageQuery, UserFace userFace, Long enterpriseId) {
        Page<UserFace> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<UserFace> wrapper = buildQueryWrapper(userFace, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(UserFace::getCreateTime);
        }
        return userFaceMapper.selectPage(page, wrapper);
    }

    @Override
    public UserFace getById(Long id) {
        UserFace userFace = userFaceMapper.selectById(id);
        if (userFace == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return userFace;
    }

    @Override
    public UserFace getByUserId(Long userId, Long enterpriseId) {
        LambdaQueryWrapper<UserFace> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(UserFace::getUserId, userId);
        if (enterpriseId != null) {
            wrapper.eq(UserFace::getEnterpriseId, enterpriseId);
        }
        return userFaceMapper.selectOne(wrapper);
    }

    @Override
    public UserFace getByUsername(String username, Long enterpriseId) {
        LambdaQueryWrapper<UserFace> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(UserFace::getUsername, username);
        if (enterpriseId != null) {
            wrapper.eq(UserFace::getEnterpriseId, enterpriseId);
        }
        return userFaceMapper.selectOne(wrapper);
    }

    @Override
    public UserFace getByFaceId(String faceId, Long enterpriseId) {
        LambdaQueryWrapper<UserFace> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(UserFace::getFaceId, faceId);
        if (enterpriseId != null) {
            wrapper.eq(UserFace::getEnterpriseId, enterpriseId);
        }
        return userFaceMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(UserFace userFace, Long enterpriseId) {
        if (userFace.getStatus() == null) {
            userFace.setStatus(1);
        }
        if (StrUtil.isBlank(userFace.getFaceId())) {
            userFace.setFaceId("FACE" + System.currentTimeMillis());
        }
        if (enterpriseId != null) {
            userFace.setEnterpriseId(enterpriseId);
        }
        userFaceMapper.insert(userFace);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, UserFace userFace) {
        UserFace exist = getById(id);
        if (userFace.getFaceFeature() != null) {
            exist.setFaceFeature(userFace.getFaceFeature());
        }
        if (userFace.getFaceImage() != null) {
            exist.setFaceImage(userFace.getFaceImage());
        }
        if (userFace.getStatus() != null) {
            exist.setStatus(userFace.getStatus());
        }
        if (userFace.getEnrollQuality() != null) {
            exist.setEnrollQuality(userFace.getEnrollQuality());
        }
        if (userFace.getDeviceId() != null) {
            exist.setDeviceId(userFace.getDeviceId());
        }
        if (userFace.getRemark() != null) {
            exist.setRemark(userFace.getRemark());
        }
        userFaceMapper.updateById(exist);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        userFaceMapper.deleteById(id);
    }

    @Override
    public List<UserFace> listByEnterpriseId(Long enterpriseId) {
        LambdaQueryWrapper<UserFace> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(UserFace::getEnterpriseId, enterpriseId);
        }
        wrapper.eq(UserFace::getStatus, 1);
        wrapper.orderByDesc(UserFace::getCreateTime);
        return userFaceMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateStatus(Long id, Integer status) {
        UserFace exist = getById(id);
        exist.setStatus(status);
        userFaceMapper.updateById(exist);
    }

    private LambdaQueryWrapper<UserFace> buildQueryWrapper(UserFace userFace, Long enterpriseId) {
        LambdaQueryWrapper<UserFace> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(UserFace::getEnterpriseId, enterpriseId);
        }
        if (userFace != null) {
            if (userFace.getUserId() != null) {
                wrapper.eq(UserFace::getUserId, userFace.getUserId());
            }
            if (StrUtil.isNotBlank(userFace.getUsername())) {
                wrapper.like(UserFace::getUsername, userFace.getUsername());
            }
            if (StrUtil.isNotBlank(userFace.getFaceId())) {
                wrapper.eq(UserFace::getFaceId, userFace.getFaceId());
            }
            if (userFace.getStatus() != null) {
                wrapper.eq(UserFace::getStatus, userFace.getStatus());
            }
        }
        return wrapper;
    }
}
