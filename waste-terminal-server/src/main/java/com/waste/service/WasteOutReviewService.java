package com.waste.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.dto.WasteOutReviewDTO;
import com.waste.entity.WasteOutReview;

import java.util.List;
import java.util.Map;

public interface WasteOutReviewService {

    IPage<WasteOutReview> page(PageQuery pageQuery, WasteOutReview review, Long enterpriseId);

    WasteOutReview getById(Long id);

    WasteOutReview getByReviewNo(String reviewNo);

    WasteOutReview getByOutNo(String outNo);

    Map<String, Object> createReview(WasteOutReviewDTO dto, Long enterpriseId);

    Map<String, Object> confirmReview(String reviewNo, WasteOutReviewDTO dto, Long enterpriseId);

    void delete(Long id);

    boolean checkByOfflineId(String offlineId, Long enterpriseId);

    List<WasteOutReview> getPendingSyncList(Long enterpriseId);

    void batchSync(List<WasteOutReviewDTO> list, Long enterpriseId);
}
