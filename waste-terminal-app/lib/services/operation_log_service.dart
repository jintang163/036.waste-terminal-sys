import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../utils/logger_util.dart';
import '../utils/sp_util.dart';
import '../utils/uuid_util.dart';

class OperationLog {
  final String id;
  final String level;
  final String category;
  final String? module;
  final String? action;
  final String message;
  final String? userId;
  final String? username;
  final String? deviceId;
  final Map<String, dynamic>? extra;
  final DateTime timestamp;
  final bool isOffline;
  final int syncStatus;
  final DateTime? syncTime;
  final String? syncFailReason;

  OperationLog({
    String? id,
    required this.level,
    required this.category,
    this.module,
    this.action,
    required this.message,
    this.userId,
    this.username,
    this.deviceId,
    this.extra,
    DateTime? timestamp,
    this.isOffline = false,
    this.syncStatus = 0,
    this.syncTime,
    this.syncFailReason,
  })  : id = id ?? UuidUtil.generate(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'logId': id,
      'level': level,
      'category': category,
      'module': module,
      'action': action,
      'message': message,
      'userId': userId,
      'username': username,
      'deviceId': deviceId,
      'extra': extra,
      'timestamp': timestamp.toIso8601String(),
      'isOffline': isOffline,
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'syncFailReason': syncFailReason,
    };
  }

  factory OperationLog.fromJson(Map<String, dynamic> json) {
    String? logId = json['logId'] as String?;
    logId ??= json['id'] as String?;
    return OperationLog(
      id: logId,
      level: json['level'] as String? ?? BusinessConstants.logLevelInfo,
      category: json['category'] as String? ?? BusinessConstants.logCategoryOperation,
      module: json['module'] as String?,
      action: json['action'] as String?,
      message: json['message'] as String? ?? '',
      userId: json['userId'] as String?,
      username: json['username'] as String?,
      deviceId: json['deviceId'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isOffline: json['isOffline'] as bool? ?? false,
      syncStatus: json['syncStatus'] as int? ?? 0,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      syncFailReason: json['syncFailReason'] as String?,
    );
  }

  String toLogLine() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}]');
    buffer.write('[$level]');
    buffer.write('[$category]');
    if (module != null) buffer.write('[$module]');
    if (action != null) buffer.write('[$action]');
    if (userId != null) buffer.write('[$userId]');
    buffer.write(' $message');
    if (extra != null && extra!.isNotEmpty) {
      buffer.write(' | extra: ${jsonEncode(extra)}');
    }
    return buffer.toString();
  }
}

class OperationLogService {
  static final OperationLogService _instance = OperationLogService._internal();
  factory OperationLogService() => _instance;

  final ApiService _apiService = ApiService();

  Directory? _logDirectory;
  File? _currentLogFile;
  Timer? _uploadTimer;
  bool _isUploading = false;
  final List<OperationLog> _pendingLogs = [];

  OperationLogService._internal();

  Future<void> init() async {
    await _initLogDirectory();
    await _rotateLogFileIfNeeded();
    _startAutoUpload();
    LoggerUtil.info('运维日志服务初始化完成');
  }

