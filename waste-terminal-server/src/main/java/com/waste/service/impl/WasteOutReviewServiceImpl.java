package com.waste.service.impl;

import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.WasteOutReviewDTO;
import com.waste.entity.WasteCatalog;
import com.waste.entity.WasteOutRecord;
import com.waste.entity.WasteOutReview;
import com.waste.mapper.WasteCatalogMapper;
import com.waste.mapper.WasteOutRecordMapper;
import com.waste.mapper.WasteOutReviewMapper;
import com.waste.service.WasteOutReviewService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class WasteOutReviewServiceImpl implements WasteOutReviewService {

    @Autowired
    private WasteOutReviewMapper reviewMapper;

    @Autowired
    private WasteOutRecordMapper outRecordMapper;

    @Autowired
    private WasteCatalogMapper catalogMapper;

    @Override
    public IPage<WasteOutReview> page(PageQuery pageQuery, WasteOutReview review, Long enterpriseId) {
        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getEnterpriseId, enterpriseId);
        wrapper.orderByDesc(WasteOutReview::getCreateTime);
        return reviewMapper.selectPage(new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize()), wrapper);
    }

    @Override
    public WasteOutReview getById(Long id) {
        return reviewMapper.selectById(id);
    }

    @Override
    public WasteOutReview getByReviewNo(String reviewNo) {
        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getReviewNo, reviewNo);
        return reviewMapper.selectOne(wrapper);
    }

    @Override
    public WasteOutReview getByOutNo(String outNo) {
        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getOutNo, outNo);
        wrapper.orderByDesc(WasteOutReview::getCreateTime);
        wrapper.last("limit 1");
        return reviewMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> createReview(WasteOutReviewDTO dto, Long enterpriseId) {
        Map<String, Object> result = new HashMap<>();

        WasteOutRecord outRecord = null;
        if (dto.getOutRecordId() != null) {
            outRecord = outRecordMapper.selectById(dto.getOutRecordId());
        }
        if (outRecord == null && StrUtil.isNotBlank(dto.getOutNo())) {
            LambdaQueryWrapper<WasteOutRecord> outWrapper = new LambdaQueryWrapper<>();
            outWrapper.eq(WasteOutRecord::getOutNo, dto.getOutNo());
            outWrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
            outWrapper.last("limit 1");
            outRecord = outRecordMapper.selectOne(outWrapper);
        }
        if (outRecord == null && StrUtil.isNotBlank(dto.getOutOfflineId())) {
            LambdaQueryWrapper<WasteOutRecord> outWrapper = new LambdaQueryWrapper<>();
            outWrapper.eq(WasteOutRecord::getOfflineId, dto.getOutOfflineId());
            outWrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
            outWrapper.last("limit 1");
            outRecord = outRecordMapper.selectOne(outWrapper);
        }
        if (outRecord == null) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "出库记录不存在，outNo=" + dto.getOutNo() + ", outOfflineId=" + dto.getOutOfflineId());
        }

        WasteCatalog catalog = catalogMapper.selectById(outRecord.getWasteId());
        boolean needReview = false;
        String reviewType = "";
        if (catalog != null) {
            if (catalog.getIsHighValue() != null && catalog.getIsHighValue() == 1) {
                needReview = true;
                reviewType = "high_value";
            }
            if (catalog.getIsHighToxic() != null && catalog.getIsHighToxic() == 1) {
                needReview = true;
                reviewType = reviewType.isEmpty() ? "high_toxic" : "high_value,high_toxic";
            }
            if (catalog.getRequireDoubleReview() != null && catalog.getRequireDoubleReview() == 1) {
                needReview = true;
            }
        }

        if (!needReview) {
            result.put("needReview", false);
            result.put("message", "该危废无需双人复核");
            return result;
        }

        LambdaQueryWrapper<WasteOutReview> existingWrapper = new LambdaQueryWrapper<>();
        existingWrapper.eq(WasteOutReview::getOutNo, dto.getOutNo());
        existingWrapper.in(WasteOutReview::getReviewResult, 1, 2);
        Long existingCount = reviewMapper.selectCount(existingWrapper);
        if (existingCount != null && existingCount > 0) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "该出库单已完成复核，请勿重复操作");
        }

        WasteOutReview review = new WasteOutReview();
        BeanUtils.copyProperties(dto, review);
        review.setReviewNo(dto.getReviewNo());
        review.setOutNo(outRecord.getOutNo());
        review.setWasteId(outRecord.getWasteId());
        review.setWasteCode(outRecord.getWasteCode());
        review.setWasteName(outRecord.getWasteName());
        review.setWeight(outRecord.getWeight());
        review.setContainerCode(outRecord.getContainerCode());
        review.setOperatorId(outRecord.getOperatorId());
        review.setOperatorName(outRecord.getOperatorName());
        review.setReviewType(reviewType);
        review.setSyncStatus(0);
        review.setEnterpriseId(enterpriseId);
        review.setCreateTime(LocalDateTime.now());
        review.setUpdateTime(LocalDateTime.now());
        review.setDeleted(0);

        reviewMapper.insert(review);

        outRecord.setReviewStatus(1);
        outRecord.setUpdateTime(LocalDateTime.now());
        outRecordMapper.updateById(outRecord);

        result.put("needReview", true);
        result.put("reviewNo", review.getReviewNo());
        result.put("reviewQrCode", review.getReviewQrCode());
        result.put("reviewType", reviewType);
        result.put("message", "复核创建成功，请通知复核员扫码确认");

        log.info("创建出库复核记录: outNo={}, reviewNo={}, reviewType={}",
                outRecord.getOutNo(), review.getReviewNo(), reviewType);

        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> confirmReview(String reviewNo, WasteOutReviewDTO dto, Long enterpriseId) {
        Map<String, Object> result = new HashMap<>();

        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getReviewNo, reviewNo);
        WasteOutReview review = reviewMapper.selectOne(wrapper);
        if (review == null) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "复核记录不存在");
        }

        if (review.getReviewResult() != null) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "该复核已处理，请勿重复操作");
        }

        if (review.getOperatorId() != null && review.getOperatorId().equals(dto.getReviewerId())) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "操作员和复核员不能为同一人");
        }

        review.setReviewerId(dto.getReviewerId());
        review.setReviewerName(dto.getReviewerName());
        review.setReviewResult(dto.getReviewResult());
        review.setReviewTime(LocalDateTime.now());
        review.setReviewRemark(dto.getReviewRemark());
        review.setReviewerFaceAuthId(dto.getReviewerFaceAuthId());
        review.setReviewerFaceId(dto.getReviewerFaceId());
        review.setReviewerFaceImage(dto.getReviewerFaceImage());
        review.setUpdateTime(LocalDateTime.now());
        reviewMapper.updateById(review);

        WasteOutRecord outRecord = null;
        if (review.getOutRecordId() != null) {
            outRecord = outRecordMapper.selectById(review.getOutRecordId());
        }
        if (outRecord == null && StrUtil.isNotBlank(review.getOutNo())) {
            LambdaQueryWrapper<WasteOutRecord> outWrapper = new LambdaQueryWrapper<>();
            outWrapper.eq(WasteOutRecord::getOutNo, review.getOutNo());
            outWrapper.eq(WasteOutRecord::getEnterpriseId, enterpriseId);
            outWrapper.last("limit 1");
            outRecord = outRecordMapper.selectOne(outWrapper);
        }
        if (outRecord != null) {
            if (dto.getReviewResult() == 1) {
                outRecord.setReviewStatus(2);
                outRecord.setStatus(2);
            } else if (dto.getReviewResult() == 2) {
                outRecord.setReviewStatus(3);
            }
            outRecord.setReviewerId(dto.getReviewerId());
            outRecord.setReviewerName(dto.getReviewerName());
            outRecord.setReviewerFaceAuthId(dto.getReviewerFaceAuthId());
            outRecord.setReviewerFaceId(dto.getReviewerFaceId());
            outRecord.setReviewerFaceImage(dto.getReviewerFaceImage());
            outRecord.setReviewTime(review.getReviewTime());
            outRecord.setReviewRemark(dto.getReviewRemark());
            outRecord.setUpdateTime(LocalDateTime.now());
            outRecordMapper.updateById(outRecord);
        }

        result.put("success", true);
        result.put("reviewResult", dto.getReviewResult() == 1 ? "通过" : "拒绝");
        result.put("message", dto.getReviewResult() == 1 ? "复核通过，出库已完成" : "复核已拒绝");

        log.info("出库复核完成: reviewNo={}, result={}, reviewer={}",
                reviewNo, dto.getReviewResult() == 1 ? "通过" : "拒绝", dto.getReviewerName());

        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        reviewMapper.deleteById(id);
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getOfflineId, offlineId);
        wrapper.eq(WasteOutReview::getEnterpriseId, enterpriseId);
        Long count = reviewMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    public List<WasteOutReview> getPendingSyncList(Long enterpriseId) {
        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getEnterpriseId, enterpriseId);
        wrapper.ne(WasteOutReview::getSyncStatus, 2);
        wrapper.orderByAsc(WasteOutReview::getCreateTime);
        return reviewMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<WasteOutReviewDTO> list, Long enterpriseId) {
        if (list == null || list.isEmpty()) {
            return;
        }

        LocalDateTime now = LocalDateTime.now();
        for (WasteOutReviewDTO dto : list) {
            try {
                if (dto.getOfflineId() != null && checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
                    continue;
                }

                WasteOutReview review = new WasteOutReview();
                BeanUtils.copyProperties(dto, review);
                review.setEnterpriseId(enterpriseId);
                review.setSyncStatus(2);
                review.setSyncTime(now);
                review.setCreateTime(now);
                review.setUpdateTime(now);
                review.setDeleted(0);
                reviewMapper.insert(review);
            } catch (Exception e) {
                log.warn("同步出库复核记录失败: offlineId={}, error={}", dto.getOfflineId(), e.getMessage());
            }
        }
    }
}
