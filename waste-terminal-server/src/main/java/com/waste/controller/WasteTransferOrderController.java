package com.waste.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.annotation.RequiresLogin;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.dto.TransferOrderDTO;
import com.waste.entity.TransferOrderTimeline;
import com.waste.entity.WasteTransferOrder;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.mq.WasteMqProducer;
import com.waste.service.WasteTransferOrderService;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.UserContext;
import com.waste.vo.TransferOrderVO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/transfer-order")
public class WasteTransferOrderController {

    @Autowired
    private WasteTransferOrderService wasteTransferOrderService;

    @Autowired
    private WasteTransferOrderMapper wasteTransferOrderMapper;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    @PostMapping("/create")
    @RequiresLogin
    public Result<WasteTransferOrder> create(@RequestBody @Validated TransferOrderDTO dto) {
        Long enterpriseId = UserContext.getCurrentEnterpriseId();
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        if (dto.getOfflineId() != null && wasteTransferOrderService.checkByOfflineId(dto.getOfflineId(), enterpriseId)) {
            return Result.fail("offline_id已存在: " + dto.getOfflineId());
        }
        if (dto.getOrderNo() == null || dto.getOrderNo().isEmpty()) {
            dto.setOrderNo(IdGeneratorUtils.generateTransferOrderNo());
        }
        dto.setOperatorId(UserContext.getCurrentUserId());
        dto.setOperatorName(UserContext.getCurrentRealName());
        wasteTransferOrderService.create(dto, enterpriseId);

        WasteTransferOrder order = wasteTransferOrderService.getByOrderNo(dto.getOrderNo());
        if (order != null) {
            wasteMqProducer.sendTransferOrderSync(order);
        }
        return Result.success(order);
    }

    @PostMapping("/sign")
    @RequiresLogin
    public Result<Void> sign(@RequestParam Long id,
                              @RequestParam(required = false) String signPhoto) {
        wasteTransferOrderService.sign(id, signPhoto);
        return Result.success();
    }

    @PostMapping("/complete")
    @RequiresLogin
    public Result<Void> complete(@RequestParam Long id,
                                  @RequestParam(required = false) String receiptPhoto) {
        wasteTransferOrderService.complete(id, receiptPhoto);
        return Result.success();
    }

    @PostMapping("/cancel")
    @RequiresLogin
    public Result<Void> cancel(@RequestParam Long id) {
        wasteTransferOrderService.cancel(id);
        return Result.success();
    }

