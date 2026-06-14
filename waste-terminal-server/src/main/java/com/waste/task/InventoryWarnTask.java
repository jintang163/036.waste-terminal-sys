package com.waste.task;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.waste.entity.WasteContainer;
import com.waste.entity.WasteInventory;
import com.waste.entity.WarningRecord;
import com.waste.mapper.WasteContainerMapper;
import com.waste.mapper.WasteInventoryMapper;
import com.waste.mapper.WarningRecordMapper;
import com.waste.mq.WasteMqProducer;
import com.waste.utils.IdGeneratorUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
public class InventoryWarnTask {

    @Autowired
    private WasteInventoryMapper wasteInventoryMapper;

    @Autowired
    private WasteContainerMapper wasteContainerMapper;

    @Autowired
    private WarningRecordMapper warningRecordMapper;

    @Autowired
    private WasteMqProducer wasteMqProducer;

    @Scheduled(cron = "0 0 1 * * ?")
    @Transactional(rollbackFor = Exception.class)
    public void executeInventoryWarnTask() {
        scanNearExpiryInventory();
        scanOverdueInventory();
        scanOverweightInventory();
    }

    private void scanNearExpiryInventory() {
        LocalDate today = LocalDate.now();
        LocalDate warnDate = today.plusDays(7);

        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getStatus, 1);
        wrapper.eq(WasteInventory::getWarnStatus, 0);
        wrapper.isNotNull(WasteInventory::getInDate);
        wrapper.isNotNull(WasteInventory::getStorageLimit);
        List<WasteInventory> list = wasteInventoryMapper.selectList(wrapper);

