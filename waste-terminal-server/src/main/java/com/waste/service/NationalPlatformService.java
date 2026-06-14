package com.waste.service;

import com.waste.entity.WasteInRecord;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteTransferOrder;

import java.util.Map;

public interface NationalPlatformService {

    boolean reportTransferOrder(WasteTransferOrder order);

    boolean reportWasteIn(WasteInRecord record);

    boolean reportWasteOut(WasteOutRecord record);

    boolean reportTransferOrderCompletion(WasteTransferOrder order);

    Map<String, Object> queryReportStatus(String bizType, String bizNo);

    String getNationalPlatformBizNo(String localBizNo);
}
