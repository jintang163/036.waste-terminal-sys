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
public class WasteLedgerExcelData {

    @ExcelProperty("序号")
    @ColumnWidth(8)
    private Integer seq;

    @ExcelProperty("业务类型")
    @ColumnWidth(12)
    private String detailType;

    @ExcelProperty("业务单号")
    @ColumnWidth(25)
    private String recordNo;

    @ExcelProperty("危废代码")
    @ColumnWidth(12)
    private String wasteCode;

    @ExcelProperty("危废名称")
    @ColumnWidth(25)
    private String wasteName;

    @ExcelProperty("废物类别")
    @ColumnWidth(15)
    private String wasteCategory;

    @ExcelProperty("危险特性")
    @ColumnWidth(12)
    private String hazardCode;

    @ExcelProperty("容器编号")
    @ColumnWidth(15)
    private String containerCode;

    @ExcelProperty("重量(kg)")
    @ColumnWidth(12)
    private BigDecimal weight;

    @ExcelProperty("变动类型")
    @ColumnWidth(12)
    private String changeType;

    @ExcelProperty("操作时间")
    @ColumnWidth(20)
    private String operateTime;

    @ExcelProperty("操作员")
    @ColumnWidth(12)
    private String operatorName;

    @ExcelProperty("备注")
    @ColumnWidth(30)
    private String remark;
}
