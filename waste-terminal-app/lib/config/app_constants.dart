/// 本地存储键名常量
class StorageConstants {
  StorageConstants._();

  /// 用户Token
  static const String token = 'token';

  /// 用户信息
  static const String userInfo = 'user_info';

  /// 企业ID
  static const String enterpriseId = 'enterprise_id';

  /// 企业信息
  static const String enterpriseInfo = 'enterprise_info';

  /// 主题模式
  static const String themeMode = 'theme_mode';

  /// 语言
  static const String language = 'language';

  /// 是否首次启动
  static const String isFirstLaunch = 'is_first_launch';

  /// 最后同步时间
  static const String lastSyncTime = 'last_sync_time';

  /// 设备ID
  static const String deviceId = 'device_id';

  /// 登录用户名
  static const String loginUsername = 'login_username';

  /// 已连接的蓝牙打印机地址
  static const String connectedPrinterAddress = 'connected_printer_address';

  /// 已连接的蓝牙打印机名称
  static const String connectedPrinterName = 'connected_printer_name';

  /// 已连接的地磅设备地址
  static const String connectedScaleAddress = 'connected_scale_address';

  /// 已连接的地磅设备名称
  static const String connectedScaleName = 'connected_scale_name';

  /// 已连接的RFID读卡器地址
  static const String connectedRfidAddress = 'connected_rfid_address';

  /// 已连接的RFID读卡器名称
  static const String connectedRfidName = 'connected_rfid_name';

  /// 地磅连接方式（bluetooth/usb）
  static const String scaleConnectionType = 'scale_connection_type';

  /// 地磅波特率
  static const String scaleBaudRate = 'scale_baud_rate';

  /// 是否自动同步
  static const String autoSyncEnabled = 'auto_sync_enabled';

  /// 是否WiFi下自动同步
  static const String syncOnlyOnWifi = 'sync_only_on_wifi';

  /// 是否启用打印
  static const String printEnabled = 'print_enabled';

  /// 是否打印二维码
  static const String printQrCode = 'print_qr_code';

  /// 标签打印份数
  static const String labelPrintCopies = 'label_print_copies';

  /// 地磅校准参数
  static const String scaleCalibrationParams = 'scale_calibration_params';

  /// 地磅零点值
  static const String scaleZeroValue = 'scale_zero_value';

  /// 地磅去皮值
  static const String scaleTareValue = 'scale_tare_value';

  /// 地磅校准历史
  static const String scaleCalibrationHistory = 'scale_calibration_history';

  /// 最后心跳时间
  static const String lastHeartbeatTime = 'last_heartbeat_time';

  /// 最后日志上传时间
  static const String lastLogUploadTime = 'last_log_upload_time';

  /// 设备自检结果缓存
  static const String deviceSelfCheckResult = 'device_self_check_result';
}

/// 路由路径常量
class RouteConstants {
  RouteConstants._();

  static const String splash = '/';
  static const String login = '/login';
  static const String main = '/main';
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String wasteIn = '/waste_in';
  static const String wasteInDetail = '/waste_in_detail';
  static const String wasteOut = '/waste_out';
  static const String wasteOutDetail = '/waste_out_detail';
  static const String transferOrder = '/transfer_order';
  static const String transferOrderDetail = '/transfer_order_detail';
  static const String transferOrderCreate = '/transfer_order_create';
  static const String inventoryCheck = '/inventory_check';
  static const String inventoryCheckDetail = '/inventory_check_detail';
  static const String inventoryCheckCreate = '/inventory_check_create';
  static const String warning = '/warning';
  static const String warningDetail = '/warning_detail';
  static const String container = '/container';
  static const String containerDetail = '/container_detail';
  static const String wasteCatalog = '/waste_catalog';
  static const String wasteCatalogDetail = '/waste_catalog_detail';
  static const String scan = '/scan';
  static const String bluetoothDevice = '/bluetooth_device';
  static const String scaleConfig = '/scale_config';
  static const String scaleCalibration = '/scale_calibration';
  static const String deviceStatus = '/device_status';
  static const String mine = '/mine';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String sync = '/sync';
  static const String about = '/about';
  static const String photoPreview = '/photo_preview';
  static const String imageCrop = '/image_crop';
  static const String selectContainer = '/select_container';
  static const String selectWasteCatalog = '/select_waste_catalog';
  static const String selectEnterprise = '/select_enterprise';
}

/// 事件总线事件常量
class EventConstants {
  EventConstants._();

