package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.TransferOrderDTO;
import com.waste.entity.EnterpriseInfo;
import com.waste.entity.TransferOrderTimeline;
import com.waste.entity.WasteTransferOrder;
import com.waste.enums.TransferOrderEventTypeEnum;
import com.waste.enums.TransferOrderStatusEnum;
import com.waste.mapper.EnterpriseInfoMapper;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.mq.WasteMqProducer;
import com.waste.service.NationalPlatformService;
import com.waste.service.TransferOrderTimelineService;
import com.waste.service.WasteTransferOrderService;
import com.waste.statemachine.TransferOrderStateMachine;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.JsonUtils;
import com.waste.utils.QrCodeUtils;
import com.waste.utils.UserContext;
import com.waste.vo.TransferOrderVO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
public class WasteTransferOrderServiceImpl implements WasteTransferOrderService {

    @Autowired
    private WasteTransferOrderMapper wasteTransferOrderMapper;

    @Autowired
    private EnterpriseInfoMapper enterpriseInfoMapper;

    @Autowired
    private NationalPlatformService nationalPlatformService;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    @Autowired
    private TransferOrderStateMachine stateMachine;

    @Autowired
    private TransferOrderTimelineService timelineService;

    @Override
    public IPage<WasteTransferOrder> page(PageQuery pageQuery, WasteTransferOrder transferOrder, Long enterpriseId) {
        Page<WasteTransferOrder> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<WasteTransferOrder> wrapper = buildQueryWrapper(transferOrder, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(WasteTransferOrder::getCreateTime);
        }
        return wasteTransferOrderMapper.selectPage(page, wrapper);
    }

    @Override
    public TransferOrderVO getDetailById(Long id) {
        WasteTransferOrder order = wasteTransferOrderMapper.selectById(id);
        if (order == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return convertToVO(order);
    }

    @Override
    public WasteTransferOrder getByOrderNo(String orderNo) {
        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteTransferOrder::getOrderNo, orderNo);
        return wasteTransferOrderMapper.selectOne(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(TransferOrderDTO dto, Long enterpriseId) {
        if (StrUtil.isNotBlank(dto.getOfflineId())) {
            boolean exist = checkByOfflineId(dto.getOfflineId(), enterpriseId);
            if (exist) {
                throw new BusinessException(ResultCode.OFFLINE_ID_EXIST);
            }
        }

        EnterpriseInfo generatorUnit = enterpriseInfoMapper.selectById(dto.getGeneratorUnitId());
        if (generatorUnit == null) {
            throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND, "产生单位不存在");
        }

        EnterpriseInfo receiverUnit = enterpriseInfoMapper.selectById(dto.getReceiverUnitId());
        if (receiverUnit == null) {
            throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND, "接收单位不存在");
        }

        String orderNo = IdGeneratorUtils.generateTransferOrderNo();
        String qrCodeContent = buildQrCodeContent(orderNo);
        String qrCodeBase64 = QrCodeUtils.generateQrCodeBase64(qrCodeContent);

        WasteTransferOrder order = new WasteTransferOrder();
        BeanUtils.copyProperties(dto, order);
        order.setOrderNo(orderNo);
        order.setGeneratorUnitName(generatorUnit.getEnterpriseName());
        order.setGeneratorUnitCode(generatorUnit.getEnterpriseCode());
        order.setReceiverUnitName(receiverUnit.getEnterpriseName());
        order.setReceiverUnitCode(receiverUnit.getEnterpriseCode());
        order.setReceiverLicenseNo(receiverUnit.getWasteLicense());

        if (dto.getTransporterId() != null) {
            EnterpriseInfo transporter = enterpriseInfoMapper.selectById(dto.getTransporterId());
            if (transporter != null) {
                order.setTransporterName(transporter.getEnterpriseName());
                order.setTransporterLicenseNo(transporter.getWasteLicense());
            }
        }

        if (CollUtil.isNotEmpty(dto.getWasteDetails())) {
            order.setWasteDetails(JsonUtils.toJson(dto.getWasteDetails()));
            BigDecimal totalWeight = dto.getWasteDetails().stream()
                    .map(TransferOrderDTO.WasteItemDTO::getWeight)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            order.setTotalWeight(totalWeight);
            order.setTotalContainers((int) dto.getWasteDetails().stream()
                    .map(TransferOrderDTO.WasteItemDTO::getContainerId)
                    .distinct().count());
        }

        order.setStatus(0);
        order.setReportStatus(0);
        order.setSyncStatus(1);
        order.setQrCode(qrCodeBase64);
        if (enterpriseId != null) {
            order.setEnterpriseId(enterpriseId);
        }

        wasteTransferOrderMapper.insert(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, TransferOrderDTO dto) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() >= 1) {
            throw new BusinessException("联单已提交或已完成，无法修改");
        }

