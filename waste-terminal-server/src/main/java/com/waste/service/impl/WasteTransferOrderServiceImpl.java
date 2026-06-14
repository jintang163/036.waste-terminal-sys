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
import com.waste.entity.WasteTransferOrder;
import com.waste.mapper.EnterpriseInfoMapper;
import com.waste.mapper.WasteTransferOrderMapper;
import com.waste.service.NationalPlatformService;
import com.waste.service.WasteTransferOrderService;
import com.waste.mq.WasteMqProducer;
import com.waste.utils.IdGeneratorUtils;
import com.waste.utils.JsonUtils;
import com.waste.utils.QrCodeUtils;
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
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() != 1) {
            throw new BusinessException("联单状态不正确，无法签收，需为待上报状态");
        }
        if (StrUtil.isNotBlank(signPhoto)) {
            order.setSignPhoto(signPhoto);
        }
        order.setActualArriveTime(LocalDateTime.now());
        wasteTransferOrderMapper.updateById(order);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void complete(Long id, String receiptPhoto) {
        WasteTransferOrder order = getOrderById(id);
        if (order.getStatus() == 2) {
            throw new BusinessException("联单已完成，请勿重复操作");
        }
        if (order.getStatus() == -1) {
            throw new BusinessException("联单已取消，无法完成");
        }
        if (StrUtil.isBlank(order.getSignPhoto())) {
            throw new BusinessException("联单尚未签收，请先签收");
        }
        if (StrUtil.isNotBlank(receiptPhoto)) {
            order.setReceiptPhoto(receiptPhoto);
        }
        order.setStatus(2);
        wasteTransferOrderMapper.updateById(order);
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
        if (status == null) {
            return "未知";
        }
        switch (status) {
            case 0:
                return "待提交";
            case 1:
                return "待上报";
            case 2:
                return "已完成";
            case -1:
                return "已取消";
            default:
                return "未知";
        }
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
}