  /// 登录成功
  static const String loginSuccess = 'login_success';

  /// 退出登录
  static const String logout = 'logout';

  /// Token过期
  static const String tokenExpired = 'token_expired';

  /// 同步完成
  static const String syncComplete = 'sync_complete';

  /// 同步开始
  static const String syncStart = 'sync_start';

  /// 入库记录新增
  static const String wasteInAdded = 'waste_in_added';

  /// 入库记录更新
  static const String wasteInUpdated = 'waste_in_updated';

  /// 入库记录删除
  static const String wasteInDeleted = 'waste_in_deleted';

  /// 出库记录新增
  static const String wasteOutAdded = 'waste_out_added';

  /// 出库记录更新
  static const String wasteOutUpdated = 'waste_out_updated';

  /// 出库记录删除
  static const String wasteOutDeleted = 'waste_out_deleted';

  /// 库存更新
  static const String inventoryUpdated = 'inventory_updated';

  /// 预警更新
  static const String warningUpdated = 'warning_updated';

  /// 网络状态变化
  static const String networkChanged = 'network_changed';

  /// 主题变化
  static const String themeChanged = 'theme_changed';

  /// 语言变化
  static const String languageChanged = 'language_changed';

  /// 蓝牙设备连接状态变化
  static const String bluetoothConnected = 'bluetooth_connected';

  /// 蓝牙设备断开
  static const String bluetoothDisconnected = 'bluetooth_disconnected';

  /// 地磅重量变化
  static const String scaleWeightChanged = 'scale_weight_changed';

  /// 地磅连接状态变化
  static const String scaleConnected = 'scale_connected';

  /// 地磅断开
  static const String scaleDisconnected = 'scale_disconnected';

  /// 容器更新
  static const String containerUpdated = 'container_updated';

  /// 危废名录更新
  static const String wasteCatalogUpdated = 'waste_catalog_updated';
}

/// 状态常量
class StatusConstants {
  StatusConstants._();

  /// 正常状态
  static const int statusNormal = 0;

  /// 禁用状态
  static const int statusDisabled = 1;

  /// 删除状态
  static const int statusDeleted = 1;

  /// 同步状态：未同步
  static const int syncStatusNotSynced = 0;

  /// 同步状态：同步成功
  static const int syncStatusSuccess = 1;

  /// 同步状态：同步失败
  static const int syncStatusFailed = 2;

  /// 同步状态：同步中
  static const int syncStatusSyncing = 3;

  /// 处理状态：未处理
  static const int handleStatusUnhandled = 0;

  /// 处理状态：处理中
  static const int handleStatusProcessing = 1;

  /// 处理状态：已处理
  static const int handleStatusHandled = 2;

  /// 预警级别：低
  static const int warningLevelLow = 1;

  /// 预警级别：中
  static const int warningLevelMedium = 2;

  /// 预警级别：高
  static const int warningLevelHigh = 3;

  /// 审核状态：待审核
  static const int auditStatusPending = 0;

  /// 审核状态：已通过
  static const int auditStatusApproved = 1;

  /// 审核状态：已驳回
  static const int auditStatusRejected = 2;

  /// 签收状态：未签收
  static const int signStatusUnsigned = 0;

  /// 签收状态：已签收
  static const int signStatusSigned = 1;

  /// 盘点状态：进行中
  static const int checkStatusProcessing = 0;

  /// 盘点状态：已完成
  static const int checkStatusCompleted = 1;

  /// 盘点状态：已取消
  static const int checkStatusCancelled = 2;

  /// 联单状态：草稿
  static const int orderStatusDraft = 0;

  /// 联单状态：待运输
  static const int orderStatusPending = 1;

  /// 联单状态：运输中
  static const int orderStatusTransporting = 2;

  /// 联单状态：已完成
  static const int orderStatusCompleted = 3;

  /// 联单状态：已取消
  static const int orderStatusCancelled = 4;

  /// 容器状态：空闲
  static const int containerStatusEmpty = 0;

  /// 容器状态：使用中
  static const int containerStatusInUse = 1;

  /// 容器状态：已满
  static const int containerStatusFull = 2;

  /// 容器状态：维修中
  static const int containerStatusRepair = 3;

  /// 容器状态：已报废
  static const int containerStatusScrap = 4;
}

/// 业务常量
class BusinessConstants {
  BusinessConstants._();

  /// 重量来源：手动录入
  static const String weightSourceManual = 'manual';

  /// 重量来源：地磅
  static const String weightSourceScale = 'scale';

