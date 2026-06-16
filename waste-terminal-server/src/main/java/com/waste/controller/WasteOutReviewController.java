package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.WasteOutReviewDTO;
import com.waste.entity.WasteOutReview;
import com.waste.mapper.WasteOutReviewMapper;
import com.waste.service.WasteOutReviewService;
import com.waste.utils.UserContext;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/waste-out-review")
public class WasteOutReviewController {

    @Autowired
    private WasteOutReviewService reviewService;

    @Autowired
    private WasteOutReviewMapper reviewMapper;

    @PostMapping("/create")
    @RequiresLogin
    public Result<Map<String, Object>> createReview(@RequestBody @Validated WasteOutReviewDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && reviewService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            return Result.fail("offline_id已存在: " + dto.getOfflineId());
        }
        Map<String, Object> result = reviewService.createReview(dto, enterpriseId);
        return Result.success(result);
    }

    @PostMapping("/confirm/{reviewNo}")
    @RequiresLogin
    public Result<Map<String, Object>> confirmReview(
            @PathVariable String reviewNo,
            @RequestBody @Validated WasteOutReviewDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Map<String, Object> result = reviewService.confirmReview(reviewNo, dto, enterpriseId);
        return Result.success(result);
    }

    @GetMapping("/get-by-review-no/{reviewNo}")
    @RequiresLogin
    public Result<WasteOutReview> getByReviewNo(@PathVariable String reviewNo) {
        return Result.success(reviewService.getByReviewNo(reviewNo));
    }

    @GetMapping("/get-by-out-no/{outNo}")
    @RequiresLogin
    public Result<WasteOutReview> getByOutNo(@PathVariable String outNo) {
        return Result.success(reviewService.getByOutNo(outNo));
    }

    @GetMapping("/list")
    @RequiresLogin
    public Result<List<WasteOutReview>> list(WasteOutReview review,
                                              @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LambdaQueryWrapper<WasteOutReview> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteOutReview::getEnterpriseId, enterpriseId);
        if (review.getOutNo() != null && !review.getOutNo().isEmpty()) {
            wrapper.eq(WasteOutReview::getOutNo, review.getOutNo());
        }
        if (review.getReviewResult() != null) {
            wrapper.eq(WasteOutReview::getReviewResult, review.getReviewResult());
        }
        wrapper.orderByDesc(WasteOutReview::getCreateTime);
        List<WasteOutReview> list = reviewMapper.selectList(wrapper);
        return Result.success(list);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<WasteOutReview>> page(PageQuery pageQuery, WasteOutReview review,
                                                    @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteOutReview> page = reviewService.page(pageQuery, review, enterpriseId);
        return Result.success(PageResult.of(page));
    }

    @DeleteMapping("/{id}")
    @RequiresLogin
    public Result<Void> delete(@PathVariable Long id) {
        reviewService.delete(id);
        return Result.success();
    }

    @PostMapping("/batch-sync")
    @RequiresLogin
    public Result<Void> batchSync(@RequestBody List<WasteOutReviewDTO> list) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        reviewService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @GetMapping("/pending-sync")
    @RequiresLogin
    public Result<List<WasteOutReview>> getPendingSyncList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        return Result.success(reviewService.getPendingSyncList(enterpriseId));
    }
}
