package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.UserFace;

import java.util.List;

public interface UserFaceService {

    IPage<UserFace> page(PageQuery pageQuery, UserFace userFace, Long enterpriseId);

    UserFace getById(Long id);

    UserFace getByUserId(Long userId, Long enterpriseId);

    UserFace getByUsername(String username, Long enterpriseId);

    UserFace getByFaceId(String faceId, Long enterpriseId);

    void add(UserFace userFace, Long enterpriseId);

    void update(Long id, UserFace userFace);

    void delete(Long id);

    List<UserFace> listByEnterpriseId(Long enterpriseId);

    void updateStatus(Long id, Integer status);
}