    @GetMapping("/list")
    @RequiresLogin
    public Result<List<WasteTransferOrder>> list(WasteTransferOrder transferOrder,
                                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteTransferOrder::getEnterpriseId, enterpriseId);
        if (transferOrder.getOrderNo() != null && !transferOrder.getOrderNo().isEmpty()) {
            wrapper.eq(WasteTransferOrder::getOrderNo, transferOrder.getOrderNo());
        }
        if (transferOrder.getStatus() != null) {
            wrapper.eq(WasteTransferOrder::getStatus, transferOrder.getStatus());
        }
        if (transferOrder.getOfflineId() != null && !transferOrder.getOfflineId().isEmpty()) {
            wrapper.eq(WasteTransferOrder::getOfflineId, transferOrder.getOfflineId());
        }
        if (transferOrder.getGeneratorUnitId() != null) {
            wrapper.eq(WasteTransferOrder::getGeneratorUnitId, transferOrder.getGeneratorUnitId());
        }
        if (transferOrder.getReceiverUnitId() != null) {
            wrapper.eq(WasteTransferOrder::getReceiverUnitId, transferOrder.getReceiverUnitId());
        }
        wrapper.orderByDesc(WasteTransferOrder::getCreateTime);
        List<WasteTransferOrder> list = wasteTransferOrderMapper.selectList(wrapper);
        return Result.success(list);
    }

    @GetMapping("/page")
    @RequiresLogin
    public Result<PageResult<WasteTransferOrder>> page(PageQuery pageQuery, WasteTransferOrder transferOrder,
                                                        @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = UserContext.getCurrentEnterpriseId();
        }
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteTransferOrder> page = wasteTransferOrderService.page(pageQuery, transferOrder, enterpriseId);
        PageResult<WasteTransferOrder> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/detail/{id}")
    @RequiresLogin
    public Result<TransferOrderVO> detail(@PathVariable Long id) {
        TransferOrderVO vo = wasteTransferOrderService.getDetailById(id);
        return Result.success(vo);
    }

    @GetMapping("/page-legacy")
    public Result<PageResult<WasteTransferOrder>> pageLegacy(PageQuery pageQuery, WasteTransferOrder transferOrder,
                                                        @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<WasteTransferOrder> page = wasteTransferOrderService.page(pageQuery, transferOrder, enterpriseId);
        PageResult<WasteTransferOrder> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<TransferOrderVO> getById(@PathVariable Long id) {
        TransferOrderVO vo = wasteTransferOrderService.getDetailById(id);
        return Result.success(vo);
    }

    @GetMapping("/no/{orderNo}")
    public Result<WasteTransferOrder> getByOrderNo(@PathVariable String orderNo) {
        WasteTransferOrder order = wasteTransferOrderService.getByOrderNo(orderNo);
        return Result.success(order);
    }

    @PostMapping("/legacy")
    public Result<Void> createLegacy(@RequestBody TransferOrderDTO dto,
                               @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteTransferOrderService.create(dto, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody TransferOrderDTO dto) {
        wasteTransferOrderService.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        wasteTransferOrderService.delete(id);
        return Result.success();
    }

    @PostMapping("/batch")
    public Result<Void> batchSync(@RequestBody List<TransferOrderDTO> list,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        wasteTransferOrderService.batchSync(list, enterpriseId);
        return Result.success();
    }

    @PutMapping("/submit/{id}")
    public Result<Void> submit(@PathVariable Long id) {
        wasteTransferOrderService.submit(id);
        return Result.success();
    }

    @PutMapping("/confirm/{id}")
    public Result<Void> confirm(@PathVariable Long id) {
        wasteTransferOrderService.confirm(id);
        return Result.success();
    }

    @PutMapping("/report/{id}")
    public Result<Void> report(@PathVariable Long id) {
        wasteTransferOrderService.report(id);
        return Result.success();
    }

    @PutMapping("/sign-legacy/{id}")
    public Result<Void> signLegacy(@PathVariable Long id,
                             @RequestParam(required = false) String signPhoto) {
        wasteTransferOrderService.sign(id, signPhoto);
        return Result.success();
    }

    @PutMapping("/complete-legacy/{id}")
    public Result<Void> completeLegacy(@PathVariable Long id,
                                 @RequestParam(required = false) String receiptPhoto) {
        wasteTransferOrderService.complete(id, receiptPhoto);
        return Result.success();
    }

    @PutMapping("/cancel-legacy/{id}")
    public Result<Void> cancelLegacy(@PathVariable Long id) {
        wasteTransferOrderService.cancel(id);
        return Result.success();
    }

    @GetMapping("/qrcode/{id}")
    public Result<String> getQrCode(@PathVariable Long id) {
        String qrCode = wasteTransferOrderService.getQrCode(id);
        return Result.success(qrCode);
    }

    @GetMapping("/pending-report")
    public Result<List<WasteTransferOrder>> getPendingReportList(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<WasteTransferOrder> list = wasteTransferOrderService.getPendingReportList(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/check/{offlineId}")
    public Result<Boolean> checkByOfflineId(@PathVariable String offlineId,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        boolean exist = wasteTransferOrderService.checkByOfflineId(offlineId, enterpriseId);
        return Result.success(exist);
    }

    @PutMapping("/start-transport/{id}")
    @RequiresLogin
    public Result<Void> startTransport(@PathVariable Long id) {
        wasteTransferOrderService.startTransport(id,
                UserContext.getCurrentRealName(),
                UserContext.getCurrentUserId());
        return Result.success();
    }

    @PutMapping("/arrive/{id}")
    @RequiresLogin
    public Result<Void> arrive(@PathVariable Long id,
                               @RequestParam(required = false) String location) {
        wasteTransferOrderService.arrive(id,
                UserContext.getCurrentRealName(),
                UserContext.getCurrentUserId(),
                location);
        return Result.success();
    }

    @PutMapping("/sign-order/{id}")
    @RequiresLogin
    public Result<Void> signOrder(@PathVariable Long id,
                                  @RequestParam(required = false) String signPhoto) {
        wasteTransferOrderService.signOrder(id,
                UserContext.getCurrentRealName(),
                UserContext.getCurrentUserId(),
                signPhoto);
        return Result.success();
    }

    @PutMapping("/complete-order/{id}")
    @RequiresLogin
    public Result<Void> completeOrder(@PathVariable Long id,
                                      @RequestParam(required = false) String receiptPhoto) {
        wasteTransferOrderService.completeOrder(id,
                UserContext.getCurrentRealName(),
                UserContext.getCurrentUserId(),
                receiptPhoto);
        return Result.success();
    }

    @PutMapping("/cancel-order/{id}")
    @RequiresLogin
    public Result<Void> cancelOrder(@PathVariable Long id,
                                    @RequestParam(required = false) String reason) {
        wasteTransferOrderService.cancelOrder(id,
                UserContext.getCurrentRealName(),
                UserContext.getCurrentUserId(),
                reason);
        return Result.success();
    }

    @GetMapping("/timeline/{id}")
    @RequiresLogin
    public Result<List<TransferOrderTimeline>> getTimeline(@PathVariable Long id) {
        List<TransferOrderTimeline> timeline = wasteTransferOrderService.getTimeline(id);
        return Result.success(timeline);
    }

    @GetMapping("/detail-full/{id}")
    @RequiresLogin
    public Result<TransferOrderVO> getDetailFull(@PathVariable Long id) {
        TransferOrderVO vo = wasteTransferOrderService.getDetailWithTimeline(id);
        return Result.success(vo);
    }

    @PostMapping("/sync-status/{id}")
    @RequiresLogin
    public Result<Boolean> syncStatus(@PathVariable Long id) {
        boolean success = wasteTransferOrderService.syncStatusFromRemote(id);
        return Result.success(success);
    }
}