  /// 盘点类型：日常盘点
  static const String checkTypeDaily = 'daily';

  /// 盘点类型：周盘点
  static const String checkTypeWeekly = 'weekly';

  /// 盘点类型：月盘点
  static const String checkTypeMonthly = 'monthly';

  /// 盘点类型：年盘点
  static const String checkTypeYearly = 'yearly';

  /// 盘点类型：临时盘点
  static const String checkTypeTemporary = 'temporary';

  /// 差异类型：正常
  static const String diffTypeNormal = 'normal';

  /// 差异类型：盘盈
  static const String diffTypeSurplus = 'surplus';

  /// 差异类型：盘亏
  static const String diffTypeLoss = 'loss';

  /// 同步方向：上传
  static const String syncDirectionUp = 'up';

  /// 同步方向：下载
  static const String syncDirectionDown = 'down';

  /// 存储类型：本地存储
  static const String storageTypeLocal = 'local';

  /// 存储类型：MinIO
  static const String storageTypeMinio = 'minio';

  /// 存储类型：阿里云OSS
  static const String storageTypeOss = 'oss';

  /// 预警类型：库存超期
  static const String warningTypeOverdue = 'overdue';

  /// 预警类型：库存不足
  static const String warningTypeLowStock = 'low_stock';

  /// 预警类型：库存超量
  static const String warningTypeOverStock = 'over_stock';

  /// 预警类型：容器异常
  static const String warningTypeContainer = 'container';

  /// 预警类型：设备异常
  static const String warningTypeDevice = 'device';

  /// 预警类型：系统异常
  static const String warningTypeSystem = 'system';

  /// 连接方式：蓝牙
  static const String connectionTypeBluetooth = 'bluetooth';

  /// 连接方式：USB
  static const String connectionTypeUsb = 'usb';

  /// 连接方式：WiFi
  static const String connectionTypeWifi = 'wifi';

  /// 文件业务类型：入库照片
  static const String bizTypeWasteInPhoto = 'waste_in_photo';

  /// 文件业务类型：出库照片
  static const String bizTypeWasteOutPhoto = 'waste_out_photo';

  /// 文件业务类型：签收照片
  static const String bizTypeSignPhoto = 'sign_photo';

  /// 文件业务类型：回执照片
  static const String bizTypeReceiptPhoto = 'receipt_photo';

  /// 文件业务类型：盘点照片
  static const String bizTypeCheckPhoto = 'check_photo';

  /// 文件业务类型：企业证照
  static const String bizTypeEnterpriseLicense = 'enterprise_license';

  /// 网络类型：WiFi
  static const String networkTypeWifi = 'wifi';

  /// 网络类型：移动网络
  static const String networkTypeMobile = 'mobile';

  /// 网络类型：无网络
  static const String networkTypeNone = 'none';

  static const String bizTypeCameraSnapshot = 'camera_snapshot';
  static const String bizTypeVideoClip = 'video_clip';
  static const String bizTypeLocalRecord = 'local_record';

  static const String cameraBrandHikvision = 'hikvision';
  static const String cameraBrandDahua = 'dahua';
  static const String cameraBrandUniview = 'uniview';

  static const String cameraTypeFixed = 'fixed';
  static const String cameraTypePtz = 'ptz';
  static const String cameraTypeDome = 'dome';

  static const String aiEventCategorySafetyViolation = 'safety_violation';
  static const String aiEventCategoryEquipmentWarning = 'equipment_warning';
  static const String aiEventCategoryBehaviorAbnormal = 'behavior_abnormal';

  static const String aiEventTypeNoGoggles = 'no_goggles';
  static const String aiEventTypeNoMask = 'no_mask';
  static const String aiEventTypeNoHelmet = 'no_helmet';
  static const String aiEventTypeForkliftSpeeding = 'forklift_speeding';
  static const String aiEventTypeSmoking = 'smoking';
  static const String aiEventTypeFallDetection = 'fall_detection';
  static const String aiEventTypeUnauthorizedEntry = 'unauthorized_entry';

  static const String recordTriggerWasteIn = 'waste_in';
  static const String recordTriggerWasteOut = 'waste_out';
  static const String recordTriggerAiEvent = 'ai_event';
  static const String recordTriggerManual = 'manual';

  static const String deviceStatusOnline = 'online';
  static const String deviceStatusOffline = 'offline';
  static const String deviceStatusAbnormal = 'abnormal';

