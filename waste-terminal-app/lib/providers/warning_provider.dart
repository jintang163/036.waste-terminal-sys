import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/warning_service.dart';

enum WarningState { idle, loading, success, error }

class WarningProvider extends ChangeNotifier {
  final WarningService _warningService = WarningService();
  final Logger _logger = Logger();

  List<Map<String, dynamic>> _warnings = [];
  WarningState _state = WarningState.idle;
  String? _errorMessage;

  int _currentPage = 1;
  int _pageSize = 20;
  bool _hasMore = true;
  int _totalCount = 0;
  int _unreadCount = 0;

  String? _keyword;
  String? _warningType;
  int? _warningLevel;
  int? _status;
  String? _wasteCode;
  String? _startTime;
  String? _endTime;

  Map<String, dynamic>? _statistics;

  List<Map<String, dynamic>> _unhandledList = [];
  int _unhandledCount = 0;

  List<Map<String, dynamic>> get warnings => _warnings;
  WarningState get state => _state;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  int get unreadCount => _unreadCount;
  Map<String, dynamic>? get statistics => _statistics;
  bool get isLoading => _state == WarningState.loading;
  List<Map<String, dynamic>> get unhandledList => _unhandledList;
  int get unhandledCount => _unhandledCount;

  Future<void> loadWarnings({bool refresh = false, bool forceRefresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _warnings = [];
    }

    if (!_hasMore && !refresh) {
      return;
    }

    _state = WarningState.loading;
    notifyListeners();

    try {
      List<Map<String, dynamic>> newWarnings = await _warningService.getWarningList(
        page: _currentPage,
        pageSize: _pageSize,
        keyword: _keyword,
        warningType: _warningType,
        warningLevel: _warningLevel,
        status: _status,
        wasteCode: _wasteCode,
        startTime: _startTime,
        endTime: _endTime,
        forceRefresh: forceRefresh,
      );

      if (refresh) {
        _warnings = newWarnings;
      } else {
        _warnings.addAll(newWarnings);
      }

      _totalCount = await _warningService.getWarningCount(
        keyword: _keyword,
        warningType: _warningType,
        warningLevel: _warningLevel,
        status: _status,
        wasteCode: _wasteCode,
        startTime: _startTime,
        endTime: _endTime,
      );

      _unreadCount = await _warningService.getUnreadCount();

      _hasMore = newWarnings.length >= _pageSize;
      if (_hasMore) {
        _currentPage++;
      }

      _state = WarningState.success;
      _errorMessage = null;
    } catch (e) {
      _state = WarningState.error;
      _errorMessage = e.toString();
      _logger.e('加载预警列表失败: $e');
    }

    notifyListeners();
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _warningService.getUnreadCount();
      notifyListeners();
    } catch (e) {
      _logger.e('加载未读预警数量失败: $e');
    }
  }

  Future<void> loadUnhandledList() async {
    try {
      _unhandledList = await _warningService.getWarningList(
        page: 1,
        pageSize: 20,
        status: 0,
        forceRefresh: false,
      );
      _unhandledCount = _unhandledList.length;
      notifyListeners();
    } catch (e) {
      _logger.e('加载未处理预警列表失败: $e');
    }
  }

  Future<void> loadStatistics() async {
    try {
      _statistics = await _warningService.getStatistics();
      notifyListeners();
    } catch (e) {
      _logger.e('加载预警统计失败: $e');
    }
  }

  Future<Map<String, dynamic>?> getWarningDetail(String warningId) async {
    try {
      return await _warningService.getWarningDetail(warningId);
    } catch (e) {
      _logger.e('获取预警详情失败: $e');
      return null;
    }
  }

  Future<bool> handleWarning(
    String warningId, {
    String? handler,
    String? handlerId,
    String? handleRemark,
  }) async {
    try {
      bool success = await _warningService.handleWarning(
        warningId,
        handler: handler,
        handlerId: handlerId,
        handleRemark: handleRemark,
      );
      if (success) {
        await loadWarnings(refresh: true);
        await loadUnreadCount();
        await loadStatistics();
      }
      return success;
    } catch (e) {
      _logger.e('处理预警失败: $e');
      return false;
    }
  }

  Future<bool> deleteWarning(String warningId) async {
    try {
      bool success = await _warningService.deleteWarning(warningId);
      if (success) {
        _warnings.removeWhere((w) => w['warning_id'] == warningId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.e('删除预警失败: $e');
      return false;
    }
  }

  void setSearchParams({
    String? keyword,
    String? warningType,
    int? warningLevel,
    int? status,
    String? wasteCode,
    String? startTime,
    String? endTime,
  }) {
    _keyword = keyword;
    _warningType = warningType;
    _warningLevel = warningLevel;
    _status = status;
    _wasteCode = wasteCode;
    _startTime = startTime;
    _endTime = endTime;
  }

  void clearSearch() {
    _keyword = null;
    _warningType = null;
    _warningLevel = null;
    _status = null;
    _wasteCode = null;
    _startTime = null;
    _endTime = null;
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    await loadWarnings(refresh: true, forceRefresh: forceRefresh);
  }

  Future<void> syncData() async {
    try {
      await _warningService.syncWarning();
      await loadWarnings(refresh: true);
      await loadUnreadCount();
      await loadStatistics();
    } catch (e) {
      _logger.e('同步预警数据失败: $e');
    }
  }

  void reset() {
    _warnings = [];
    _state = WarningState.idle;
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    _totalCount = 0;
    _unreadCount = 0;
    clearSearch();
  }
}
