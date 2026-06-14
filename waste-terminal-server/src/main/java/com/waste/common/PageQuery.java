package com.waste.common;

import lombok.Data;

import java.io.Serializable;

/**
 * 分页查询参数基类
 */
@Data
public class PageQuery implements Serializable {

    private static final long serialVersionUID = 1L;

    private Long pageNum = 1L;
    private Long pageSize = 10L;
    private String orderBy;
    private String orderDirection = "desc";

    public Long getPageNum() {
        return pageNum != null && pageNum > 0 ? pageNum : 1L;
    }

    public Long getPageSize() {
        if (pageSize == null || pageSize <= 0) {
            return 10L;
        }
        return pageSize > 100 ? 100L : pageSize;
    }
}