  static const String logLevelInfo = 'info';
  static const String logLevelWarning = 'warning';
  static const String logLevelError = 'error';
  static const String logLevelDebug = 'debug';

  static const String logCategoryOperation = 'operation';
  static const String logCategoryDevice = 'device';
  static const String logCategorySystem = 'system';
  static const String logCategorySync = 'sync';
}

/// 正则表达式常量
class RegexConstants {
  RegexConstants._();

  /// 手机号正则
  static const String phone = r'^1[3-9]\d{9}$';

  /// 邮箱正则
  static const String email = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';

  /// 身份证号正则
  static const String idCard = r'^\d{17}[\dXx]$';

  /// 车牌号正则
  static const String vehicleNo = r'^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-Z][A-Z0-9]{4,5}[A-Z0-9挂学警港澳]$';

  /// 危废代码正则（HW开头+3位数字）
  static const String wasteCode = r'^HW\d{3}$';

  /// 容器编码正则
  static const String containerCode = r'^[A-Z0-9]{4,32}$';

  /// 重量正则（最多3位小数）
  static const String weight = r'^\d+(\.\d{1,3})?$';

  /// URL正则
  static const String url = r'^https?:\/\/[^\s]+$';

  /// 中文正则
  static const String chinese = r'^[\u4e00-\u9fa5]+$';

  /// 数字正则
  static const String number = r'^\d+$';

  /// 字母正则
  static const String letter = r'^[a-zA-Z]+$';

  /// 字母数字正则
  static const String letterNumber = r'^[a-zA-Z0-9]+$';

  /// 用户名正则（4-20位字母数字下划线）
  static const String username = r'^[a-zA-Z0-9_]{4,20}$';

  /// 密码正则（6-20位，包含字母和数字）
  static const String password = r'^(?=.*[a-zA-Z])(?=.*\d)[a-zA-Z0-9!@#$%^&*]{6,20}$';
}

/// 格式化模式常量
class FormatConstants {
  FormatConstants._();

  /// 日期格式（年月日）
  static const String date = 'yyyy-MM-dd';

  /// 时间格式（时分秒）
  static const String time = 'HH:mm:ss';

  /// 日期时间格式
  static const String dateTime = 'yyyy-MM-dd HH:mm:ss';

  /// 日期时间格式（无秒）
  static const String dateTimeMinute = 'yyyy-MM-dd HH:mm';

  /// 中文日期格式
  static const String dateCn = 'yyyy年MM月dd日';

  /// 中文日期时间格式
  static const String dateTimeCn = 'yyyy年MM月dd日 HH:mm:ss';

  /// 重量格式（3位小数）
  static const String weight = '0.000';

  /// 百分比格式
  static const String percent = '0.00%';

  /// 货币格式
  static const String currency = '¥0.00';
}

/// API接口路径常量
class ApiConstants {
  ApiConstants._();

  /// 认证相关
  static const String authLogin = '/auth/login';
  static const String authFaceLogin = '/auth/face-login';
  static const String authLogout = '/auth/logout';
  static const String authRefreshToken = '/auth/refresh';
  static const String authUserInfo = '/auth/userInfo';
  static const String authChangePassword = '/auth/changePassword';

  /// 用户相关
  static const String userList = '/user/list';
  static const String userDetail = '/user/detail';

  /// 企业相关
  static const String enterpriseInfo = '/enterprise/info';
  static const String enterpriseList = '/enterprise/list';

  /// 危废名录
  static const String wasteCatalogList = '/waste-catalog/list';
  static const String wasteCatalogDetail = '/waste-catalog/detail';
  static const String wasteCatalogPage = '/waste-catalog/page';
  static const String wasteCatalogSync = '/waste-catalog/sync';

  /// 容器管理
  static const String containerList = '/container/list';
  static const String containerDetail = '/container/detail';
  static const String containerPage = '/container/page';
  static const String containerAdd = '/container/add';
  static const String containerUpdate = '/container/update';
  static const String containerSync = '/container/sync';

  /// 库存管理
  static const String inventoryList = '/inventory/list';
  static const String inventoryDetail = '/inventory/detail';
  static const String inventoryPage = '/inventory/page';
  static const String inventoryStats = '/inventory/stats';
  static const String inventorySync = '/inventory/sync';
  static const String inventoryByContainer = '/inventory/by-container';

  /// 入库管理
  static const String wasteInAdd = '/waste-in/add';
  static const String wasteInList = '/waste-in/list';
  static const String wasteInDetail = '/waste-in/detail';
  static const String wasteInPage = '/waste-in/page';
  static const String wasteInUpdate = '/waste-in/update';
  static const String wasteInDelete = '/waste-in/delete';
  static const String wasteInBatchAdd = '/waste-in/batch-add';

