package com.waste.dto;

import lombok.Data;

import javax.validation.constraints.NotBlank;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class InventoryCheckDTO {

    private Long id;

    private String checkNo;

    @NotBlank(message = "盘点名称不能为空")
    private String checkName;

    private String checkType;

    private LocalDate checkDate;

    private Integer totalContainers;

    private Integer checkedContainers;

    private Integer missingContainers;

    private Integer extraContainers;

    private BigDecimal diffWeight;

    private Integer status;

    private Integer auditStatus;

    private Long auditUserId;

    private String auditRemark;

    private Long operatorId;

    private String operatorName;

    private String remark;

    private Integer syncStatus;

    private String offlineId;

    private Long enterpriseId;

    private List<CheckDetailDTO> details;

    @Data
    public static class CheckDetailDTO {
        private Long id;
        private Long checkId;
        private String checkOfflineId;
        private Long containerId;
        private String containerCode;
        private Long wasteId;
        private String wasteCode;
        private String wasteName;
        private BigDecimal systemWeight;
        private BigDecimal actualWeight;
        private BigDecimal inventoryWeight;
        private BigDecimal checkWeight;
        private BigDecimal diffWeight;
        private String diffType;
        private Integer isFound;
        private String remark;
    }
}