        if (dto.getGeneratorUnitId() != null && !dto.getGeneratorUnitId().equals(order.getGeneratorUnitId())) {
            EnterpriseInfo generatorUnit = enterpriseInfoMapper.selectById(dto.getGeneratorUnitId());
            if (generatorUnit == null) {
                throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND, "产生单位不存在");
            }
            order.setGeneratorUnitId(dto.getGeneratorUnitId());
            order.setGeneratorUnitName(generatorUnit.getEnterpriseName());
            order.setGeneratorUnitCode(generatorUnit.getEnterpriseCode());
        }

        if (dto.getReceiverUnitId() != null && !dto.getReceiverUnitId().equals(order.getReceiverUnitId())) {
            EnterpriseInfo receiverUnit = enterpriseInfoMapper.selectById(dto.getReceiverUnitId());
            if (receiverUnit == null) {
                throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND, "接收单位不存在");
            }
            order.setReceiverUnitId(dto.getReceiverUnitId());
            order.setReceiverUnitName(receiverUnit.getEnterpriseName());
            order.setReceiverUnitCode(receiverUnit.getEnterpriseCode());
            order.setReceiverLicenseNo(receiverUnit.getWasteLicense());
        }

        if (dto.getTransporterId() != null) {
            EnterpriseInfo transporter = enterpriseInfoMapper.selectById(dto.getTransporterId());
            if (transporter != null) {
                order.setTransporterId(dto.getTransporterId());
                order.setTransporterName(transporter.getEnterpriseName());
                order.setTransporterLicenseNo(transporter.getWasteLicense());
            }
        }

        if (dto.getOrderType() != null) {
            order.setOrderType(dto.getOrderType());
        }
        if (dto.getVehicleNo() != null) {
            order.setVehicleNo(dto.getVehicleNo());
        }
        if (dto.getDriverName() != null) {
            order.setDriverName(dto.getDriverName());
        }
        if (dto.getDriverLicense() != null) {
            order.setDriverLicense(dto.getDriverLicense());
        }
        if (dto.getEscortName() != null) {
            order.setEscortName(dto.getEscortName());
        }
        if (dto.getStartTime() != null) {
            order.setStartTime(dto.getStartTime());
        }
        if (dto.getEstimateArriveTime() != null) {
            order.setEstimateArriveTime(dto.getEstimateArriveTime());
        }
        if (dto.getRoute() != null) {
            order.setRoute(dto.getRoute());
        }
        if (dto.getEmergencyContact() != null) {
            order.setEmergencyContact(dto.getEmergencyContact());
        }
        if (dto.getEmergencyPhone() != null) {
            order.setEmergencyPhone(dto.getEmergencyPhone());
        }
        if (dto.getOperatorId() != null) {
            order.setOperatorId(dto.getOperatorId());
        }
        if (dto.getOperatorName() != null) {
            order.setOperatorName(dto.getOperatorName());
        }
        if (dto.getRemark() != null) {
            order.setRemark(dto.getRemark());
        }

        if (CollUtil.isNotEmpty(dto.getWasteDetails())) {
            order.setWasteDetails(JsonUtils.toJson(dto.getWasteDetails()));
            BigDecimal totalWeight = dto.getWasteDetails().stream()
                    .map(TransferOrderDTO.WasteItemDTO::getWeight)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            order.setTotalWeight(totalWeight);
            order.setTotalContainers((int) dto.getWasteDetails().stream()
                    .map(TransferOrderDTO.WasteItemDTO::getContainerId)
                    .distinct().count());
        }

        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() >= 1) {
            throw new BusinessException("联单已提交或已完成，无法删除");
        }
        wasteTransferOrderMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void confirm(Long id) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() != 1) {
            throw new BusinessException("联单状态不正确，无法确认运输");
        }
        order.setStatus(2);
        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<TransferOrderDTO> list, Long enterpriseId) {
        if (CollUtil.isEmpty(list)) {
            throw new BusinessException(ResultCode.SYNC_DATA_EMPTY);
        }

        List<String> offlineIds = new ArrayList<>();
        for (TransferOrderDTO dto : list) {
            if (StrUtil.isBlank(dto.getOfflineId())) {
                throw new BusinessException(ResultCode.SYNC_DATA_ERROR, "离线数据ID不能为空");
            }
            offlineIds.add(dto.getOfflineId());
        }

        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(WasteTransferOrder::getOfflineId, offlineIds);
        if (enterpriseId != null) {
            wrapper.eq(WasteTransferOrder::getEnterpriseId, enterpriseId);
        }
        List<WasteTransferOrder> existOrders = wasteTransferOrderMapper.selectList(wrapper);
        List<String> existOfflineIds = existOrders.stream()
                .map(WasteTransferOrder::getOfflineId)
                .collect(Collectors.toList());

        for (TransferOrderDTO dto : list) {
            if (existOfflineIds.contains(dto.getOfflineId())) {
                continue;
            }
            try {
                create(dto, enterpriseId);
            } catch (Exception e) {
                WasteTransferOrder failOrder = new WasteTransferOrder();
                BeanUtils.copyProperties(dto, failOrder);
                failOrder.setOrderNo(IdGeneratorUtils.generateTransferOrderNo());
                failOrder.setSyncStatus(2);
                failOrder.setSyncFailReason(e.getMessage());
                if (enterpriseId != null) {
                    failOrder.setEnterpriseId(enterpriseId);
                }
                wasteTransferOrderMapper.insert(failOrder);
            }
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void submit(Long id) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() != 0) {
            throw new BusinessException("联单状态不正确，无法提交");
        }
        order.setStatus(1);
        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void report(Long id) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() != 1) {
            throw new BusinessException("联单未提交，无法上报");
        }
        if (order.getReportStatus() != null && order.getReportStatus() == 1) {
            throw new BusinessException("联单已上报，请勿重复操作");
        }

        order.setReportStatus(2);
        order.setReportTime(LocalDateTime.now());
        wasteTransferOrderMapper.updateById(order);

        boolean reportSuccess = nationalPlatformService.reportTransferOrder(order);
        if (reportSuccess) {
            String nationalOrderNo = "GJ" + IdGeneratorUtils.nextIdStr();
            order.setNationalOrderNo(nationalOrderNo);
            order.setReportStatus(1);
            order.setReportTime(LocalDateTime.now());
            wasteTransferOrderMapper.updateById(order);
            log.info("联单上报国家平台成功, orderNo={}, nationalOrderNo={}", order.getOrderNo(), nationalOrderNo);
        } else {
            order.setReportStatus(3);
            wasteTransferOrderMapper.updateById(order);
            throw new BusinessException(ResultCode.NATIONAL_PLATFORM_REPORT_FAIL);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void sign(Long id, String signPhoto) {
        signOrder(id, UserContext.getCurrentRealName(), UserContext.getCurrentUserId(), signPhoto);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void complete(Long id, String receiptPhoto) {
        completeOrder(id, UserContext.getCurrentRealName(), UserContext.getCurrentUserId(), receiptPhoto);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long id) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() == -1) {
            throw new BusinessException("联单已取消，请勿重复操作");
        }
        if (order.getStatus() == 2) {
            throw new BusinessException("联单已完成，无法取消");
        }
        order.setStatus(-1);
        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    public String getQrCode(Long id) {
        WasteTransferOrder order = getOrderById(id);
        if (StrUtil.isNotBlank(order.getQrCode())) {
            return order.getQrCode();
        }
        String qrCodeContent = buildQrCodeContent(order.getOrderNo());
        String qrCodeBase64 = QrCodeUtils.generateQrCodeBase64(qrCodeContent);
        order.setQrCode(qrCodeBase64);
        wasteTransferOrderMapper.updateById(order);
        return qrCodeBase64;
    }

    @Override
    public List<WasteTransferOrder> getPendingReportList(Long enterpriseId) {
        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteTransferOrder::getStatus, 1);
        wrapper.ne(WasteTransferOrder::getReportStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteTransferOrder::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(WasteTransferOrder::getCreateTime);
        return wasteTransferOrderMapper.selectList(wrapper);
    }

    @Override
    public List<WasteTransferOrder> getPendingSyncList(Long enterpriseId) {
        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.ne(WasteTransferOrder::getSyncStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(WasteTransferOrder::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(WasteTransferOrder::getCreateTime);
        return wasteTransferOrderMapper.selectList(wrapper);
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<WasteTransferOrder> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteTransferOrder::getOfflineId, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(WasteTransferOrder::getEnterpriseId, enterpriseId);
        }
        Long count = wasteTransferOrderMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public WasteTransferOrder createTransferOrder(TransferOrderDTO dto) {
        if (StrUtil.isNotBlank(dto.getOfflineId())) {
            boolean exist = checkByOfflineId(dto.getOfflineId(), dto.getEnterpriseId());
            if (exist) {
                throw new BusinessException(ResultCode.OFFLINE_ID_EXIST);
            }
        }

        EnterpriseInfo generatorUnit = enterpriseInfoMapper.selectById(dto.getGeneratorUnitId());
        if (generatorUnit == null) {
            throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND, "产生单位不存在");
        }

        EnterpriseInfo receiverUnit = enterpriseInfoMapper.selectById(dto.getReceiverUnitId());
        if (receiverUnit == null) {
            throw new BusinessException(ResultCode.ENTERPRISE_NOT_FOUND, "接收单位不存在");
        }

        String orderNo = IdGeneratorUtils.generateTransferOrderNo();
        String qrCodeContent = buildQrCodeContent(orderNo);
        String qrCodeBase64 = QrCodeUtils.generateQrCodeBase64(qrCodeContent);

        WasteTransferOrder order = new WasteTransferOrder();
        BeanUtils.copyProperties(dto, order);
        order.setOrderNo(orderNo);
        order.setGeneratorUnitName(generatorUnit.getEnterpriseName());
        order.setGeneratorUnitCode(generatorUnit.getEnterpriseCode());
        order.setReceiverUnitName(receiverUnit.getEnterpriseName());
        order.setReceiverUnitCode(receiverUnit.getEnterpriseCode());
        order.setReceiverLicenseNo(receiverUnit.getWasteLicense());

        if (dto.getTransporterId() != null) {
            EnterpriseInfo transporter = enterpriseInfoMapper.selectById(dto.getTransporterId());
            if (transporter != null) {
                order.setTransporterName(transporter.getEnterpriseName());
                order.setTransporterLicenseNo(transporter.getWasteLicense());
            }
        }

        if (CollUtil.isNotEmpty(dto.getWasteDetails())) {
            order.setWasteDetails(JsonUtils.toJson(dto.getWasteDetails()));
            BigDecimal totalWeight = dto.getWasteDetails().stream()
                    .map(TransferOrderDTO.WasteItemDTO::getWeight)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            order.setTotalWeight(totalWeight);
            order.setTotalContainers((int) dto.getWasteDetails().stream()
                    .map(TransferOrderDTO.WasteItemDTO::getContainerId)
                    .distinct().count());
        }

        order.setStatus(1);
        order.setReportStatus(0);
        order.setSyncStatus(1);
        order.setQrCode(qrCodeBase64);
        if (dto.getEnterpriseId() != null) {
            order.setEnterpriseId(dto.getEnterpriseId());
        }

        wasteTransferOrderMapper.insert(order);

        wasteMqProducer.sendTransferOrderReport(order);

        return order;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void signTransferOrder(Long orderId, String signPhoto) {
        WasteTransferOrder order = getOrderById(orderId);
        if (order.getStatus() != 1) {
            throw new BusinessException("联单状态不正确，无法签收");
        }
        order.setSignStatus(1);
        order.setSignTime(LocalDateTime.now());
        if (StrUtil.isNotBlank(signPhoto)) {
            order.setSignPhoto(signPhoto);
        }
        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void completeTransferOrder(Long orderId, String receiptPhoto) {
        WasteTransferOrder order = getOrderById(orderId);
        if (order.getStatus() == 2) {
            throw new BusinessException("联单已完成，请勿重复操作");
        }
        if (order.getStatus() == -1) {
            throw new BusinessException("联单已取消，无法完成");
        }
        if (StrUtil.isNotBlank(receiptPhoto)) {
            order.setReceiptPhoto(receiptPhoto);
        }
        order.setStatus(2);
        order.setCompleteTime(LocalDateTime.now());
        wasteTransferOrderMapper.updateById(order);

        wasteMqProducer.sendTransferOrderReport(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancelTransferOrder(Long orderId, String reason) {
        WasteTransferOrder order = getOrderById(orderId);
        if (order.getStatus() == -1) {
            throw new BusinessException("联单已取消，请勿重复操作");
        }
        if (order.getStatus() == 2) {
            throw new BusinessException("联单已完成，无法取消");
        }
        order.setStatus(-1);
        if (StrUtil.isNotBlank(reason)) {
            order.setRemark(reason);
        }
        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    public List<WasteTransferOrder> queryList(WasteTransferOrder transferOrder, Long enterpriseId) {
        LambdaQueryWrapper<WasteTransferOrder> wrapper = buildQueryWrapper(transferOrder, enterpriseId);
        wrapper.orderByDesc(WasteTransferOrder::getCreateTime);
        return wasteTransferOrderMapper.selectList(wrapper);
    }

    @Override
    public IPage<WasteTransferOrder> queryPage(PageQuery pageQuery, WasteTransferOrder transferOrder, Long enterpriseId) {
        return page(pageQuery, transferOrder, enterpriseId);
    }

    private WasteTransferOrder getOrderById(Long id) {
        WasteTransferOrder order = wasteTransferOrderMapper.selectById(id);
        if (order == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return order;
    }

    private TransferOrderVO convertToVO(WasteTransferOrder order) {
        TransferOrderVO vo = new TransferOrderVO();
        BeanUtils.copyProperties(order, vo);

        if (order.getStatus() != null) {
            vo.setStatusName(getStatusName(order.getStatus()));
        }
        if (order.getReportStatus() != null) {
            vo.setReportStatusName(getReportStatusName(order.getReportStatus()));
        }
        if (StrUtil.isNotBlank(order.getOrderType())) {
            vo.setOrderTypeName(getOrderTypeName(order.getOrderType()));
        }

        if (StrUtil.isNotBlank(order.getWasteDetails())) {
            List<TransferOrderVO.WasteItemVO> wasteItems = JsonUtils.parseList(
                    order.getWasteDetails(), TransferOrderVO.WasteItemVO.class);
            vo.setWasteDetails(wasteItems);
        }

        return vo;
    }

    private String getStatusName(Integer status) {
        return TransferOrderStatusEnum.getNameByCode(status);
    }

    private String getReportStatusName(Integer reportStatus) {
        switch (reportStatus) {
            case 0:
                return "未上报";
            case 1:
                return "已上报";
            case 2:
                return "上报失败";
            default:
                return "未知";
        }
    }

    private String getOrderTypeName(String orderType) {
        if ("1".equals(orderType)) {
            return "转移联单";
        } else if ("2".equals(orderType)) {
            return "处置联单";
        }
        return "未知";
    }

    private String buildQrCodeContent(String orderNo) {
        return "waste-transfer:" + orderNo;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void startTransport(Long id, String operatorName, Long operatorId) {
        WasteTransferOrder order = getOrderById(id);
        stateMachine.transition(order, TransferOrderEventTypeEnum.START_TRANSPORT, operatorName, operatorId);
        wasteMqProducer.sendTransferOrderSync(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void arrive(Long id, String operatorName, Long operatorId, String location) {
        WasteTransferOrder order = getOrderById(id);
        stateMachine.transition(order, TransferOrderEventTypeEnum.ARRIVE, operatorName, operatorId);
        if (StrUtil.isNotBlank(location)) {
            timelineService.addTimeline(
                    order.getId(),
                    order.getOrderNo(),
                    order.getNationalOrderNo(),
                    null,
                    null,
                    null,
                    operatorName,
                    operatorId,
                    location,
                    "到达位置: " + location,
                    null,
                    order.getEnterpriseId()
            );
        }
        wasteMqProducer.sendTransferOrderSync(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void signOrder(Long id, String operatorName, Long operatorId, String signPhoto) {
        WasteTransferOrder order = getOrderById(id);
        if (StrUtil.isNotBlank(signPhoto)) {
            order.setSignPhoto(signPhoto);
            wasteTransferOrderMapper.updateById(order);
        }
        stateMachine.transition(order, TransferOrderEventTypeEnum.SIGN, operatorName, operatorId);
        wasteMqProducer.sendTransferOrderReport(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void completeOrder(Long id, String operatorName, Long operatorId, String receiptPhoto) {
        WasteTransferOrder order = getOrderById(id);
        if (StrUtil.isNotBlank(receiptPhoto)) {
            order.setReceiptPhoto(receiptPhoto);
            wasteTransferOrderMapper.updateById(order);
        }
        stateMachine.transition(order, TransferOrderEventTypeEnum.COMPLETE, operatorName, operatorId);
        wasteMqProducer.sendTransferOrderReport(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancelOrder(Long id, String operatorName, Long operatorId, String reason) {
        WasteTransferOrder order = getOrderById(id);
        if (StrUtil.isNotBlank(reason)) {
            order.setRemark(reason);
            wasteTransferOrderMapper.updateById(order);
        }
        stateMachine.transition(order, TransferOrderEventTypeEnum.CANCEL, operatorName, operatorId);
    }

    @Override
    public List<TransferOrderTimeline> getTimeline(Long id) {
        return timelineService.getTimelineByOrderId(id);
    }

    @Override
    public TransferOrderVO getDetailWithTimeline(Long id) {
        TransferOrderVO vo = getDetailById(id);
        List<TransferOrderTimeline> timelineList = timelineService.getTimelineByOrderId(id);
        vo.setTimelineList(timelineList);
        return vo;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public WasteTransferOrder createAndReportFromOutRecord(com.waste.entity.WasteOutRecord outRecord) {
        log.info("根据出库记录创建并上报联单, outRecordId={}, outNo={}", outRecord.getId(), outRecord.getOutNo());

        TransferOrderDTO dto = new TransferOrderDTO();
        dto.setGeneratorUnitId(outRecord.getEnterpriseId());
        dto.setReceiverUnitId(outRecord.getReceiverUnitId());
        dto.setReceiverUnitName(outRecord.getReceiverUnitName());
        dto.setTransporterId(outRecord.getTransporterId());
        dto.setTransporterName(outRecord.getTransporterName());
        dto.setVehicleNo(outRecord.getVehicleNo());
        dto.setDriverName(outRecord.getDriverName());
        dto.setDriverPhone(outRecord.getDriverPhone());
        dto.setTotalWeight(outRecord.getWeight());
        dto.setTotalContainers(1);
        dto.setOperatorId(outRecord.getOperatorId());
        dto.setOperatorName(outRecord.getOperatorName());
        dto.setRemark(outRecord.getRemark());
        dto.setEnterpriseId(outRecord.getEnterpriseId());
        dto.setOrderType("1");

        TransferOrderDTO.WasteItemDTO wasteItem = new TransferOrderDTO.WasteItemDTO();
        wasteItem.setWasteId(outRecord.getWasteId());
        wasteItem.setWasteCode(outRecord.getWasteCode());
        wasteItem.setWasteName(outRecord.getWasteName());
        wasteItem.setContainerId(outRecord.getContainerId());
        wasteItem.setContainerCode(outRecord.getContainerCode());
        wasteItem.setWeight(outRecord.getWeight());
        dto.setWasteDetails(java.util.Collections.singletonList(wasteItem));

        EnterpriseInfo generatorUnit = enterpriseInfoMapper.selectById(outRecord.getEnterpriseId());
        if (generatorUnit != null) {
            dto.setGeneratorUnitName(generatorUnit.getEnterpriseName());
            dto.setGeneratorUnitCode(generatorUnit.getEnterpriseCode());
        }

        EnterpriseInfo receiverUnit = null;
        if (outRecord.getReceiverUnitId() != null) {
            receiverUnit = enterpriseInfoMapper.selectById(outRecord.getReceiverUnitId());
        }
        if (receiverUnit != null) {
            dto.setReceiverUnitName(receiverUnit.getEnterpriseName());
            dto.setReceiverUnitCode(receiverUnit.getEnterpriseCode());
            dto.setReceiverLicenseNo(receiverUnit.getWasteLicense());
        }

        String orderNo = IdGeneratorUtils.generateTransferOrderNo();
        String qrCodeContent = buildQrCodeContent(orderNo);
        String qrCodeBase64 = QrCodeUtils.generateQrCodeBase64(qrCodeContent);

        WasteTransferOrder order = new WasteTransferOrder();
        org.springframework.beans.BeanUtils.copyProperties(dto, order);
        order.setOrderNo(orderNo);
        order.setQrCode(qrCodeBase64);
        order.setStatus(TransferOrderStatusEnum.PENDING_REPORT.getCode());
        order.setReportStatus(2);
        order.setSyncStatus(1);
        order.setReportTime(LocalDateTime.now());
        order.setStartTime(outRecord.getOutTime());

        if (CollUtil.isNotEmpty(dto.getWasteDetails())) {
            order.setWasteDetails(JsonUtils.toJson(dto.getWasteDetails()));
        }

        wasteTransferOrderMapper.insert(order);

        timelineService.addTimeline(
                order.getId(), order.getOrderNo(), null,
                null, TransferOrderStatusEnum.PENDING_REPORT.getCode(),
                TransferOrderStatusEnum.PENDING_REPORT.getName(),
                outRecord.getOperatorName(), outRecord.getOperatorId(),
                null, "出库确认，自动创建联单",
                null, outRecord.getEnterpriseId()
        );

        Map<String, Object> reportResult = nationalPlatformService.reportElectronicManifestWithResult(order);
        if (reportResult != null && Boolean.TRUE.equals(reportResult.get("success"))) {
            String nationalOrderNo = reportResult.get("nationalOrderNo") != null
                    ? reportResult.get("nationalOrderNo").toString()
                    : null;
            if (nationalOrderNo != null) {
                order.setNationalOrderNo(nationalOrderNo);
            }
            order.setReportStatus(1);
            order.setStatus(TransferOrderStatusEnum.PENDING_TRANSPORT.getCode());
            wasteTransferOrderMapper.updateById(order);

            timelineService.addTimeline(
                    order.getId(), order.getOrderNo(), order.getNationalOrderNo(),
                    TransferOrderStatusEnum.PENDING_REPORT.getCode(),
                    TransferOrderStatusEnum.PENDING_TRANSPORT.getCode(),
                    TransferOrderStatusEnum.PENDING_TRANSPORT.getName(),
                    "SYSTEM", null, null,
                    "上报国家平台成功，联单号: " + order.getNationalOrderNo(),
                    null, outRecord.getEnterpriseId()
            );
            log.info("联单上报成功, orderId={}, orderNo={}, nationalOrderNo={}",
                    order.getId(), order.getOrderNo(), order.getNationalOrderNo());
        } else {
            order.setReportStatus(3);
            String failReason = reportResult != null && reportResult.get("message") != null
                    ? reportResult.get("message").toString()
                    : "上报国家平台失败";
            wasteTransferOrderMapper.updateById(order);
            timelineService.addTimeline(
                    order.getId(), order.getOrderNo(), null,
                    null, null, null,
                    "SYSTEM", null, null,
                    "上报国家平台失败: " + failReason,
                    null, outRecord.getEnterpriseId()
            );
            log.warn("联单上报失败, orderId={}, orderNo={}, reason={}",
                    order.getId(), order.getOrderNo(), failReason);
        }

        try {
            wasteMqProducer.sendTransferOrderSync(order);
        } catch (Exception e) {
            log.error("发送联单同步MQ失败, orderId={}", order.getId(), e);
        }

        return order;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public boolean syncStatusFromRemote(Long orderId) {
        WasteTransferOrder order = getOrderById(orderId);
        if (StrUtil.isBlank(order.getNationalOrderNo()) && StrUtil.isBlank(order.getOrderNo())) {
            log.warn("联单无国家联单号和本地联单号，无法同步远程状态, orderId={}", orderId);
            return false;
        }

        Map<String, Object> statusResult = nationalPlatformService.queryTransferOrderStatus(
                order.getNationalOrderNo(), order.getOrderNo());

        if (statusResult == null || !Boolean.TRUE.equals(statusResult.get("success"))) {
            log.warn("查询远程联单状态失败, orderId={}", orderId);
            return false;
        }

        Integer localStatus = statusResult.get("localStatus") != null
                ? (Integer) statusResult.get("localStatus")
                : null;
        if (localStatus == null) {
            return false;
        }

        if (statusResult.get("nationalOrderNo") != null && StrUtil.isBlank(order.getNationalOrderNo())) {
            order.setNationalOrderNo(statusResult.get("nationalOrderNo").toString());
            wasteTransferOrderMapper.updateById(order);
        }

        TransferOrderStatusEnum currentStatus = TransferOrderStatusEnum.getByCode(order.getStatus());
        TransferOrderStatusEnum targetStatus = TransferOrderStatusEnum.getByCode(localStatus);

        if (currentStatus == null || targetStatus == null) {
            return false;
        }

        if (currentStatus == targetStatus) {
            return true;
        }

        if (!currentStatus.canTransitionTo(targetStatus)) {
            log.warn("联单状态流转不合法, orderId={}, current={}, target={}",
                    orderId, currentStatus.getCode(), targetStatus.getCode());
            return false;
        }

        TransferOrderEventTypeEnum eventType = resolveEventType(currentStatus, targetStatus);
        if (eventType != null) {
            stateMachine.transition(order, eventType, "SYNC", null);
            log.info("同步远程状态成功, orderId={}, {} -> {}",
                    orderId, currentStatus.getName(), targetStatus.getName());
            return true;
        }

        order.setStatus(targetStatus.getCode());
        wasteTransferOrderMapper.updateById(order);
        timelineService.addTimeline(
                order.getId(), order.getOrderNo(), order.getNationalOrderNo(),
                currentStatus.getCode(), targetStatus.getCode(),
                targetStatus.getName(), "SYNC", null, null,
                "同步远程状态变更: " + currentStatus.getName() + " → " + targetStatus.getName(),
                null, order.getEnterpriseId()
        );
        return true;
    }

    private TransferOrderEventTypeEnum resolveEventType(TransferOrderStatusEnum from, TransferOrderStatusEnum to) {
        if (from == TransferOrderStatusEnum.PENDING_REPORT && to == TransferOrderStatusEnum.PENDING_TRANSPORT) {
            return TransferOrderEventTypeEnum.REPORT_SUCCESS;
        }
        if (from == TransferOrderStatusEnum.PENDING_TRANSPORT && to == TransferOrderStatusEnum.IN_TRANSIT) {
            return TransferOrderEventTypeEnum.START_TRANSPORT;
        }
        if (from == TransferOrderStatusEnum.IN_TRANSIT && to == TransferOrderStatusEnum.ARRIVED) {
            return TransferOrderEventTypeEnum.ARRIVE;
        }
        if (from == TransferOrderStatusEnum.ARRIVED && to == TransferOrderStatusEnum.SIGNED) {
            return TransferOrderEventTypeEnum.SIGN;
        }
        if (from == TransferOrderStatusEnum.SIGNED && to == TransferOrderStatusEnum.COMPLETED) {
            return TransferOrderEventTypeEnum.COMPLETE;
        }
        if (to == TransferOrderStatusEnum.CANCELLED) {
            return TransferOrderEventTypeEnum.CANCEL;
        }
        return null;
    }
}