  /// 出库管理
  static const String wasteOutAdd = '/waste-out/add';
  static const String wasteOutList = '/waste-out/list';
  static const String wasteOutDetail = '/waste-out/detail';
  static const String wasteOutPage = '/waste-out/page';
  static const String wasteOutUpdate = '/waste-out/update';
  static const String wasteOutDelete = '/waste-out/delete';
  static const String wasteOutCheckDoubleReview = '/waste-out/check-double-review';

  /// 出库复核管理
  static const String wasteOutReviewCreate = '/waste-out-review/create';
  static const String wasteOutReviewConfirm = '/waste-out-review/confirm';
  static const String wasteOutReviewGetByNo = '/waste-out-review/get-by-review-no';
  static const String wasteOutReviewGetByOutNo = '/waste-out-review/get-by-out-no';
  static const String wasteOutReviewList = '/waste-out-review/list';
  static const String wasteOutReviewPage = '/waste-out-review/page';
  static const String wasteOutReviewBatchSync = '/waste-out-review/batch-sync';
  static const String wasteOutReviewPendingSync = '/waste-out-review/pending-sync';

  /// 联单管理
  static const String transferOrderList = '/transfer-order/list';
  static const String transferOrderDetail = '/transfer-order/detail';
  static const String transferOrderPage = '/transfer-order/page';
  static const String transferOrderCreate = '/transfer-order/create';
  static const String transferOrderUpdate = '/transfer-order/update';
  static const String transferOrderSign = '/transfer-order/sign';
  static const String transferOrderComplete = '/transfer-order/complete';
  static const String transferOrderCancel = '/transfer-order/cancel';

  /// 盘点管理
  static const String inventoryCheckList = '/inventory-check/list';
  static const String inventoryCheckDetail = '/inventory-check/detail';
  static const String inventoryCheckPage = '/inventory-check/page';
  static const String inventoryCheckCreate = '/inventory-check/create';
  static const String inventoryCheckSubmit = '/inventory-check/submit';
  static const String inventoryCheckUpdate = '/inventory-check/update';

  /// 预警管理
  static const String warningList = '/warning/list';
  static const String warningDetail = '/warning/detail';
  static const String warningPage = '/warning/page';
  static const String warningHandle = '/warning/handle';
  static const String warningStats = '/warning/stats';
  static const String warningSync = '/warning/sync';

  /// 文件管理
  static const String fileUpload = '/file/upload';
  static const String fileBatchUpload = '/file/batch-upload';
  static const String fileDownload = '/file/download';
  static const String fileDelete = '/file/delete';
  static const String fileInfo = '/file/info';

  /// 数据同步
  static const String syncPull = '/sync/pull';
  static const String syncPush = '/sync/push';
  static const String syncStatus = '/sync/status';
  static const String syncPullWasteCatalog = '/sync/pull/waste-catalog';
  static const String syncPullContainer = '/sync/pull/container';
  static const String syncPullInventory = '/sync/pull/inventory';
  static const String syncPullWarning = '/sync/pull/warning';
  static const String syncPushWasteIn = '/sync/push/waste-in';
  static const String syncPushWasteOut = '/sync/push/waste-out';
  static const String syncPushInventoryCheck = '/sync/push/inventory-check';
  static const String syncPushTransferOrder = '/sync/push/transfer-order';

  /// 设备管理
  static const String deviceRegister = '/device/register';
  static const String deviceHeartbeat = '/device/heartbeat';
  static const String deviceUnbind = '/device/unbind';
  static const String deviceSelfCheck = '/device/self-check';
  static const String deviceStatusReport = '/device/status-report';

  /// 运维日志
  static const String logUpload = '/log/upload';
  static const String logBatchUpload = '/log/batch-upload';
  static const String logList = '/log/list';

  /// 统计报表
  static const String statsOverview = '/stats/overview';
  static const String statsWasteIn = '/stats/waste-in';
  static const String statsWasteOut = '/stats/waste-out';
  static const String statsInventory = '/stats/inventory';
  static const String statsWarning = '/stats/warning';

