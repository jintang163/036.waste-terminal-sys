-- =============================================
-- 升级脚本：双人复核出库功能
-- 日期：2026-06-16
-- =============================================

-- =============================================
-- 1. 为 waste_catalog 表新增高价值/高毒性标识字段
-- =============================================
ALTER TABLE waste_catalog
    ADD COLUMN is_high_value TINYINT NOT NULL DEFAULT 0 COMMENT '是否高价值: 0-否 1-是' AFTER status,
    ADD COLUMN is_high_toxic TINYINT NOT NULL DEFAULT 0 COMMENT '是否高毒性: 0-否 1-是' AFTER is_high_value,
    ADD COLUMN require_double_review TINYINT NOT NULL DEFAULT 0 COMMENT '是否需要双人复核: 0-否 1-是' AFTER is_high_toxic;

-- =============================================
-- 2. 为 waste_out_record 表新增复核相关字段
-- =============================================
ALTER TABLE waste_out_record
    ADD COLUMN review_status TINYINT NOT NULL DEFAULT 0 COMMENT '复核状态: 0-无需复核 1-待复核 2-复核通过 3-复核拒绝' AFTER status,
    ADD COLUMN reviewer_id BIGINT COMMENT '复核员ID' AFTER operator_id,
    ADD COLUMN reviewer_name VARCHAR(50) COMMENT '复核员姓名' AFTER operator_name,
    ADD COLUMN reviewer_face_id VARCHAR(64) COMMENT '复核员人脸ID' AFTER face_id,
    ADD COLUMN reviewer_face_image VARCHAR(255) COMMENT '复核时人脸抓拍图片' AFTER operator_face_image,
    ADD COLUMN reviewer_face_auth_id VARCHAR(64) COMMENT '复核员人脸认证ID' AFTER reviewer_face_id,
    ADD COLUMN review_time DATETIME COMMENT '复核时间' AFTER review_status,
    ADD COLUMN review_remark VARCHAR(500) COMMENT '复核备注' AFTER review_time;

-- =============================================
-- 3. 创建出库复核记录表
-- =============================================
DROP TABLE IF EXISTS waste_out_review;
CREATE TABLE waste_out_review (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    review_no VARCHAR(50) NOT NULL COMMENT '复核单号',
    out_record_id BIGINT COMMENT '出库记录ID',
    out_no VARCHAR(50) COMMENT '出库单号',
    out_offline_id VARCHAR(64) COMMENT '出库记录离线ID',
    waste_id BIGINT COMMENT '危废名录ID',
    waste_code VARCHAR(20) COMMENT '危废代码',
    waste_name VARCHAR(200) COMMENT '危废名称',
    weight DECIMAL(12,4) COMMENT '出库重量(kg)',
    container_code VARCHAR(50) COMMENT '容器编号',
    operator_id BIGINT COMMENT '操作员ID',
    operator_name VARCHAR(50) COMMENT '操作员姓名',
    reviewer_id BIGINT COMMENT '复核员ID',
    reviewer_name VARCHAR(50) COMMENT '复核员姓名',
    review_type VARCHAR(20) COMMENT '复核类型: high_value-高价值 high_toxic-高毒性',
    review_result TINYINT COMMENT '复核结果: 1-通过 2-拒绝',
    review_time DATETIME COMMENT '复核时间',
    review_remark VARCHAR(500) COMMENT '复核备注',
    reviewer_face_auth_id VARCHAR(64) COMMENT '复核员人脸认证ID',
    reviewer_face_id VARCHAR(64) COMMENT '复核员人脸ID',
    reviewer_face_image VARCHAR(255) COMMENT '复核时人脸抓拍图片',
    review_qr_code VARCHAR(500) COMMENT '复核二维码',
    sync_status TINYINT DEFAULT 0 COMMENT '同步状态: 0-未同步 1-同步中 2-已同步 3-同步失败',
    sync_time DATETIME COMMENT '同步时间',
    offline_id VARCHAR(64) COMMENT '离线数据ID',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_review_no (review_no),
    UNIQUE KEY uk_offline_id (offline_id),
    KEY idx_out_record_id (out_record_id),
    KEY idx_out_no (out_no),
    KEY idx_out_offline_id (out_offline_id),
    KEY idx_operator_id (operator_id),
    KEY idx_reviewer_id (reviewer_id),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废出库复核记录表';

-- =============================================
-- 4. 初始化高价值/高毒性危废示例数据（可选）
-- =============================================
-- UPDATE waste_catalog SET is_high_value = 1, require_double_review = 1 
-- WHERE waste_code IN ('HW08', 'HW09', 'HW12', 'HW13');
-- 
-- UPDATE waste_catalog SET is_high_toxic = 1, require_double_review = 1 
-- WHERE waste_code IN ('HW02', 'HW03', 'HW04', 'HW05', 'HW06');
