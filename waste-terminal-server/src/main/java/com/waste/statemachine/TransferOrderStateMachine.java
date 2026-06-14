package com.waste.statemachine;

import com.waste.entity.WasteTransferOrder;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;

public interface TransferOrderStateMachine {

    boolean transition(WasteTransferOrder order, TransferOrderEventTypeEnum event, String operatorName, Long operatorId);

    boolean canTransition(WasteTransferOrder order, TransferOrderEventTypeEnum event);

    TransferOrderStatusEnum getTargetStatus(TransferOrderStatusEnum currentStatus, TransferOrderEventTypeEnum event);
}