  /// 国家平台上报
  static const String platformReportDashboard = '/platform-report/dashboard';
  static const String platformReportStatistics = '/platform-report/statistics';
  static const String platformReportFailed = '/platform-report/failed';
  static const String platformReportRetryQueue = '/platform-report/retry-queue';
  static const String platformReportManualRetry = '/platform-report/manual-retry';
  static const String platformReportBatchRetry = '/platform-report/batch-manual-retry';
  static const String platformReportPage = '/platform-report/page';

  static const String cameraList = '/camera/list';
  static const String cameraPage = '/camera/page';
  static const String cameraDetail = '/camera/detail';
  static const String cameraPreviewUrl = '/camera/preview-url';
  static const String cameraSnapshotUrl = '/camera/snapshot-url';
  static const String cameraToggleAi = '/camera/ai';

  static const String videoPreview = '/video/preview';
  static const String videoSnapshot = '/video/snapshot';
  static const String videoStreamOpen = '/video/stream/open';
  static const String videoStreamClose = '/video/stream/close';
  static const String videoStreamStatus = '/video/stream/status';

  static const String aiCapturePage = '/ai-capture/page';
  static const String aiCaptureDetail = '/ai-capture/detail';
  static const String aiCaptureUnhandled = '/ai-capture/unhandled';
  static const String aiCaptureList = '/ai-capture/list';
  static const String aiCaptureHandle = '/ai-capture/handle';
  static const String aiCaptureIgnore = '/ai-capture/ignore';
  static const String aiCaptureStatistics = '/ai-capture/statistics';
  static const String aiCaptureCallback = '/ai-capture/callback';

  static const String localRecordPage = '/local-record/page';
  static const String localRecordDetail = '/local-record/detail';
  static const String localRecordTask = '/local-record/task';
  static const String localRecordUnsynced = '/local-record/unsynced';
  static const String localRecordList = '/local-record/list';
  static const String localRecordTrigger = '/local-record/trigger';
  static const String localRecordSyncStatus = '/local-record/sync-status';
  static const String localRecordBatchSyncStatus = '/local-record/batch-sync-status';
  static const String localRecordConfirmUpload = '/local-record/confirm-upload';

  static const String userFacePage = '/user-face/page';
  static const String userFaceDetail = '/user-face';
  static const String userFaceByUserId = '/user-face/user';
  static const String userFaceByUsername = '/user-face/username';
  static const String userFaceByFaceId = '/user-face/face';
  static const String userFaceList = '/user-face/list';
  static const String userFaceAdd = '/user-face';
  static const String userFaceUpdate = '/user-face';
  static const String userFaceDelete = '/user-face';
  static const String userFaceUpdateStatus = '/user-face/status';
  static const String userFaceSync = '/user-face/sync';

  static const String faceAuthPage = '/face-auth/page';
  static const String faceAuthDetail = '/face-auth';
  static const String faceAuthByAuthId = '/face-auth/auth';
  static const String faceAuthAdd = '/face-auth';
  static const String faceAuthBatchAdd = '/face-auth/batch';
  static const String faceAuthByBusiness = '/face-auth/business';
  static const String faceAuthByUser = '/face-auth/user';

  /// 运输车辆
  static const String transportVehicleList = '/transport-vehicle/list';
  static const String transportVehicleDetail = '/transport-vehicle/detail';
  static const String transportVehiclePage = '/transport-vehicle/page';
  static const String transportVehicleAdd = '/transport-vehicle/add';
  static const String transportVehicleUpdate = '/transport-vehicle/update';
  static const String transportVehicleSync = '/transport-vehicle/sync';

  /// 驾驶员
  static const String transportDriverList = '/transport-driver/list';
  static const String transportDriverDetail = '/transport-driver/detail';
  static const String transportDriverPage = '/transport-driver/page';
  static const String transportDriverAdd = '/transport-driver/add';
  static const String transportDriverUpdate = '/transport-driver/update';
  static const String transportDriverSync = '/transport-driver/sync';

  /// 运输轨迹
  static const String transportTrackList = '/transport-track/list';
  static const String transportTrackDetail = '/transport-track/detail';
  static const String transportTrackPage = '/transport-track/page';
  static const String transportTrackCreate = '/transport-track/create';
  static const String transportTrackEnd = '/transport-track/end';
  static const String transportTrackPoints = '/transport-track/points';
  static const String transportTrackReplay = '/transport-track/replay';
  static const String transportTrackUploadPoint = '/transport-track/upload-point';
  static const String transportTrackUploadPoints = '/transport-track/upload-points';

  static const String wasteAiRecognize = '/waste-ai/recognition/recognize';
  static const String wasteAiConfig = '/waste-ai/recognition/config';
}
