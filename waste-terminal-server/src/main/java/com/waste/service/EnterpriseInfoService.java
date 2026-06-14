package com.waste.service;

import com.waste.entity.EnterpriseInfo;

import java.util.List;

public interface EnterpriseInfoService {

    EnterpriseInfo getById(Long id);

    List<EnterpriseInfo> list(String enterpriseType, Long enterpriseId);

    void update(EnterpriseInfo enterpriseInfo);
}
