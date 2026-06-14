import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/sync_service.dart';

enum SyncState { idle, syncing, success, failed }

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final Logger _logger = Logger();

  SyncState _syncState = SyncState.idle;
  double _progress = 0.0;
  String? _currentModule;
  DateTime? _lastSyncTime;
  int _unsyncedCount = 0;
  Map<String, int> _unsyncedByModule = {};

  bool _isInitialized = false;

  SyncState get syncState => _syncState;
  double get progress => _progress;
  String? get currentModule => _currentModule;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get unsyncedCount => _unsyncedCount;
  Map<String, int> get unsyncedByModule => _unsyncedByModule;
  bool get isSyncing => _syncState == SyncState.syncing;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    try {
      _syncService.init();

      _syncService.statusStream.listen((status) {
        switch (status) {
          case SyncStatus.idle:
            _syncState = SyncState.idle;
            break;
          case SyncStatus.syncing:
            _syncState = SyncState.syncing;
            break;
          case SyncStatus.success:
            _syncState = SyncState.success;
            _updateLastSyncTime();
            break;
          case SyncStatus.failed:
            _syncState = SyncState.failed;
            break;
        }
        notifyListeners();
      });

      _syncService.progressStream.listen((progress) {
        _progress = progress;
        notifyListeners();
      });

      _syncService.moduleStream.listen((module) {
        _currentModule = module;
        notifyListeners();
      });

      await loadUnsyncedCount();
      await loadLastSyncTime();

      _isInitialized = true;
      notifyListeners();

      _logger.i('SyncProvider初始化完成');
    } catch (e) {
      _logger.e('SyncProvider初始化失败: $e');
    }
  }

  Future<void> fullSync() async {
    if (_syncState == SyncState.syncing) {
      _logger.w('同步进行中，忽略重复请求');
      return;
    }

    try {
      _syncState = SyncState.syncing;
      _progress = 0.0;
      notifyListeners();

      await _syncService.fullSync();

      _syncState = SyncState.success;
      await loadUnsyncedCount();
      await loadLastSyncTime();

      _logger.i('全量同步完成');
    } catch (e) {
      _syncState = SyncState.failed;
      _logger.e('全量同步失败: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> syncAll() async {
    await fullSync();
  }

  Future<void> incrementalSync() async {
    if (_syncState == SyncState.syncing) {
      _logger.w('同步进行中，忽略重复请求');
      return;
    }

    try {
      _syncState = SyncState.syncing;
      _progress = 0.0;
      notifyListeners();

      await _syncService.incrementalSync();

      _syncState = SyncState.success;
      await loadUnsyncedCount();
      await loadLastSyncTime();

      _logger.i('增量同步完成');
    } catch (e) {
      _syncState = SyncState.failed;
      _logger.e('增量同步失败: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadUnsyncedCount() async {
    try {
      _unsyncedCount = await _syncService.getUnsyncedTotalCount();
      _unsyncedByModule = await _syncService.getUnsyncedCountByModule();
      notifyListeners();
    } catch (e) {
      _logger.e('加载待同步数量失败: $e');
    }
  }

  Future<void> loadLastSyncTime() async {
    try {
      _lastSyncTime = await _syncService.getLastSyncTime();
      notifyListeners();
    } catch (e) {
      _logger.e('加载最后同步时间失败: $e');
    }
  }

  void _updateLastSyncTime() {
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }

  void setAutoSyncEnabled(bool enabled) {
    _syncService.setAutoSyncEnabled(enabled);
    _logger.d('自动同步${enabled ? "已开启" : "已关闭"}');
  }

  String get progressText {
    return '${(_progress * 100).toStringAsFixed(0)}%';
  }

  String? get lastSyncTimeText {
    if (_lastSyncTime == null) {
      return null;
    }

    DateTime now = DateTime.now();
    Duration difference = now.difference(_lastSyncTime!);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${_lastSyncTime!.month}/${_lastSyncTime!.day} ${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}';
    }
  }

  void resetState() {
    _syncState = SyncState.idle;
    _progress = 0.0;
    _currentModule = null;
    notifyListeners();
  }
}
