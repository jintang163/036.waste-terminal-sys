package com.waste.service;

import com.waste.dto.PlatformReportDashboardDTO;
import com.waste.entity.PlatformReportRecord;
import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteTransferOrder;

import java.util.List;
import java.util.Map;

public interface NationalPlatformService {

    boolean reportTransferOrder(WasteTransferOrder order);

    boolean reportWasteOut(WasteOutRecord record);

    boolean reportTransferOrderCompletion(WasteTransferOrder order);

    Map<String, Object> queryReportStatus(String bizType, String bizNo);

    String getNationalPlatformBizNo(String localBizNo);

    boolean reportWasteIn(WasteInRecord record);

    boolean reportWasteInIot(WasteInRecord record);

    boolean reportElectronicManifest(WasteTransferOrder order);

    boolean reportWasteOutIot(WasteOutRecord record);

    PlatformReportRecord createReportRecord(String bizType, String bizId, String bizNo, String apiPath, String requestPayload, Long enterpriseId);

    void updateReportRecordSuccess(PlatformReportRecord record, String responsePayload, String nationalBizNo, long durationMs);

    void updateReportRecordFailed(PlatformReportRecord record, String failReason, long durationMs);

    void updateReportRecordRetrying(PlatformReportRecord record, String failReason);

    PlatformReportDashboardDTO.ReportStatistics getReportStatistics(Long enterpriseId);

    List<PlatformReportDashboardDTO.FailedReportItem> getFailedReports(Long enterpriseId, Integer limit);

    List<PlatformReportDashboardDTO.RetryQueueItem> getRetryQueue(Long enterpriseId);

    PlatformReportDashboardDTO.ManualRetryResult manualRetry(Long recordId, boolean forceResend);
}