        for (WasteInventory inventory : list) {
            if (inventory.getInDate() == null || inventory.getStorageLimit() == null) {
                continue;
            }
            LocalDate expiryDate = inventory.getInDate().plusDays(inventory.getStorageLimit());
            long daysRemaining = ChronoUnit.DAYS.between(today, expiryDate);

            if (daysRemaining <= 7 && daysRemaining > 0) {
                inventory.setWarnStatus(1);
                wasteInventoryMapper.updateById(inventory);

                WarningRecord warning = new WarningRecord();
                warning.setWarningNo(IdGeneratorUtils.generateWarningNo());
                warning.setWarningType("NEAR_EXPIRY");
                warning.setWarningLevel(2);
                warning.setWasteCode(inventory.getWasteCode());
                warning.setWasteName(inventory.getWasteName());
                warning.setContainerId(inventory.getContainerId());
                warning.setContainerCode(inventory.getContainerCode());
                warning.setWarningContent("危废即将超期，剩余" + daysRemaining + "天，请及时处理！");
                warning.setTriggerTime(LocalDateTime.now());
                warning.setHandleStatus(0);
                warning.setPushStatus(0);
                warning.setEnterpriseId(inventory.getEnterpriseId());
                warningRecordMapper.insert(warning);

                try {
                    wasteMqProducer.sendWarningPush(warning);
                    log.info("即将超期预警生成成功，已发送推送消息, warningNo={}", warning.getWarningNo());
                } catch (Exception e) {
                    log.error("即将超期预警推送消息发送失败, warningNo={}", warning.getWarningNo(), e);
                }
            }
        }
    }

    private void scanOverdueInventory() {
        LocalDate today = LocalDate.now();

        LambdaQueryWrapper<WasteInventory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WasteInventory::getStatus, 1);
        wrapper.in(WasteInventory::getWarnStatus, 0, 1);
        wrapper.isNotNull(WasteInventory::getInDate);
        wrapper.isNotNull(WasteInventory::getStorageLimit);
        List<WasteInventory> list = wasteInventoryMapper.selectList(wrapper);

        for (WasteInventory inventory : list) {
            if (inventory.getInDate() == null || inventory.getStorageLimit() == null) {
                continue;
            }
            LocalDate expiryDate = inventory.getInDate().plusDays(inventory.getStorageLimit());
            long daysOverdue = ChronoUnit.DAYS.between(expiryDate, today);

            if (daysOverdue > 0) {
                inventory.setWarnStatus(2);
                wasteInventoryMapper.updateById(inventory);

                WarningRecord warning = new WarningRecord();
                warning.setWarningNo(IdGeneratorUtils.generateWarningNo());
                warning.setWarningType("OVERDUE");
                warning.setWarningLevel(3);
                warning.setWasteCode(inventory.getWasteCode());
                warning.setWasteName(inventory.getWasteName());
                warning.setContainerId(inventory.getContainerId());
                warning.setContainerCode(inventory.getContainerCode());
                warning.setWarningContent("危废已超期" + daysOverdue + "天，请立即处理！");
                warning.setTriggerTime(LocalDateTime.now());
                warning.setHandleStatus(0);
                warning.setPushStatus(0);
                warning.setEnterpriseId(inventory.getEnterpriseId());
                warningRecordMapper.insert(warning);

                try {
                    wasteMqProducer.sendWarningPush(warning);
                    log.info("超期预警生成成功，已发送推送消息, warningNo={}", warning.getWarningNo());
                } catch (Exception e) {
                    log.error("超期预警推送消息发送失败, warningNo={}", warning.getWarningNo(), e);
                }
            }
        }
    }

    private void scanOverweightInventory() {
        LambdaQueryWrapper<WasteContainer> containerWrapper = new LambdaQueryWrapper<>();
        List<WasteContainer> containers = wasteContainerMapper.selectList(containerWrapper);

        Map<Long, BigDecimal> containerCapacityMap = new HashMap<>();
        for (WasteContainer container : containers) {
            if (container.getCapacity() != null) {
                containerCapacityMap.put(container.getId(), container.getCapacity());
            }
        }

        LambdaQueryWrapper<WasteInventory> inventoryWrapper = new LambdaQueryWrapper<>();
        inventoryWrapper.eq(WasteInventory::getStatus, 1);
        List<WasteInventory> inventories = wasteInventoryMapper.selectList(inventoryWrapper);

        for (WasteInventory inventory : inventories) {
            BigDecimal capacity = containerCapacityMap.get(inventory.getContainerId());
            if (capacity == null || inventory.getWeight() == null) {
                continue;
            }

            BigDecimal usageRate = inventory.getWeight().divide(capacity, 4, BigDecimal.ROUND_HALF_UP)
                    .multiply(new BigDecimal("100"));

            if (usageRate.compareTo(new BigDecimal("90")) >= 0 && inventory.getWarnStatus() != 3) {
                inventory.setWarnStatus(3);
                wasteInventoryMapper.updateById(inventory);

                WarningRecord warning = new WarningRecord();
                warning.setWarningNo(IdGeneratorUtils.generateWarningNo());
                warning.setWarningType("OVERWEIGHT");
                warning.setWarningLevel(1);
                warning.setWasteCode(inventory.getWasteCode());
                warning.setWasteName(inventory.getWasteName());
                warning.setContainerId(inventory.getContainerId());
                warning.setContainerCode(inventory.getContainerCode());
                warning.setWarningContent("容器库存容量已达" + usageRate.setScale(2, BigDecimal.ROUND_HALF_UP) + "%，请注意！");
                warning.setTriggerTime(LocalDateTime.now());
                warning.setHandleStatus(0);
                warning.setPushStatus(0);
                warning.setEnterpriseId(inventory.getEnterpriseId());
                warningRecordMapper.insert(warning);

                try {
                    wasteMqProducer.sendWarningPush(warning);
                    log.info("超量预警生成成功，已发送推送消息, warningNo={}", warning.getWarningNo());
                } catch (Exception e) {
                    log.error("超量预警推送消息发送失败, warningNo={}", warning.getWarningNo(), e);
                }
            }
        }
    }
}
