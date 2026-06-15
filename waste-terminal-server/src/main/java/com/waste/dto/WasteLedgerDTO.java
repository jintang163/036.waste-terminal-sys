package com.waste.dto;

import lombok.Data;

import java.time.LocalDate;

@Data
public class WasteLedgerDTO {

    private Long id;

    private String ledgerType;

    private Integer periodYear;

    private Integer periodMonth;

    private LocalDate startDate;

    private LocalDate endDate;

    private Long enterpriseId;

    private String remark;

    private Integer generateStatus;

    private Integer reportStatus;
}
