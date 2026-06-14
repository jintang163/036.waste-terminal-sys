import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/inventory_service.dart';

enum InventoryState { idle, loading, success, error }

class InventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService = InventoryService();
  final Logger _logger = Logger();

  List<Map<String, dynamic>> _items = [];
  InventoryState _state = InventoryState.idle;
  String? _errorMessage;

  int _currentPage = 1;
  int _pageSize = 20;
  bool _hasMore = true;
  int _totalCount = 0;

  String? _keyword;
  String? _wasteCode;
  String? _wasteCategory;
  String? _warehouseId;

  Map<String, dynamic>? _statistics;

  double? _totalWeight;
  int? _containerCount;
  int _nearExpiryCount = 0;
  int _overdueCount = 0;
  List<Map<String, dynamic>> _recentList = [];

  List<Map<String, dynamic>> get items => _items;
  InventoryState get state => _state;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  Map<String, dynamic>? get statistics => _statistics;
  bool get isLoading => _state == InventoryState.loading;
  double? get totalWeight => _totalWeight;
  int? get containerCount => _containerCount;
  int get nearExpiryCount => _nearExpiryCount;
  int get overdueCount => _overdueCount;
  List<Map<String, dynamic>> get recentList => _recentList;

  Future<void> loadItems({bool refresh = false, bool forceRefresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _items = [];
    }

    if (!_hasMore && !refresh) {
      return;
    }

    _state = InventoryState.loading;
    notifyListeners();

    try {
      List<Map<String, dynamic>> newItems = await _inventoryService.getInventoryList(
        page: _currentPage,
        pageSize: _pageSize,
        keyword: _keyword,
        wasteCode: _wasteCode,
        wasteCategory: _wasteCategory,
        warehouseId: _warehouseId,
        forceRefresh: forceRefresh,
      );

      if (refresh) {
        _items = newItems;
      } else {
        _items.addAll(newItems);
      }

      _totalCount = await _inventoryService.getInventoryCount(
        keyword: _keyword,
        wasteCode: _wasteCode,
        wasteCategory: _wasteCategory,
        warehouseId: _warehouseId,
      );

      _hasMore = newItems.length >= _pageSize;
      if (_hasMore) {
        _currentPage++;
      }

      _state = InventoryState.success;
      _errorMessage = null;
    } catch (e) {
      _state = InventoryState.error;
      _errorMessage = e.toString();
      _logger.e('加载库存列表失败: $e');
    }

    notifyListeners();
  }

  Future<void> loadStatistics() async {
    try {
      _statistics = await _inventoryService.getStatistics();
      if (_statistics != null) {
        _totalWeight = (_statistics!['totalWeight'] as num?)?.toDouble();
        _containerCount = (_statistics!['containerCount'] as num?)?.toInt();
        _nearExpiryCount = (_statistics!['nearExpiryCount'] as num?)?.toInt() ?? 0;
        _overdueCount = (_statistics!['overdueCount'] as num?)?.toInt() ?? 0;
      }
      await _loadRecentList();
      notifyListeners();
    } catch (e) {
      _logger.e('加载库存统计失败: $e');
    }
  }

  Future<void> _loadRecentList() async {
    try {
      _recentList = await _inventoryService.getInventoryList(
        page: 1,
        pageSize: 5,
        forceRefresh: false,
      );
    } catch (e) {
      _logger.e('加载最近库存失败: $e');
    }
  }

  Future<Map<String, dynamic>?> getItemById(String inventoryId) async {
    try {
      return await _inventoryService.getInventoryById(inventoryId);
    } catch (e) {
      _logger.e('获取库存详情失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getItemsByWasteCode(String wasteCode) async {
    try {
      return await _inventoryService.getInventoryByWasteCode(wasteCode);
    } catch (e) {
      _logger.e('根据废物代码获取库存失败: $e');
      return [];
    }
  }

  void setSearchParams({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? warehouseId,
  }) {
    _keyword = keyword;
    _wasteCode = wasteCode;
    _wasteCategory = wasteCategory;
    _warehouseId = warehouseId;
  }

  void clearSearch() {
    _keyword = null;
    _wasteCode = null;
    _wasteCategory = null;
    _warehouseId = null;
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    await loadItems(refresh: true, forceRefresh: forceRefresh);
  }

  Future<void> syncData() async {
    try {
      await _inventoryService.syncInventory();
      await loadItems(refresh: true);
      await loadStatistics();
    } catch (e) {
      _logger.e('同步库存数据失败: $e');
    }
  }

  void reset() {
    _items = [];
    _state = InventoryState.idle;
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    _totalCount = 0;
    clearSearch();
  }
}
