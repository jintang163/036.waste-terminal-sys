import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/waste_in_service.dart';

enum WasteInState { idle, loading, success, error }

class WasteInProvider extends ChangeNotifier {
  final WasteInService _wasteInService = WasteInService();
  final Logger _logger = Logger();

  List<Map<String, dynamic>> _records = [];
  WasteInState _state = WasteInState.idle;
  String? _errorMessage;

  int _currentPage = 1;
  int _pageSize = 20;
  bool _hasMore = true;
  int _totalCount = 0;

  String? _keyword;
  String? _wasteCode;
  String? _wasteCategory;
  int? _syncStatus;
  String? _startTime;
  String? _endTime;

  Map<String, dynamic>? _statistics;

  List<Map<String, dynamic>> get records => _records;
  WasteInState get state => _state;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  Map<String, dynamic>? get statistics => _statistics;
  bool get isLoading => _state == WasteInState.loading;

  Future<void> loadRecords({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _records = [];
    }

    if (!_hasMore && !refresh) {
      return;
    }

    _state = WasteInState.loading;
    notifyListeners();

    try {
      List<Map<String, dynamic>> newRecords = await _wasteInService.getWasteInList(
        page: _currentPage,
        pageSize: _pageSize,
        keyword: _keyword,
        wasteCode: _wasteCode,
        wasteCategory: _wasteCategory,
        syncStatus: _syncStatus,
        startTime: _startTime,
        endTime: _endTime,
      );

      if (refresh) {
        _records = newRecords;
      } else {
        _records.addAll(newRecords);
      }

      _totalCount = await _wasteInService.getWasteInCount(
        keyword: _keyword,
        wasteCode: _wasteCode,
        wasteCategory: _wasteCategory,
        syncStatus: _syncStatus,
        startTime: _startTime,
        endTime: _endTime,
      );

      _hasMore = newRecords.length >= _pageSize;
      if (_hasMore) {
        _currentPage++;
      }

      _state = WasteInState.success;
      _errorMessage = null;
    } catch (e) {
      _state = WasteInState.error;
      _errorMessage = e.toString();
      _logger.e('加载入库记录失败: $e');
    }

    notifyListeners();
  }

  Future<bool> addRecord(Map<String, dynamic> record) async {
    try {
      await _wasteInService.addWasteInRecord(record);
      await loadRecords(refresh: true);
      return true;
    } catch (e) {
      _logger.e('添加入库记录失败: $e');
      return false;
    }
  }

  Future<bool> updateRecord(Map<String, dynamic> record) async {
    try {
      bool success = await _wasteInService.updateWasteInRecord(record);
      if (success) {
        await loadRecords(refresh: true);
      }
      return success;
    } catch (e) {
      _logger.e('更新入库记录失败: $e');
      return false;
    }
  }

  Future<bool> deleteRecord(String offlineId) async {
    try {
      bool success = await _wasteInService.deleteWasteInRecord(offlineId);
      if (success) {
        _records.removeWhere((r) => r['offline_id'] == offlineId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.e('删除入库记录失败: $e');
      return false;
    }
  }

  Future<void> loadStatistics() async {
    try {
      _statistics = await _wasteInService.getStatistics(
        startTime: _startTime,
        endTime: _endTime,
      );
      notifyListeners();
    } catch (e) {
      _logger.e('加载入库统计失败: $e');
    }
  }

  void setSearchParams({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) {
    _keyword = keyword;
    _wasteCode = wasteCode;
    _wasteCategory = wasteCategory;
    _syncStatus = syncStatus;
    _startTime = startTime;
    _endTime = endTime;
  }

  void clearSearch() {
    _keyword = null;
    _wasteCode = null;
    _wasteCategory = null;
    _syncStatus = null;
    _startTime = null;
    _endTime = null;
  }

  Future<void> refresh() async {
    await loadRecords(refresh: true);
  }

  void reset() {
    _records = [];
    _state = WasteInState.idle;
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    _totalCount = 0;
    clearSearch();
  }
}
