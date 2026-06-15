package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.entity.Camera;

import java.util.List;

public interface CameraService {

    IPage<Camera> page(PageQuery pageQuery, Camera camera, Long enterpriseId);

    Camera getById(Long id);

    void add(Camera camera, Long enterpriseId);

    void update(Long id, Camera camera);

    void delete(Long id);

    List<Camera> listByEnterpriseId(Long enterpriseId);

    Camera getByCode(String cameraCode, Long enterpriseId);

    void updateStatus(Long id, Integer status);

    void toggleAi(Long id, Boolean enabled);
}
