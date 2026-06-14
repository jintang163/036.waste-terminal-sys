package com.waste.service.impl;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.waste.common.PageQuery;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.dto.InventoryCheckDTO;
import com.waste.entity.InventoryCheck;
import com.waste.entity.InventoryCheckDetail;
import com.waste.entity.WasteInventory;
import com.waste.mapper.InventoryCheckDetailMapper;
import com.waste.mapper.InventoryCheckMapper;
import com.waste.mapper.WasteInventoryMapper;
import com.waste.service.InventoryCheckService;
import com.waste.utils.IdGeneratorUtils;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class InventoryCheckServiceImpl implements InventoryCheckService {

    @Autowired
    private InventoryCheckMapper inventoryCheckMapper;

    @Autowired
    private InventoryCheckDetailMapper inventoryCheckDetailMapper;

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Override
    public IPage<InventoryCheck> page(PageQuery pageQuery, InventoryCheck inventoryCheck, Long enterpriseId) {
        Page<InventoryCheck> page = new Page<>(pageQuery.getPageNum(), pageQuery.getPageSize());
        LambdaQueryWrapper<InventoryCheck> wrapper = buildQueryWrapper(inventoryCheck, enterpriseId);
        if (pageQuery.getOrderBy() != null && pageQuery.getOrderDirection() != null) {
            if ("asc".equalsIgnoreCase(pageQuery.getOrderDirection())) {
                wrapper.orderByAsc(pageQuery.getOrderBy());
            } else {
                wrapper.orderByDesc(pageQuery.getOrderBy());
            }
        } else {
            wrapper.orderByDesc(InventoryCheck::getCreateTime);
        }
        return inventoryCheckMapper.selectPage(page, wrapper);
    }

    @Override
    public InventoryCheck getById(Long id) {
        InventoryCheck check = inventoryCheckMapper.selectById(id);
        if (check == null) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return check;
    }

    @Override
    public List<InventoryCheckDetail> getDetailsByCheckId(Long checkId) {
        LambdaQueryWrapper<InventoryCheckDetail> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(InventoryCheckDetail::getCheckId, checkId);
        wrapper.orderByAsc(InventoryCheckDetail::getContainerCode);
        return inventoryCheckDetailMapper.selectList(wrapper);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void createCheck(InventoryCheckDTO dto, Long enterpriseId) {
        if (StrUtil.isNotBlank(dto.getOfflineId())) {
            boolean exist = checkByOfflineId(dto.getOfflineId(), enterpriseId);
            if (exist) {
                throw new BusinessException(ResultCode.OFFLINE_ID_EXIST);
            }
        }

        InventoryCheck check = new InventoryCheck();
        BeanUtils.copyProperties(dto, check);
        check.setCheckNo(IdGeneratorUtils.generateCheckNo());
        check.setStatus(0);
        check.setAuditStatus(0);
        check.setSyncStatus(1);
        if (enterpriseId != null) {
            check.setEnterpriseId(enterpriseId);
        }

        if (check.getCheckDate() == null) {
            check.setCheckDate(java.time.LocalDate.now());
        }

        LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
        inventoryWrapper.eq(WasteInventory::getStatus, 1);
        if (enterpriseId != null) {
            inventoryWrapper.eq(WasteInventory::getEnterpriseId, enterpriseId);
        }
        Long totalCount = wasteInventoryMapper.selectCount(inventoryWrapper);
        check.setTotalContainers(totalCount != null ? totalCount.intValue() : 0);
        check.setCheckedContainers(0);
        check.setMissingContainers(0);
        check.setExtraContainers(0);
        check.setDiffWeight(BigDecimal.ZERO);

        inventoryCheckMapper.insert(check);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, InventoryCheckDTO dto) {
        InventoryCheck check = getById(id);
        if (check.getStatus() == 1) {
            throw new BusinessException("盘点已完成，无法修改");
        }
        if (check.getStatus() == 2) {
            throw new BusinessException("盘点已取消，无法修改");
        }

        if (dto.getCheckName() != null) {
            check.setCheckName(dto.getCheckName());
        }
        if (dto.getCheckType() != null) {
            check.setCheckType(dto.getCheckType());
        }
        if (dto.getCheckDate() != null) {
            check.setCheckDate(dto.getCheckDate());
        }
        if (dto.getOperatorId() != null) {
            check.setOperatorId(dto.getOperatorId());
        }
        if (dto.getOperatorName() != null) {
            check.setOperatorName(dto.getOperatorName());
        }
        if (dto.getRemark() != null) {
            check.setRemark(dto.getRemark());
        }

        inventoryCheckMapper.updateById(check);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        InventoryCheck check = getById(id);
        if (check.getStatus() == 1) {
            throw new BusinessException("盘点已完成，无法删除");
        }

        LambdaQueryWrapper<InventoryCheckDetail> detailWrapper = new LambdaQueryWrapper<>();
        detailWrapper.eq(InventoryCheckDetail::getCheckId, id);
        inventoryCheckDetailMapper.delete(detailWrapper);

        inventoryCheckMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long id) {
        InventoryCheck check = getById(id);
        if (check.getStatus() == 2) {
            throw new BusinessException("盘点已取消，请勿重复操作");
        }
        if (check.getStatus() == 1) {
            throw new BusinessException("盘点已完成，无法取消");
        }

        check.setStatus(2);
        inventoryCheckMapper.updateById(check);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void addDetail(Long checkId, InventoryCheckDTO.CheckDetailDTO detailDTO) {
        InventoryCheck check = getById(checkId);
        if (check.getStatus() == 1) {
            throw new BusinessException("盘点已完成，无法添加明细");
        }

        InventoryCheckDetail detail = new InventoryCheckDetail();
        BeanUtils.copyProperties(detailDTO, detail);
        detail.setCheckId(checkId);
        detail.setCheckTime(LocalDateTime.now());

        if (detail.getCheckWeight() != null && detail.getInventoryWeight() != null) {
            detail.setDiffWeight(detail.getCheckWeight().subtract(detail.getInventoryWeight()));
            if (detail.getDiffWeight().compareTo(BigDecimal.ZERO) > 0) {
                detail.setDiffType("盘盈");
            } else if (detail.getDiffWeight().compareTo(BigDecimal.ZERO) < 0) {
                detail.setDiffType("盘亏");
            } else {
                detail.setDiffType("正常");
            }
        }

        if (detail.getIsFound() == null) {
            detail.setIsFound(1);
        }

        inventoryCheckDetailMapper.insert(detail);

        updateCheckStatistics(checkId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchSync(List<InventoryCheckDTO> list, Long enterpriseId) {
        if (CollUtil.isEmpty(list)) {
            throw new BusinessException(ResultCode.SYNC_DATA_EMPTY);
        }

        List<String> offlineIds = new ArrayList<>();
        for (InventoryCheckDTO dto : list) {
            if (StrUtil.isBlank(dto.getOfflineId())) {
                throw new BusinessException(ResultCode.SYNC_DATA_ERROR, "离线数据ID不能为空");
            }
            offlineIds.add(dto.getOfflineId());
        }

        LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(InventoryCheck::getOfflineId, offlineIds);
        if (enterpriseId != null) {
            wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
        }
        List<InventoryCheck> existRecords = inventoryCheckMapper.selectList(wrapper);
        List<String> existOfflineIds = new ArrayList<>();
        for (InventoryCheck record : existRecords) {
            existOfflineIds.add(record.getOfflineId());
        }

        for (InventoryCheckDTO dto : list) {
            if (existOfflineIds.contains(dto.getOfflineId())) {
                continue;
            }
            try {
                createCheck(dto, enterpriseId);
                if (CollUtil.isNotEmpty(dto.getDetails())) {
                    InventoryCheck check = getByOfflineId(dto.getOfflineId(), enterpriseId);
                    if (check != null) {
                        for (InventoryCheckDTO.CheckDetailDTO detailDTO : dto.getDetails()) {
                            addDetail(check.getId(), detailDTO);
                        }
                    }
                }
            } catch (Exception e) {
                InventoryCheck failRecord = new InventoryCheck();
                BeanUtils.copyProperties(dto, failRecord);
                failRecord.setCheckNo(IdGeneratorUtils.generateCheckNo());
                failRecord.setSyncStatus(2);
                failRecord.setSyncFailReason(e.getMessage());
                if (enterpriseId != null) {
                    failRecord.setEnterpriseId(enterpriseId);
                }
                inventoryCheckMapper.insert(failRecord);
            }
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void completeCheck(Long id) {
        InventoryCheck check = getById(id);
        if (check.getStatus() == 1) {
            throw new BusinessException("盘点已完成，请勿重复操作");
        }
        if (check.getStatus() == 2) {
            throw new BusinessException("盘点已取消，无法完成");
        }

        updateCheckStatistics(id);

        check.setStatus(1);
        inventoryCheckMapper.updateById(check);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void auditCheck(Long id, Integer auditStatus, String auditRemark, Long userId) {
        InventoryCheck check = getById(id);
        if (check.getStatus() != 1) {
            throw new BusinessException("盘点未完成，无法审核");
        }
        if (check.getAuditStatus() == 1) {
            throw new BusinessException("盘点已审核，请勿重复操作");
        }

        check.setAuditStatus(auditStatus);
        check.setAuditUserId(userId);
        check.setAuditTime(LocalDateTime.now());
        check.setAuditRemark(auditRemark);
        inventoryCheckMapper.updateById(check);
    }

    @Override
    public boolean checkByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return false;
        }
        LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(InventoryCheck::getOfflineId, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
        }
        Long count = inventoryCheckMapper.selectCount(wrapper);
        return count != null && count > 0;
    }

    @Override
    public List<InventoryCheck> getPendingSyncList(Long enterpriseId) {
        LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
        wrapper.ne(InventoryCheck::getSyncStatus, 1);
        if (enterpriseId != null) {
            wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
        }
        wrapper.orderByAsc(InventoryCheck::getCreateTime);
        return inventoryCheckMapper.selectList(wrapper);
    }

    private InventoryCheck getByOfflineId(String offlineId, Long enterpriseId) {
        if (StrUtil.isBlank(offlineId)) {
            return null;
        }
        LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(InventoryCheck::getOfflineId, offlineId);
        if (enterpriseId != null) {
            wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
        }
        return inventoryCheckMapper.selectOne(wrapper);
    }

    private void updateCheckStatistics(Long checkId) {
        List<InventoryCheckDetail> details = getDetailsByCheckId(checkId);
        InventoryCheck check = getById(checkId);

        int checkedCount = 0;
        int missingCount = 0;
        int extraCount = 0;
        BigDecimal totalDiffWeight = BigDecimal.ZERO;

        for (InventoryCheckDetail detail : details) {
            checkedCount++;
            if (detail.getIsFound() != null && detail.getIsFound() == 0) {
                missingCount++;
            }
            if (detail.getDiffType() != null && "盘盈".equals(detail.getDiffType())) {
                extraCount++;
            }
            if (detail.getDiffWeight() != null) {
                totalDiffWeight = totalDiffWeight.add(detail.getDiffWeight());
            }
        }

        check.setCheckedContainers(checkedCount);
        check.setMissingContainers(missingCount);
        check.setExtraContainers(extraCount);
        check.setDiffWeight(totalDiffWeight);

        inventoryCheckMapper.updateById(check);
    }

    private LambdaQueryWrapper<InventoryCheck> buildQueryWrapper(InventoryCheck inventoryCheck, Long enterpriseId) {
        LambdaQueryWrapper<InventoryCheck> wrapper = new LambdaQueryWrapper<>();
        if (enterpriseId != null) {
            wrapper.eq(InventoryCheck::getEnterpriseId, enterpriseId);
        }
        if (inventoryCheck != null) {
            if (StrUtil.isNotBlank(inventoryCheck.getCheckNo())) {
                wrapper.like(InventoryCheck::getCheckNo, inventoryCheck.getCheckNo());
            }
            if (StrUtil.isNotBlank(inventoryCheck.getCheckName())) {
                wrapper.like(InventoryCheck::getCheckName, inventoryCheck.getCheckName());
            }
            if (StrUtil.isNotBlank(inventoryCheck.getCheckType())) {
                wrapper.eq(InventoryCheck::getCheckType, inventoryCheck.getCheckType());
            }
            if (inventoryCheck.getStatus() != null) {
                wrapper.eq(InventoryCheck::getStatus, inventoryCheck.getStatus());
            }
            if (inventoryCheck.getAuditStatus() != null) {
                wrapper.eq(InventoryCheck::getAuditStatus, inventoryCheck.getAuditStatus());
            }
            if (StrUtil.isNotBlank(inventoryCheck.getOperatorName())) {
                wrapper.like(InventoryCheck::getOperatorName, inventoryCheck.getOperatorName());
            }
            if (inventoryCheck.getSyncStatus() != null) {
                wrapper.eq(InventoryCheck::getSyncStatus, inventoryCheck.getSyncStatus());
            }
        }
        return wrapper;
    }
}
