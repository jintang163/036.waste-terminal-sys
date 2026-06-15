package com.waste.excel;

import com.alibaba.excel.annotation.ExcelProperty;
import com.alibaba.excel.annotation.write.style.ColumnWidth;
import com.alibaba.excel.annotation.write.style.ContentRowHeight;
import com.alibaba.excel.annotation.write.style.HeadRowHeight;
import lombok.Data;

import java.math.BigDecimal;

@Data
@HeadRowHeight(20)
@ContentRowHeight(18)
@ColumnWidth(20)
public class WasteLedgerSummaryExcelData {

    @ExcelProperty("项目")
    @ColumnWidth(25)
    private String item;

    @ExcelProperty("数量")
    @ColumnWidth(15)
    private Integer count;

    @ExcelProperty("重量(kg)")
    @ColumnWidth(15)
    private BigDecimal weight;

    @ExcelProperty("备注")
    @ColumnWidth(30)
    private String remark;
}
