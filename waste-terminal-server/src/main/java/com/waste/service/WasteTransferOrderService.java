package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.TransferOrderDTO;
import com.waste.entity.WasteTransferOrder;
import com.waste.vo.TransferOrderVO;

import java.util.List;

public interface WasteTransferOrderService {

    IPage<WasteTransferOrder> page(PageQuery pageQuery, WasteTransferOrder transferOrder, Long enterpriseId);

    TransferOrderVO getDetailById(Long id);

    WasteTransferOrder getByOrderNo(String orderNo);

    void create(TransferOrderDTO dto, Long enterpriseId);

    void update(Long id, TransferOrderDTO dto);

    void delete(Long id);

    void confirm(Long id);

    void batchSync(List<TransferOrderDTO> list, Long enterpriseId);

    void submit(Long id);

    void report(Long id);

    void sign(Long id, String signPhoto);

    void complete(Long id, String receiptPhoto);

    void cancel(Long id);

    String getQrCode(Long id);

    List<WasteTransferOrder> getPendingReportList(Long enterpriseId);

    List<WasteTransferOrder> getPendingSyncList(Long enterpriseId);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    WasteTransferOrder createTransferOrder(TransferOrderDTO dto);

    void signTransferOrder(Long orderId, String signPhoto);

    void completeTransferOrder(Long orderId, String receiptPhoto);

    void cancelTransferOrder(Long orderId, String reason);

    List<WasteTransferOrder> queryList(WasteTransferOrder transferOrder, Long enterpriseId);

    IPage<WasteTransferOrder> queryPage(PageQuery pageQuery, WasteTransferOrder transferOrder, Long enterpriseId);
}
