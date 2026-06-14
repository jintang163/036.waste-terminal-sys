-- =============================================
-- 危废智能终端系统 - 数据库脚本
-- 数据库: MySQL 8.0+
-- 创建日期: 2026-06-13
-- =============================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS waste_terminal DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE waste_terminal;

-- =============================================
-- 1. 系统用户表
-- =============================================
DROP TABLE IF EXISTS sys_user;
CREATE TABLE sys_user (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    username VARCHAR(50) NOT NULL COMMENT '用户名',
    password VARCHAR(100) NOT NULL COMMENT '密码(SM4加密)',
    real_name VARCHAR(50) COMMENT '真实姓名',
    phone VARCHAR(20) COMMENT '手机号',
    email VARCHAR(100) COMMENT '邮箱',
    avatar VARCHAR(255) COMMENT '头像URL',
    dept_id BIGINT COMMENT '部门ID',
    role VARCHAR(20) NOT NULL DEFAULT 'operator' COMMENT '角色: admin-管理员 operator-操作员 inspector-巡检员',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-禁用 1-启用',
    last_login_time DATETIME COMMENT '最后登录时间',
    last_login_ip VARCHAR(50) COMMENT '最后登录IP',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除: 0-未删除 1-已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username),
    KEY idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统用户表';

-- =============================================
-- 2. 企业信息表
-- =============================================
DROP TABLE IF EXISTS enterprise_info;
CREATE TABLE enterprise_info (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '企业ID',
    enterprise_name VARCHAR(200) NOT NULL COMMENT '企业名称',
    enterprise_code VARCHAR(50) NOT NULL COMMENT '企业统一社会信用代码',
    legal_person VARCHAR(50) COMMENT '法人代表',
    contact_person VARCHAR(50) COMMENT '联系人',
    contact_phone VARCHAR(20) COMMENT '联系电话',
    address VARCHAR(500) COMMENT '地址',
    province VARCHAR(50) COMMENT '省份',
    city VARCHAR(50) COMMENT '城市',
    district VARCHAR(50) COMMENT '区县',
    business_license VARCHAR(255) COMMENT '营业执照URL',
    waste_license VARCHAR(255) COMMENT '危废经营许可证URL',
    license_expire_date DATE COMMENT '许可证到期日期',
    storage_capacity DECIMAL(12,2) COMMENT '贮存总容量(吨)',
    storage_used DECIMAL(12,2) DEFAULT 0 COMMENT '已用容量(吨)',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-禁用 1-启用',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_enterprise_code (enterprise_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企业信息表';

-- =============================================
-- 3. 危废名录表
-- =============================================
DROP TABLE IF EXISTS waste_catalog;
CREATE TABLE waste_catalog (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    waste_code VARCHAR(20) NOT NULL COMMENT '危废代码',
    waste_name VARCHAR(200) NOT NULL COMMENT '危废名称',
    waste_category VARCHAR(50) COMMENT '废物类别',
    waste_type VARCHAR(50) COMMENT '废物类型',
    hazard_code VARCHAR(20) COMMENT '危险特性',
    disposal_method VARCHAR(100) COMMENT '处置方式',
    storage_requirement VARCHAR(500) COMMENT '贮存要求',
    safety_measures VARCHAR(500) COMMENT '安全措施',
    description TEXT COMMENT '描述',
    sort_order INT DEFAULT 0 COMMENT '排序',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-禁用 1-启用',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_waste_code (waste_code),
    KEY idx_waste_name (waste_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废名录表';

-- =============================================
-- 4. 危废容器表
-- =============================================
DROP TABLE IF EXISTS waste_container;
CREATE TABLE waste_container (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '容器ID',
    container_code VARCHAR(50) NOT NULL COMMENT '容器编号(二维码内容)',
    container_type VARCHAR(20) COMMENT '容器类型: barrel-桶 bag-袋 tank-罐 other-其他',
    container_spec VARCHAR(50) COMMENT '容器规格',
    material VARCHAR(50) COMMENT '容器材质',
    capacity DECIMAL(10,2) COMMENT '额定容量(L)',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-报废 1-空闲 2-使用中',
    location VARCHAR(100) COMMENT '存放位置',
    rfid_code VARCHAR(100) COMMENT 'RFID编号',
    enterprise_id BIGINT COMMENT '所属企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_container_code (container_code),
    KEY idx_enterprise_id (enterprise_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废容器表';

-- =============================================
-- 5. 危废入库记录表
-- =============================================
DROP TABLE IF EXISTS waste_in_record;
CREATE TABLE waste_in_record (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '入库记录ID',
    in_no VARCHAR(50) NOT NULL COMMENT '入库单号',
    container_id BIGINT COMMENT '容器ID',
    container_code VARCHAR(50) COMMENT '容器编号',
    waste_id BIGINT COMMENT '危废名录ID',
    waste_code VARCHAR(20) COMMENT '危废代码',
    waste_name VARCHAR(200) COMMENT '危废名称',
    waste_category VARCHAR(50) COMMENT '废物类别',
    hazard_code VARCHAR(20) COMMENT '危险特性',
    weight DECIMAL(12,4) NOT NULL COMMENT '重量(kg)',
    weight_source VARCHAR(20) DEFAULT 'manual' COMMENT '重量来源: manual-手动 scale-地磅',
    scale_device VARCHAR(50) COMMENT '地磅设备编号',
    produce_date DATE COMMENT '产生日期',
    produce_department VARCHAR(100) COMMENT '产生部门/工序',
    storage_location VARCHAR(100) COMMENT '贮存位置',
    operator_id BIGINT COMMENT '操作员ID',
    operator_name VARCHAR(50) COMMENT '操作员姓名',
    photos TEXT COMMENT '照片URL(多个逗号分隔)',
    remark VARCHAR(500) COMMENT '备注',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-作废 1-待同步 2-已同步 3-已确认',
    sync_status TINYINT DEFAULT 0 COMMENT '同步状态: 0-未同步 1-同步中 2-已同步 3-同步失败',
    sync_time DATETIME COMMENT '同步时间',
    sync_fail_reason VARCHAR(500) COMMENT '同步失败原因',
    offline_id VARCHAR(64) COMMENT '离线数据ID(移动端生成)',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_in_no (in_no),
    UNIQUE KEY uk_offline_id (offline_id),
    KEY idx_container_id (container_id),
    KEY idx_waste_code (waste_code),
    KEY idx_create_time (create_time),
    KEY idx_sync_status (sync_status),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废入库记录表';

-- =============================================
-- 6. 危废库存表
-- =============================================
DROP TABLE IF EXISTS waste_inventory;
CREATE TABLE waste_inventory (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '库存ID',
    container_id BIGINT NOT NULL COMMENT '容器ID',
    container_code VARCHAR(50) COMMENT '容器编号',
    waste_id BIGINT COMMENT '危废名录ID',
    waste_code VARCHAR(20) COMMENT '危废代码',
    waste_name VARCHAR(200) COMMENT '危废名称',
    waste_category VARCHAR(50) COMMENT '废物类别',
    hazard_code VARCHAR(20) COMMENT '危险特性',
    weight DECIMAL(12,4) NOT NULL COMMENT '当前重量(kg)',
    in_weight DECIMAL(12,4) DEFAULT 0 COMMENT '入库重量(kg)',
    out_weight DECIMAL(12,4) DEFAULT 0 COMMENT '出库重量(kg)',
    storage_days INT DEFAULT 0 COMMENT '贮存天数',
    storage_limit INT COMMENT '贮存期限(天)',
    produce_date DATE COMMENT '产生日期',
    in_date DATE COMMENT '入库日期',
    storage_location VARCHAR(100) COMMENT '贮存位置',
    warn_status TINYINT DEFAULT 0 COMMENT '预警状态: 0-正常 1-即将到期 2-已超期 3-超量',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-已出库 1-在库',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_container_id (container_id),
    KEY idx_waste_code (waste_code),
    KEY idx_status (status),
    KEY idx_warn_status (warn_status),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废库存表';

-- =============================================
-- 7. 危废出库记录表
-- =============================================
DROP TABLE IF EXISTS waste_out_record;
CREATE TABLE waste_out_record (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '出库记录ID',
    out_no VARCHAR(50) NOT NULL COMMENT '出库单号',
    transfer_order_id BIGINT COMMENT '转移联单ID',
    container_id BIGINT COMMENT '容器ID',
    container_code VARCHAR(50) COMMENT '容器编号',
    waste_id BIGINT COMMENT '危废名录ID',
    waste_code VARCHAR(20) COMMENT '危废代码',
    waste_name VARCHAR(200) COMMENT '危废名称',
    weight DECIMAL(12,4) NOT NULL COMMENT '出库重量(kg)',
    receiver_unit_id BIGINT COMMENT '接收单位ID',
    receiver_unit_name VARCHAR(200) COMMENT '接收单位名称',
    transporter_id BIGINT COMMENT '运输单位ID',
    transporter_name VARCHAR(200) COMMENT '运输单位名称',
    vehicle_no VARCHAR(20) COMMENT '运输车牌号',
    driver_name VARCHAR(50) COMMENT '司机姓名',
    driver_phone VARCHAR(20) COMMENT '司机电话',
    out_time DATETIME COMMENT '出库时间',
    operator_id BIGINT COMMENT '操作员ID',
    operator_name VARCHAR(50) COMMENT '操作员姓名',
    remark VARCHAR(500) COMMENT '备注',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-作废 1-待出库 2-已出库 3-已签收',
    sign_status TINYINT DEFAULT 0 COMMENT '签收状态: 0-待签收 1-已签收',
    sign_time DATETIME COMMENT '签收时间',
    sign_photo VARCHAR(255) COMMENT '签收照片',
    receipt_photo VARCHAR(255) COMMENT '回执照片',
    sync_status TINYINT DEFAULT 0 COMMENT '同步状态: 0-未同步 1-同步中 2-已同步 3-同步失败',
    sync_time DATETIME COMMENT '同步时间',
    offline_id VARCHAR(64) COMMENT '离线数据ID',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_out_no (out_no),
    UNIQUE KEY uk_offline_id (offline_id),
    KEY idx_transfer_order_id (transfer_order_id),
    KEY idx_container_id (container_id),
    KEY idx_waste_code (waste_code),
    KEY idx_status (status),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废出库记录表';

-- =============================================
-- 8. 危废转移联单表
-- =============================================
DROP TABLE IF EXISTS waste_transfer_order;
CREATE TABLE waste_transfer_order (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '联单ID',
    order_no VARCHAR(50) NOT NULL COMMENT '联单编号',
    national_order_no VARCHAR(50) COMMENT '国家平台联单编号',
    order_type VARCHAR(20) DEFAULT 'normal' COMMENT '联单类型: normal-普通 emergency-应急',
    generator_unit_id BIGINT COMMENT '产生单位ID',
    generator_unit_name VARCHAR(200) COMMENT '产生单位名称',
    generator_unit_code VARCHAR(50) COMMENT '产生单位信用代码',
    receiver_unit_id BIGINT COMMENT '接收单位ID',
    receiver_unit_name VARCHAR(200) COMMENT '接收单位名称',
    receiver_unit_code VARCHAR(50) COMMENT '接收单位信用代码',
    receiver_license_no VARCHAR(100) COMMENT '接收单位经营许可证号',
    transporter_id BIGINT COMMENT '运输单位ID',
    transporter_name VARCHAR(200) COMMENT '运输单位名称',
    transporter_license_no VARCHAR(100) COMMENT '运输许可证号',
    vehicle_no VARCHAR(20) COMMENT '运输车辆牌号',
    driver_name VARCHAR(50) COMMENT '驾驶员姓名',
    driver_license VARCHAR(50) COMMENT '驾驶员从业资格证号',
    escort_name VARCHAR(50) COMMENT '押运员姓名',
    total_weight DECIMAL(12,4) COMMENT '总重量(kg)',
    total_containers INT COMMENT '总容器数',
    waste_details TEXT COMMENT '危废明细(JSON数组)',
    start_time DATETIME COMMENT '出发时间',
    estimate_arrive_time DATETIME COMMENT '预计到达时间',
    actual_arrive_time DATETIME COMMENT '实际到达时间',
    route VARCHAR(500) COMMENT '运输路线',
    emergency_contact VARCHAR(50) COMMENT '应急联系人',
    emergency_phone VARCHAR(20) COMMENT '应急电话',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-作废 1-待提交 2-待运输 3-运输中 4-已到达 5-已签收 6-已完成',
    report_status TINYINT DEFAULT 0 COMMENT '上报状态: 0-未上报 1-上报中 2-已上报 3-上报失败',
    report_time DATETIME COMMENT '上报时间',
    qr_code VARCHAR(255) COMMENT '联单二维码URL',
    sign_photo VARCHAR(255) COMMENT '签收照片',
    receipt_photo VARCHAR(255) COMMENT '回执照片',
    remark VARCHAR(500) COMMENT '备注',
    offline_id VARCHAR(64) COMMENT '离线数据ID',
    operator_id BIGINT COMMENT '创建人ID',
    operator_name VARCHAR(50) COMMENT '创建人姓名',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    UNIQUE KEY uk_national_order_no (national_order_no),
    UNIQUE KEY uk_offline_id (offline_id),
    KEY idx_status (status),
    KEY idx_report_status (report_status),
    KEY idx_create_time (create_time),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='危废转移联单表';

-- =============================================
-- 9. 库存盘点表
-- =============================================
DROP TABLE IF EXISTS inventory_check;
CREATE TABLE inventory_check (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '盘点ID',
    check_no VARCHAR(50) NOT NULL COMMENT '盘点单号',
    check_name VARCHAR(200) COMMENT '盘点名称',
    check_type VARCHAR(20) DEFAULT 'full' COMMENT '盘点类型: full-全盘 partial-抽盘',
    check_date DATE COMMENT '盘点日期',
    total_containers INT DEFAULT 0 COMMENT '应盘容器数',
    checked_containers INT DEFAULT 0 COMMENT '实盘容器数',
    missing_containers INT DEFAULT 0 COMMENT '缺失容器数',
    extra_containers INT DEFAULT 0 COMMENT '多余容器数',
    diff_weight DECIMAL(12,4) DEFAULT 0 COMMENT '差异重量(kg)',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1-盘点中 2-已完成 3-已审核',
    audit_status TINYINT DEFAULT 0 COMMENT '审核状态: 0-待审核 1-审核通过 2-审核不通过',
    audit_user_id BIGINT COMMENT '审核人ID',
    audit_time DATETIME COMMENT '审核时间',
    audit_remark VARCHAR(500) COMMENT '审核意见',
    operator_id BIGINT COMMENT '盘点人ID',
    operator_name VARCHAR(50) COMMENT '盘点人姓名',
    remark VARCHAR(500) COMMENT '备注',
    sync_status TINYINT DEFAULT 0 COMMENT '同步状态',
    offline_id VARCHAR(64) COMMENT '离线数据ID',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_check_no (check_no),
    UNIQUE KEY uk_offline_id (offline_id),
    KEY idx_check_date (check_date),
    KEY idx_status (status),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存盘点表';

-- =============================================
-- 10. 盘点明细表
-- =============================================
DROP TABLE IF EXISTS inventory_check_detail;
CREATE TABLE inventory_check_detail (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '明细ID',
    check_id BIGINT NOT NULL COMMENT '盘点ID',
    check_offline_id VARCHAR(64) COMMENT '盘点离线ID',
    container_id BIGINT COMMENT '容器ID',
    container_code VARCHAR(50) COMMENT '容器编号',
    waste_id BIGINT COMMENT '危废名录ID',
    waste_code VARCHAR(20) COMMENT '危废代码',
    waste_name VARCHAR(200) COMMENT '危废名称',
    inventory_weight DECIMAL(12,4) COMMENT '账面重量(kg)',
    check_weight DECIMAL(12,4) COMMENT '实盘重量(kg)',
    diff_weight DECIMAL(12,4) COMMENT '差异重量(kg)',
    diff_type VARCHAR(20) COMMENT '差异类型: normal-正常 missing-缺失 extra-多余 more-多了 less-少了',
    is_found TINYINT DEFAULT 1 COMMENT '是否找到: 0-未找到 1-已找到',
    check_time DATETIME COMMENT '盘点时间',
    remark VARCHAR(500) COMMENT '备注',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_check_id (check_id),
    KEY idx_container_id (container_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='盘点明细表';

-- =============================================
-- 11. 预警记录表
-- =============================================
DROP TABLE IF EXISTS warning_record;
CREATE TABLE warning_record (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '预警ID',
    warning_no VARCHAR(50) NOT NULL COMMENT '预警编号',
    warning_type VARCHAR(30) NOT NULL COMMENT '预警类型: expire-即将超期 overdue-已超期 over_capacity-超量 low_stock-库存不足',
    warning_level TINYINT NOT NULL DEFAULT 1 COMMENT '预警级别: 1-一般 2-较重 3-严重',
    waste_code VARCHAR(20) COMMENT '危废代码',
    waste_name VARCHAR(200) COMMENT '危废名称',
    container_id BIGINT COMMENT '容器ID',
    container_code VARCHAR(50) COMMENT '容器编号',
    warning_content TEXT COMMENT '预警内容',
    trigger_time DATETIME NOT NULL COMMENT '触发时间',
    handle_status TINYINT DEFAULT 0 COMMENT '处理状态: 0-未处理 1-处理中 2-已处理 3-已忽略',
    handle_user_id BIGINT COMMENT '处理人ID',
    handle_time DATETIME COMMENT '处理时间',
    handle_remark VARCHAR(500) COMMENT '处理说明',
    push_status TINYINT DEFAULT 0 COMMENT '推送状态: 0-未推送 1-已推送 2-推送失败',
    push_time DATETIME COMMENT '推送时间',
    push_fail_reason VARCHAR(500) COMMENT '推送失败原因',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_warning_no (warning_no),
    KEY idx_warning_type (warning_type),
    KEY idx_warning_level (warning_level),
    KEY idx_handle_status (handle_status),
    KEY idx_trigger_time (trigger_time),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='预警记录表';

-- =============================================
-- 12. 数据同步记录表
-- =============================================
DROP TABLE IF EXISTS sync_record;
CREATE TABLE sync_record (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '同步ID',
    sync_no VARCHAR(50) NOT NULL COMMENT '同步编号',
    sync_type VARCHAR(30) NOT NULL COMMENT '同步类型: in-入库 out-出库 inventory-库存 catalog-名录 order-联单',
    sync_direction VARCHAR(10) NOT NULL COMMENT '同步方向: up-上行(端→云) down-下行(云→端)',
    device_id VARCHAR(100) COMMENT '设备ID',
    total_count INT DEFAULT 0 COMMENT '总记录数',
    success_count INT DEFAULT 0 COMMENT '成功数',
    fail_count INT DEFAULT 0 COMMENT '失败数',
    sync_time DATETIME COMMENT '同步时间',
    sync_duration INT COMMENT '同步耗时(秒)',
    status TINYINT DEFAULT 1 COMMENT '状态: 1-同步中 2-成功 3-失败',
    fail_reason VARCHAR(500) COMMENT '失败原因',
    operator_id BIGINT COMMENT '操作员ID',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sync_no (sync_no),
    KEY idx_sync_type (sync_type),
    KEY idx_sync_direction (sync_direction),
    KEY idx_device_id (device_id),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据同步记录表';

-- =============================================
-- 13. 文件管理表
-- =============================================
DROP TABLE IF EXISTS sys_file;
CREATE TABLE sys_file (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '文件ID',
    file_name VARCHAR(255) NOT NULL COMMENT '文件名',
    file_url VARCHAR(500) NOT NULL COMMENT '文件URL',
    file_size BIGINT COMMENT '文件大小(字节)',
    file_type VARCHAR(50) COMMENT '文件类型: image-图片 video-视频 document-文档 other-其他',
    file_ext VARCHAR(20) COMMENT '文件扩展名',
    storage_type VARCHAR(20) DEFAULT 'minio' COMMENT '存储方式: local-本地 minio-MinIO',
    bucket_name VARCHAR(50) COMMENT 'MinIO桶名',
    object_key VARCHAR(255) COMMENT '对象键',
    md5 VARCHAR(32) COMMENT '文件MD5',
    biz_type VARCHAR(50) COMMENT '业务类型: waste_photo-危废照片 receipt-回执 qrcode-二维码',
    biz_id VARCHAR(64) COMMENT '业务ID',
    upload_user_id BIGINT COMMENT '上传人ID',
    enterprise_id BIGINT COMMENT '企业ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    KEY idx_biz_type (biz_type),
    KEY idx_biz_id (biz_id),
    KEY idx_md5 (md5),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='文件管理表';

-- =============================================
-- 14. 设备管理表
-- =============================================
DROP TABLE IF EXISTS device_info;
CREATE TABLE device_info (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '设备ID',
    device_no VARCHAR(50) NOT NULL COMMENT '设备编号',
    device_name VARCHAR(100) COMMENT '设备名称',
    device_type VARCHAR(20) COMMENT '设备类型: scale-地磅 printer-打印机 pda-手持终端',
    device_model VARCHAR(50) COMMENT '设备型号',
    manufacturer VARCHAR(100) COMMENT '生产厂家',
    connect_type VARCHAR(20) COMMENT '连接方式: bluetooth-蓝牙 usb-USB serial-串口',
    mac_address VARCHAR(50) COMMENT 'MAC地址',
    serial_port VARCHAR(20) COMMENT '串口号',
    baud_rate INT COMMENT '波特率',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-离线 1-在线 2-故障',
    last_connect_time DATETIME COMMENT '最后连接时间',
    enterprise_id BIGINT COMMENT '所属企业ID',
    remark VARCHAR(500) COMMENT '备注',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_device_no (device_no),
    KEY idx_device_type (device_type),
    KEY idx_status (status),
    KEY idx_enterprise_id (enterprise_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备管理表';

-- =============================================
-- 初始化数据
-- =============================================

-- 初始化系统用户 (密码: 123456, 需使用SM4加密)
INSERT INTO sys_user (username, password, real_name, phone, role, status) VALUES
('admin', 'sm4_encrypted_password', '系统管理员', '13800138000', 'admin', 1),
('operator01', 'sm4_encrypted_password', '张操作员', '13800138001', 'operator', 1),
('operator02', 'sm4_encrypted_password', '李操作员', '13800138002', 'operator', 1);

-- 初始化危废名录(示例数据)
INSERT INTO waste_catalog (waste_code, waste_name, waste_category, waste_type, hazard_code, disposal_method, sort_order) VALUES
('HW01', '医院临床废物', '医院废物', '医疗废物', 'T/In', '焚烧处置', 1),
('HW02', '医药废物', '医药废物', '工业废物', 'T', '焚烧/安全填埋', 2),
('HW03', '废药物、药品', '废药物药品', '工业废物', 'T', '焚烧处置', 3),
('HW04', '农药废物', '农药废物', '工业废物', 'T', '焚烧/安全填埋', 4),
('HW05', '木材防腐剂废物', '木材防腐剂废物', '工业废物', 'T', '焚烧处置', 5),
('HW06', '废有机溶剂与含有机溶剂废物', '有机溶剂废物', '工业废物', 'T/I', '焚烧/蒸馏回收', 6),
('HW07', '热处理含氰废物', '热处理含氰废物', '工业废物', 'T', '化学处理/安全填埋', 7),
('HW08', '废矿物油与含矿物油废物', '废矿物油', '工业废物', 'T,I', '焚烧/回收利用', 8),
('HW09', '油水、烃/水混合物或乳化液', '油/水、烃/水混合物', '工业废物', 'T', '分离/焚烧', 9),
('HW10', '多氯（溴）联苯类废物', '多氯联苯类废物', '工业废物', 'T', '焚烧处置', 10),
('HW11', '精（蒸）馏残渣', '精（蒸）馏残渣', '工业废物', 'T', '焚烧/安全填埋', 11),
('HW12', '染料、涂料废物', '染料涂料废物', '工业废物', 'T', '焚烧处置', 12),
('HW13', '有机树脂类废物', '有机树脂类废物', '工业废物', 'T', '焚烧处置', 13),
('HW14', '新化学物质废物', '新化学物质废物', '工业废物', 'T', '危险废物处置', 14),
('HW15', '爆炸性废物', '爆炸性废物', '工业废物', 'E', '爆炸物处置', 15),
('HW16', '感光材料废物', '感光材料废物', '工业废物', 'T', '回收/焚烧', 16),
('HW17', '表面处理废物', '表面处理废物', '工业废物', 'T/C', '化学处理/安全填埋', 17),
('HW18', '焚烧处置残渣', '焚烧处置残渣', '工业废物', 'T', '安全填埋', 18),
('HW19', '含金属羰基化合物废物', '含金属羰基化合物废物', '工业废物', 'T', '化学处理', 19),
('HW20', '含铍废物', '含铍废物', '工业废物', 'T', '安全填埋', 20),
('HW21', '含铬废物', '含铬废物', '工业废物', 'T', '化学处理/安全填埋', 21),
('HW22', '含铜废物', '含铜废物', '工业废物', 'T', '回收利用/安全填埋', 22),
('HW23', '含锌废物', '含锌废物', '工业废物', 'T', '回收利用/安全填埋', 23),
('HW24', '含砷废物', '含砷废物', '工业废物', 'T', '安全填埋', 24),
('HW25', '含硒废物', '含硒废物', '工业废物', 'T', '安全填埋', 25),
('HW26', '含镉废物', '含镉废物', '工业废物', 'T', '安全填埋', 26),
('HW27', '含锑废物', '含锑废物', '工业废物', 'T', '安全填埋', 27),
('HW28', '含碲废物', '含碲废物', '工业废物', 'T', '安全填埋', 28),
('HW29', '含汞废物', '含汞废物', '工业废物', 'T', '回收/安全填埋', 29),
('HW30', '含铊废物', '含铊废物', '工业废物', 'T', '安全填埋', 30),
('HW31', '含铅废物', '含铅废物', '工业废物', 'T', '回收利用/安全填埋', 31),
('HW32', '无机氟化物废物', '无机氟化物废物', '工业废物', 'T/C', '化学处理/安全填埋', 32),
('HW33', '无机氰化物废物', '无机氰化物废物', '工业废物', 'T', '化学处理/安全填埋', 33),
('HW34', '废酸', '废酸', '工业废物', 'C', '中和/回收', 34),
('HW35', '废碱', '废碱', '工业废物', 'C', '中和/回收', 35),
('HW36', '石棉废物', '石棉废物', '工业废物', 'T', '安全填埋', 36),
('HW37', '有机磷化合物废物', '有机磷化合物废物', '工业废物', 'T', '焚烧处置', 37),
('HW38', '有机氰化物废物', '有机氰化物废物', '工业废物', 'T', '焚烧处置', 38),
('HW39', '含酚废物', '含酚废物', '工业废物', 'T', '焚烧/化学处理', 39),
('HW40', '含醚废物', '含醚废物', '工业废物', 'T', '焚烧处置', 40),
('HW41', '废卤化有机溶剂', '废卤化有机溶剂', '工业废物', 'T', '焚烧/回收', 41),
('HW42', '废有机溶剂', '废有机溶剂', '工业废物', 'T/I', '焚烧/回收', 42),
('HW43', '含多氯苯并二恶英类废物', '含多氯苯并二恶英', '工业废物', 'T', '焚烧处置', 43),
('HW44', '含多氯苯并呋喃类废物', '含多氯苯并呋喃', '工业废物', 'T', '焚烧处置', 44),
('HW45', '含有机卤化物废物', '含有机卤化物废物', '工业废物', 'T', '焚烧处置', 45),
('HW46', '含镍废物', '含镍废物', '工业废物', 'T', '回收利用', 46),
('HW47', '含钡废物', '含钡废物', '工业废物', 'T', '化学处理/安全填埋', 47),
('HW48', '有色金属冶炼废物', '有色金属冶炼废物', '工业废物', 'T', '回收利用/安全填埋', 48),
('HW49', '其他废物', '其他废物', '其他废物', 'T/In', '按危废处置', 49),
('HW50', '废催化剂', '废催化剂', '工业废物', 'T', '回收利用', 50);

-- 初始化企业信息
INSERT INTO enterprise_info (enterprise_name, enterprise_code, legal_person, contact_person, contact_phone, address, province, city, district, storage_capacity, status) VALUES
('某化工有限公司', '91320100MA12345678', '张三', '李四', '13800138000', '江苏省南京市化工园区1号', '江苏省', '南京市', '六合区', 500.00, 1);

-- 初始化容器信息
INSERT INTO waste_container (container_code, container_type, container_spec, material, capacity, status, location, enterprise_id) VALUES
('C20240001', 'barrel', '200L', 'HDPE', 200.00, 1, 'A区-01号货架', 1),
('C20240002', 'barrel', '200L', 'HDPE', 200.00, 1, 'A区-01号货架', 1),
('C20240003', 'barrel', '200L', 'HDPE', 200.00, 1, 'A区-02号货架', 1),
('C20240004', 'bag', '1吨袋', 'PP', 1000.00, 1, 'B区-03号货架', 1),
('C20240005', 'bag', '1吨袋', 'PP', 1000.00, 1, 'B区-03号货架', 1);

-- =============================================
-- 15. 国家平台上报记录表
-- =============================================
DROP TABLE IF EXISTS platform_report_record;
CREATE TABLE platform_report_record (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    report_no VARCHAR(64) NOT NULL COMMENT '上报编号(系统生成)',
    biz_type VARCHAR(32) NOT NULL COMMENT '业务类型: WASTE_IN-入库 WASTE_OUT-出库 TRANSFER_ORDER-电子联单 TRANSFER_COMPLETE-联单完成',
    biz_id VARCHAR(64) NOT NULL COMMENT '业务ID(关联本地业务表主键)',
    biz_no VARCHAR(64) COMMENT '业务编号(入库单号/出库单号/联单编号)',
    api_path VARCHAR(128) COMMENT '上报接口路径',
    report_status TINYINT NOT NULL DEFAULT 0 COMMENT '上报状态: 0-待上报 1-成功 2-失败 3-重试中',
    retry_count INT NOT NULL DEFAULT 0 COMMENT '已重试次数(累加)',
    max_retry_count INT NOT NULL DEFAULT 3 COMMENT '最大重试次数',
    first_report_time DATETIME COMMENT '首次上报时间',
    last_report_time DATETIME COMMENT '最近上报时间',
    next_retry_time DATETIME COMMENT '下次重试时间',
    request_payload TEXT COMMENT '请求报文(加密后)',
    response_payload TEXT COMMENT '响应报文',
    fail_reason VARCHAR(500) COMMENT '失败原因',
    national_biz_no VARCHAR(64) COMMENT '国家平台返回的业务编号',
    enterprise_id BIGINT COMMENT '企业ID',
    device_id VARCHAR(64) COMMENT '设备ID',
    duration_ms BIGINT COMMENT '上报耗时(毫秒)',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by VARCHAR(64) COMMENT '创建人',
    update_by VARCHAR(64) COMMENT '更新人',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除: 0-未删除 1-已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_biz_type_id (biz_type, biz_id),
    KEY idx_report_no (report_no),
    KEY idx_biz_type (biz_type),
    KEY idx_report_status (report_status),
    KEY idx_enterprise_id (enterprise_id),
    KEY idx_last_report_time (last_report_time),
    KEY idx_next_retry_time (next_retry_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='国家平台上报记录表';

-- =============================================
-- 16. 数据版本管理表
-- =============================================
DROP TABLE IF EXISTS data_version;
CREATE TABLE data_version (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '版本ID',
    data_type VARCHAR(32) NOT NULL COMMENT '数据类型: WASTE_CATALOG-危废名录 RECEIVER_UNIT-接收单位 VEHICLE-车辆 CONTAINER-容器 INVENTORY-库存',
    version BIGINT NOT NULL DEFAULT 1 COMMENT '版本号(递增)',
    version_time DATETIME NOT NULL COMMENT '版本生效时间',
    change_summary VARCHAR(500) COMMENT '变更摘要',
    record_count BIGINT DEFAULT 0 COMMENT '该版本包含记录数',
    enterprise_id BIGINT COMMENT '企业ID(空表示全局数据)',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by VARCHAR(64) COMMENT '创建人',
    update_by VARCHAR(64) COMMENT '更新人',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    PRIMARY KEY (id),
    KEY idx_data_type (data_type),
    KEY idx_data_type_version (data_type, version),
    KEY idx_enterprise_id (enterprise_id),
    KEY idx_version_time (version_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据版本管理表';

-- =============================================
-- 初始化数据版本
-- =============================================
INSERT INTO data_version (data_type, version, version_time, change_summary, record_count) VALUES
('WASTE_CATALOG', 1, NOW(), '初始化危废名录50条', 50, NULL),
('RECEIVER_UNIT', 1, NOW(), '初始化接收单位', 0, NULL),
('VEHICLE', 1, NOW(), '初始化车辆信息', 0, NULL),
('CONTAINER', 1, NOW(), '初始化容器信息5条', 5, 1),
('INVENTORY', 1, NOW(), '初始化库存', 0, 1);
