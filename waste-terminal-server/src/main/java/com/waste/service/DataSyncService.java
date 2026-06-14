package com.waste.service;

import com.waste.dto.DeltaSyncDTO;
import com.waste.dto.DeltaSyncResultDTO;

import java.util.Map;

public interface DataSyncService {

    DeltaSyncResultDTO performDeltaSync(DeltaSyncDTO request, Long enterpriseId);

    Map<String, DeltaSyncResultDTO.VersionInfo> getCurrentVersions(Long enterpriseId);

    void bumpVersion(String dataType, Long enterpriseId, String changeSummary, Long recordCount);
}
