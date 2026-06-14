import 'package:logger/logger.dart';

import '../db/waste_catalog_db.dart';
import 'api_service.dart';

class WasteCatalogService {
  static final WasteCatalogService _instance = WasteCatalogService._internal();
  factory WasteCatalogService() => _instance;

  final WasteCatalogDb _wasteCatalogDb = WasteCatalogDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  WasteCatalogService._internal();

  Future<List<Map<String, dynamic>>> getCatalogList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCategory,
    String? wasteType,
    bool forceRefresh = false,
  }) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();

      if (forceRefresh && hasNetwork) {
        await _syncCatalogFromNetwork();
      }

      if (!hasNetwork) {
        _logger.d('无网络，从本地获取危废名录');
      }

      return await _wasteCatalogDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCategory: wasteCategory,
        wasteType: wasteType,
      );
    } catch (e) {
      _logger.e('获取危废名录失败: $e');
      return await _wasteCatalogDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCategory: wasteCategory,
        wasteType: wasteType,
      );
    }
  }

  Future<int> getCatalogCount({
    String? keyword,
    String? wasteCategory,
    String? wasteType,
  }) async {
    try {
      return await _wasteCatalogDb.queryCount(
        keyword: keyword,
        wasteCategory: wasteCategory,
        wasteType: wasteType,
      );
    } catch (e) {
      _logger.e('获取危废名录数量失败: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCatalogs() async {
    try {
      return await _wasteCatalogDb.queryAll();
    } catch (e) {
      _logger.e('获取所有危废名录失败: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCatalogById(String catalogId) async {
    try {
      Map<String, dynamic>? catalog = await _wasteCatalogDb.queryByCatalogId(catalogId);
      if (catalog != null) {
        return catalog;
      }

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        final response = await _apiService.get('/waste-catalog/$catalogId');
        if (response.data['data'] != null) {
          Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data']);
          await _wasteCatalogDb.insert(data);
          return data;
        }
      }
      return null;
    } catch (e) {
      _logger.e('根据ID获取危废名录失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCatalogByWasteCode(String wasteCode) async {
    try {
      return await _wasteCatalogDb.queryByWasteCode(wasteCode);
    } catch (e) {
      _logger.e('根据废物代码获取危废名录失败: $e');
      return null;
    }
  }

  Future<void> syncCatalog() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过危废名录同步');
        return;
      }
      await _syncCatalogFromNetwork();
    } catch (e) {
      _logger.e('同步危废名录失败: $e');
      rethrow;
    }
  }

  Future<void> _syncCatalogFromNetwork() async {
    try {
      final response = await _apiService.get('/waste-catalog/list');
      List<dynamic> data = response.data['data'] ?? [];
      List<Map<String, dynamic>> catalogList =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      await _wasteCatalogDb.replaceAll(catalogList);
      _logger.i('危废名录同步完成，数量: ${catalogList.length}');
    } catch (e) {
      _logger.e('从网络同步危废名录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchCatalog(String keyword) async {
    try {
      return await _wasteCatalogDb.queryWithPagination(
        keyword: keyword,
        pageSize: 50,
      );
    } catch (e) {
      _logger.e('搜索危废名录失败: $e');
      return [];
    }
  }

  Future<List<String>> getWasteCategories() async {
    try {
      List<Map<String, dynamic>> all = await _wasteCatalogDb.queryAll();
      Set<String> categories = {};
      for (var item in all) {
        if (item['waste_category'] != null && item['waste_category'].toString().isNotEmpty) {
          categories.add(item['waste_category'].toString());
        }
      }
      return categories.toList();
    } catch (e) {
      _logger.e('获取废物类别失败: $e');
      return [];
    }
  }
}
