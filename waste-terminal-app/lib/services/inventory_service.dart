import 'package:logger/logger.dart';

import '../db/waste_inventory_db.dart';
import 'api_service.dart';

class InventoryService {
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;

  final WasteInventoryDb _wasteInventoryDb = WasteInventoryDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  InventoryService._internal();

  Future<List<Map<String, dynamic>>> getInventoryList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? warehouseId,
    bool forceRefresh = false,
  }) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();

      if (forceRefresh && hasNetwork) {
        await _syncInventoryFromNetwork();
      }

      return await _wasteInventoryDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        warehouseId: warehouseId,
      );
    } catch (e) {
      _logger.e('获取库存列表失败: $e');
      return await _wasteInventoryDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        warehouseId: warehouseId,
      );
    }
  }

  Future<int> getInventoryCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? warehouseId,
  }) async {
    try {
      return await _wasteInventoryDb.queryCount(
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        warehouseId: warehouseId,
      );
    } catch (e) {
      _logger.e('获取库存数量失败: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getAllInventory() async {
    try {
      return await _wasteInventoryDb.queryAll();
    } catch (e) {
      _logger.e('获取所有库存失败: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getInventoryById(String inventoryId) async {
    try {
      return await _wasteInventoryDb.queryByInventoryId(inventoryId);
    } catch (e) {
      _logger.e('根据ID获取库存失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getInventoryByWasteCode(String wasteCode) async {
    try {
      return await _wasteInventoryDb.queryByWasteCode(wasteCode);
    } catch (e) {
      _logger.e('根据废物代码获取库存失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInventoryByContainerId(String containerId) async {
    try {
      return await _wasteInventoryDb.queryByContainerId(containerId);
    } catch (e) {
      _logger.e('根据容器ID获取库存失败: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      return await _wasteInventoryDb.getStatistics();
    } catch (e) {
      _logger.e('获取库存统计失败: $e');
      return {
        'total_count': 0,
        'total_quantity': 0.0,
        'total_weight': 0.0,
        'by_category': [],
      };
    }
  }

  Future<void> syncInventory() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过库存同步');
        return;
      }
      await _syncInventoryFromNetwork();
    } catch (e) {
      _logger.e('同步库存失败: $e');
      rethrow;
    }
  }

  Future<void> _syncInventoryFromNetwork() async {
    try {
      final response = await _apiService.get('/inventory/list');
      List<dynamic> data = response.data['data'] ?? [];
      List<Map<String, dynamic>> inventoryList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _wasteInventoryDb.replaceAll(inventoryList);
      _logger.i('库存数据同步完成，数量: ${inventoryList.length}');
    } catch (e) {
      _logger.e('从网络同步库存数据失败: $e');
      rethrow;
    }
  }

  Future<bool> updateInventory(Map<String, dynamic> inventory) async {
    try {
      int count = await _wasteInventoryDb.update(inventory);
      return count > 0;
    } catch (e) {
      _logger.e('更新库存失败: $e');
      return false;
    }
  }

  Future<bool> deleteInventory(String inventoryId) async {
    try {
      int count = await _wasteInventoryDb.deleteByInventoryId(inventoryId);
      return count > 0;
    } catch (e) {
      _logger.e('删除库存失败: $e');
      return false;
    }
  }

  Future<void> batchUpsert(List<Map<String, dynamic>> inventoryList) async {
    try {
      await _wasteInventoryDb.batchUpsert(inventoryList);
    } catch (e) {
      _logger.e('批量更新库存失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchInventory(String keyword) async {
    try {
      return await _wasteInventoryDb.queryWithPagination(
        keyword: keyword,
        pageSize: 50,
      );
    } catch (e) {
      _logger.e('搜索库存失败: $e');
      return [];
    }
  }

  Future<List<String>> getWasteCategories() async {
    try {
      List<Map<String, dynamic>> all = await _wasteInventoryDb.queryAll();
      Set<String> categories = {};
      for (var item in all) {
        if (item['waste_category'] != null && item['waste_category'].toString().isNotEmpty) {
          categories.add(item['waste_category'].toString());
        }
      }
      return categories.toList();
    } catch (e) {
      _logger.e('获取库存废物类别失败: $e');
      return [];
    }
  }
}
