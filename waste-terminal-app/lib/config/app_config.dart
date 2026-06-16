import 'package:flutter/material.dart';

/// 应用全局配置
class AppConfig {
  AppConfig._();

  /// 应用名称
  static const String appName = '危废智能终端系统';

  /// 应用描述
  static const String appDescription = '危废全流程数字化合规管理平台';

  /// 应用版本
  static const String appVersion = '1.0.0';

  /// 版本号（用于显示）
  static const String version = '1.0.0';

  /// 版权信息
  static const String copyright = '© 2026 危废智能终端系统 版权所有';

  /// 构建号
  static const int buildNumber = 1;

  /// 当前运行环境
  static const Environment environment = Environment.dev;

  /// 开发环境API地址
  static const String baseUrlDev = 'http://192.168.1.100:8080/api';

  /// 测试环境API地址
  static const String baseUrlTest = 'http://192.168.1.101:8080/api';

  /// 生产环境API地址
  static const String baseUrlProd = 'https://api.waste-terminal.com/api';

  /// 根据环境获取API基础地址
  static String get baseUrl {
    switch (environment) {
      case Environment.dev:
        return baseUrlDev;
      case Environment.test:
        return baseUrlTest;
      case Environment.prod:
        return baseUrlProd;
    }
  }

  /// 连接超时时间（毫秒）
  static const int connectTimeout = 30000;

  /// 接收超时时间（毫秒）
  static const int receiveTimeout = 30000;

  /// 发送超时时间（毫秒）
  static const int sendTimeout = 30000;

  /// 请求重试次数
  static const int maxRetryCount = 3;

  /// 重试间隔时间（毫秒）
  static const int retryInterval = 1000;

  /// 默认分页大小
  static const int defaultPageSize = 10;

  /// 最大分页大小
  static const int maxPageSize = 100;

  /// 列表缓存数量
  static const int listCacheSize = 100;

  /// SM4加密密钥
  static const String sm4Key = 'waste-terminal-sm4-key-2024';

  /// SM2公钥
  static const String sm2PublicKey = '';

  /// SM2私钥
  static const String sm2PrivateKey = '';

  /// 默认企业ID
  static const int defaultEnterpriseId = 1;

  /// 本地存储键名前缀
  static const String storageKeyPrefix = 'waste_terminal_';

  /// 数据库文件名
  static const String dbName = 'waste_terminal.db';

  /// 数据库版本号
  static const int dbVersion = 1;

  /// 最大缓存大小（字节）
  static const int maxCacheSize = 100 * 1024 * 1024;

  /// 最大图片缓存大小（字节）
  static const int maxImageCacheSize = 50 * 1024 * 1024;

  /// 同步最大重试次数
  static const int syncRetryCount = 3;

  /// 同步重试间隔（秒）
  static const Duration syncRetryInterval = Duration(seconds: 5);

  /// 同步批次大小
  static const int syncBatchSize = 50;

  /// 自动同步间隔（分钟）
  static const Duration autoSyncInterval = Duration(minutes: 15);

  /// 蓝牙扫描超时时间（秒）
  static const int bluetoothScanTimeout = 10;

  /// 蓝牙连接超时时间（秒）
  static const int bluetoothConnectTimeout = 15;

  /// 地磅读取间隔（毫秒）
  static const int scaleReadInterval = 200;

  /// 地磅稳定判定次数
  static const int scaleStableCount = 3;

  /// 地磅稳定判定阈值（kg）
  static const double scaleStableThreshold = 0.01;

  /// 地磅重量单位
  static const String scaleWeightUnit = 'kg';

  /// 标签打印宽度（毫米）
  static const int labelPrintWidth = 80;

  /// 二维码纠错等级
  static const int qrErrorCorrectLevel = 2;

  /// 图片压缩质量
  static const int imageCompressQuality = 80;

  /// 图片最大宽度（像素）
  static const int imageMaxWidth = 1280;

  /// 图片最大高度（像素）
  static const int imageMaxHeight = 1280;

  /// 文件上传分片大小（字节）
  static const int uploadChunkSize = 5 * 1024 * 1024;

  /// 最大并发上传数
  static const int maxConcurrentUploads = 3;

  /// 条码最小长度
  static const int barcodeMinLength = 4;

  /// 条码最大长度
  static const int barcodeMaxLength = 32;

  /// 重量小数位数
  static const int weightDecimalPlaces = 3;

  /// 库存超期预警天数
  static const int inventoryOverdueDays = 30;

  /// 库存不足预警阈值（kg）
  static const double inventoryLowThreshold = 10.0;

  /// 日志最大保留天数
  static const int logRetentionDays = 30;

  /// 是否启用调试日志
  static const bool enableDebugLog = true;

  /// 是否启用离线模式
  static const bool enableOfflineMode = true;

  /// 是否启用数据加密
  static const bool enableDataEncryption = false;

  // ==================== 高德地图配置 ====================
  /// 高德地图 Android Key
  static const String amapAndroidKey = 'your_amap_android_key_here';

  /// 高德地图 iOS Key
  static const String amapIosKey = 'your_amap_ios_key_here';

  /// 应用主题色
  static const Color primaryColor = Color(0xFF1976D2);

  /// 主题色（浅）
  static const Color primaryLight = Color(0xFF42A5F5);

  /// 主题色（深）
  static const Color primaryDark = Color(0xFF0D47A1);

  /// 成功颜色
  static const Color successColor = Color(0xFF4CAF50);

  /// 警告颜色
  static const Color warningColor = Color(0xFFFFC107);

  /// 危险颜色
  static const Color dangerColor = Color(0xFFF44336);

  /// 信息颜色
  static const Color infoColor = Color(0xFF2196F3);

  /// 获取当前环境名称
  static String get environmentName {
    switch (environment) {
      case Environment.dev:
        return '开发环境';
      case Environment.test:
        return '测试环境';
      case Environment.prod:
        return '生产环境';
    }
  }

  /// 是否为开发环境
  static bool get isDev => environment == Environment.dev;

  /// 是否为生产环境
  static bool get isProd => environment == Environment.prod;
}

/// 运行环境枚举
enum Environment {
  /// 开发环境
  dev,

  /// 测试环境
  test,

  /// 生产环境
  prod,
}