  Future<void> _initLogDirectory() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _logDirectory = Directory('${appDir.path}/operation_logs');
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }
      LoggerUtil.info('日志目录: ${_logDirectory!.path}');
    } catch (e) {
      LoggerUtil.error('初始化日志目录失败', e);
      try {
        final tempDir = await getTemporaryDirectory();
        _logDirectory = Directory('${tempDir.path}/operation_logs');
        if (!await _logDirectory!.exists()) {
          await _logDirectory!.create(recursive: true);
        }
      } catch (e2) {
        LoggerUtil.error('创建临时日志目录也失败', e2);
      }
    }
  }

  Future<String> _getLogFileName() async {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'operation_log_$dateStr.log';
  }

  Future<String> _getLogIndexFileName() async {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'operation_log_${dateStr}_index.json';
  }

  Future<void> _rotateLogFileIfNeeded() async {
    try {
      if (_logDirectory == null) return;

      final fileName = await _getLogFileName();
      final filePath = '${_logDirectory!.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size >= AppConfig.maxLogFileSize) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newPath = '${filePath}_$timestamp';
          await file.rename(newPath);
          LoggerUtil.info('日志文件已轮转: $filePath -> $newPath');
        }
      }

      _currentLogFile = file;
    } catch (e) {
      LoggerUtil.error('日志文件轮转失败', e);
    }
  }

  Future<void> _cleanOldLogs() async {
    try {
      if (_logDirectory == null) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: AppConfig.logRetentionDays));

      final entities = await _logDirectory!.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.changed.isBefore(cutoffDate)) {
            await entity.delete();
            LoggerUtil.info('已删除过期日志文件: ${entity.path}');
          }
        }
      }
    } catch (e) {
      LoggerUtil.warning('清理旧日志失败: $e');
    }
  }

  Future<OperationLog> log({
    required String message,
    String level = BusinessConstants.logLevelInfo,
    String category = BusinessConstants.logCategoryOperation,
    String? module,
    String? action,
    Map<String, dynamic>? extra,
    bool forceOffline = false,
  }) async {
    final userId = SpUtil.getUserId()?.toString();
    final username = SpUtil.getString(StorageConstants.loginUsername);
    final deviceId = SpUtil.getDeviceId();

    final isNetworkAvailable = await _apiService.isNetworkAvailable();
    final isOffline = forceOffline || !isNetworkAvailable;

    final log = OperationLog(
      level: level,
      category: category,
      module: module,
      action: action,
      message: message,
      userId: userId,
      username: username,
      deviceId: deviceId,
      extra: extra,
      isOffline: isOffline,
    );

    await _writeToLocalFile(log);

    _pendingLogs.add(log);

    if (isNetworkAvailable && !_isUploading) {
      unawaited(_uploadPendingLogs());
    }

    return log;
  }

  Future<OperationLog> logInfo(
    String message, {
    String category = BusinessConstants.logCategoryOperation,
    String? module,
    String? action,
    Map<String, dynamic>? extra,
  }) {
    return log(
      message: message,
      level: BusinessConstants.logLevelInfo,
      category: category,
      module: module,
      action: action,
      extra: extra,
    );
  }

  Future<OperationLog> logWarning(
    String message, {
    String category = BusinessConstants.logCategoryOperation,
    String? module,
    String? action,
    Map<String, dynamic>? extra,
  }) {
    return log(
      message: message,
      level: BusinessConstants.logLevelWarning,
      category: category,
      module: module,
      action: action,
      extra: extra,
    );
  }

  Future<OperationLog> logError(
    String message, {
    String category = BusinessConstants.logCategoryOperation,
    String? module,
    String? action,
    Map<String, dynamic>? extra,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final extraData = <String, dynamic>{};
    if (extra != null) extraData.addAll(extra);
    if (error != null) extraData['error'] = error.toString();
    if (stackTrace != null) extraData['stackTrace'] = stackTrace.toString();

    return log(
      message: message,
      level: BusinessConstants.logLevelError,
      category: category,
      module: module,
      action: action,
      extra: extraData.isNotEmpty ? extraData : null,
    );
  }

  Future<OperationLog> logDebug(
    String message, {
    String category = BusinessConstants.logCategorySystem,
    String? module,
    String? action,
    Map<String, dynamic>? extra,
  }) {
    if (!AppConfig.enableDebugLog) {
      return Future.value(OperationLog(
        level: BusinessConstants.logLevelDebug,
        category: category,
        module: module,
        action: action,
        message: message,
      ));
    }
    return log(
      message: message,
      level: BusinessConstants.logLevelDebug,
      category: category,
      module: module,
      action: action,
      extra: extra,
    );
  }

  Future<void> _writeToLocalFile(OperationLog log) async {
    try {
      await _rotateLogFileIfNeeded();
      if (_currentLogFile == null) return;

      final logLine = '${log.toLogLine()}\n';
      await _currentLogFile!.writeAsString(
        logLine,
        mode: FileMode.append,
        flush: true,
      );

      await _appendToIndex(log);
    } catch (e) {
      LoggerUtil.error('写入本地日志文件失败', e);
    }
  }

  Future<void> _appendToIndex(OperationLog log) async {
    try {
      if (_logDirectory == null) return;

      final indexFileName = await _getLogIndexFileName();
      final indexFile = File('${_logDirectory!.path}/$indexFileName');

      List<Map<String, dynamic>> indexList = [];
      if (await indexFile.exists()) {
        try {
          final content = await indexFile.readAsString();
          if (content.isNotEmpty) {
            final decoded = jsonDecode(content);
            if (decoded is List) {
              indexList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          }
        } catch (_) {}
      }

      indexList.add(log.toJson());
      await indexFile.writeAsString(jsonEncode(indexList));
    } catch (e) {
      LoggerUtil.warning('写入日志索引失败: $e');
    }
  }

  Future<List<OperationLog>> getUnsyncedLogs() async {
    try {
      if (_logDirectory == null) return [];

      final unsyncedLogs = <OperationLog>[];
      final entities = await _logDirectory!.list().toList();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('_index.json')) {
          try {
            final content = await entity.readAsString();
            if (content.isEmpty) continue;

            final decoded = jsonDecode(content);
            if (decoded is List) {
              for (final item in decoded) {
                final log = OperationLog.fromJson(Map<String, dynamic>.from(item as Map));
                if (log.syncStatus != 1) {
                  unsyncedLogs.add(log);
                }
              }
            }
          } catch (e) {
            LoggerUtil.warning('读取日志索引失败: ${entity.path}, $e');
          }
        }
      }

      unsyncedLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return unsyncedLogs;
    } catch (e) {
      LoggerUtil.error('获取未同步日志失败', e);
      return [];
    }
  }

  Future<void> _startAutoUpload() async {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(
      Duration(minutes: AppConfig.logUploadIntervalMinutes),
      (_) async {
        if (!_isUploading) {
          unawaited(_uploadPendingLogs());
        }
      },
    );
    LoggerUtil.info('日志自动上传已启动，间隔: ${AppConfig.logUploadIntervalMinutes}分钟');
  }

  Future<void> _uploadPendingLogs() async {
    if (_isUploading) return;

    try {
      final isOnline = await _apiService.isNetworkAvailable();
      if (!isOnline) {
        LoggerUtil.info('网络不可用，跳过日志上传');
        return;
      }

      _isUploading = true;

      final logsToUpload = <OperationLog>[];
      if (_pendingLogs.isNotEmpty) {
        logsToUpload.addAll(_pendingLogs);
        _pendingLogs.clear();
      }

      final unsyncedFromFile = await getUnsyncedLogs();
      for (final log in unsyncedFromFile) {
        if (!logsToUpload.any((l) => l.id == log.id)) {
          logsToUpload.add(log);
        }
      }

      if (logsToUpload.isEmpty) {
        LoggerUtil.debug('没有待上传的日志');
        return;
      }

      LoggerUtil.info('开始上传日志，共 ${logsToUpload.length} 条');

      final batchSize = AppConfig.syncBatchSize;
      for (int i = 0; i < logsToUpload.length; i += batchSize) {
        final batch = logsToUpload.sublist(
          i,
          (i + batchSize < logsToUpload.length) ? i + batchSize : logsToUpload.length,
        );

        try {
          await _uploadLogBatch(batch);
          await _markLogsAsSynced(batch);
          LoggerUtil.info('日志批量上传成功: ${batch.length}条');
        } catch (e) {
          LoggerUtil.error('日志批量上传失败: ${batch.length}条', e);
          for (final log in batch) {
            if (!_pendingLogs.any((l) => l.id == log.id)) {
              _pendingLogs.add(log);
            }
          }
          rethrow;
        }
      }

      await SpUtil.putInt(
        StorageConstants.lastLogUploadTime,
        DateTime.now().millisecondsSinceEpoch,
      );

      LoggerUtil.info('日志上传完成，共 ${logsToUpload.length} 条');
    } catch (e) {
      LoggerUtil.error('日志上传过程出错', e);
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _uploadLogBatch(List<OperationLog> logs) async {
    final payload = logs.map((log) => log.toJson()).toList();
    await _apiService.post(
      ApiConstants.logBatchUpload,
      data: {'logs': payload},
      checkNetwork: false,
    );
  }

  Future<void> _markLogsAsSynced(List<OperationLog> logs) async {
    try {
      if (_logDirectory == null) return;

      final updatedIds = logs.map((l) => l.id).toSet();
      final entities = await _logDirectory!.list().toList();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('_index.json')) {
          bool modified = false;
          List<Map<String, dynamic>> indexList = [];

          try {
            final content = await entity.readAsString();
            if (content.isNotEmpty) {
              final decoded = jsonDecode(content);
              if (decoded is List) {
                indexList = decoded.map((e) {
                  final map = Map<String, dynamic>.from(e as Map);
                  if (updatedIds.contains(map['id'])) {
                    map['syncStatus'] = 1;
                    map['syncTime'] = DateTime.now().toIso8601String();
                    modified = true;
                  }
                  return map;
                }).toList();
              }
            }
          } catch (_) {}

          if (modified) {
            await entity.writeAsString(jsonEncode(indexList));
          }
        }
      }
    } catch (e) {
      LoggerUtil.warning('标记日志已同步失败: $e');
    }
  }

  Future<void> forceUpload() async {
    await _uploadPendingLogs();
  }

  Future<List<OperationLog>> getLogsForDate(DateTime date) async {
    try {
      if (_logDirectory == null) return [];

      final dateStr = '${date.year.toString().padLeft(4, '0')}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';
      final indexFile = File('${_logDirectory!.path}/operation_log_${dateStr}_index.json');

      if (!await indexFile.exists()) return [];

      final content = await indexFile.readAsString();
      if (content.isEmpty) return [];

      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded
            .map((e) => OperationLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      return [];
    } catch (e) {
      LoggerUtil.error('获取日志列表失败', e);
      return [];
    }
  }

  Future<List<OperationLog>> getRecentLogs({int limit = 100}) async {
    final allLogs = <OperationLog>[];
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final logs = await getLogsForDate(date);
      allLogs.addAll(logs);
      if (allLogs.length >= limit) break;
    }

    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs.take(limit).toList();
  }

  Future<int> getUnsyncedCount() async {
    final logs = await getUnsyncedLogs();
    return logs.length + _pendingLogs.length;
  }

  Future<DateTime?> getLastUploadTime() async {
    final timestamp = SpUtil.getInt(StorageConstants.lastLogUploadTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<Map<String, int>> getLogStats() async {
    int total = 0;
    int unsynced = 0;
    int infoCount = 0;
    int warningCount = 0;
    int errorCount = 0;

    final allLogs = await getRecentLogs(limit: 10000);
    for (final log in allLogs) {
      total++;
      if (log.syncStatus != 1) unsynced++;
      switch (log.level) {
        case BusinessConstants.logLevelInfo:
          infoCount++;
          break;
        case BusinessConstants.logLevelWarning:
          warningCount++;
          break;
        case BusinessConstants.logLevelError:
          errorCount++;
          break;
      }
    }

    return {
      'total': total,
      'unsynced': unsynced,
      'info': infoCount,
      'warning': warningCount,
      'error': errorCount,
    };
  }

  void dispose() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }
}
