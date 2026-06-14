import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../db/transfer_order_db.dart';
import 'api_service.dart';

class TransferOrderService {
  static final TransferOrderService _instance = TransferOrderService._internal();
  factory TransferOrderService() => _instance;

  final TransferOrderDb _transferOrderDb = TransferOrderDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  TransferOrderService._internal();

  Future<Map<String, dynamic>> createTransferOrder(Map<String, dynamic> order) async {
    try {
      String offlineId = _uuid.v4();
      order['offline_id'] = offlineId;
      order['status'] = order['status'] ?? 0;
      order['sync_status'] = 0;
      order['create_time'] = DateTime.now().toIso8601String();
      order['update_time'] = DateTime.now().toIso8601String();
      order['is_deleted'] = 0;

      int id = await _transferOrderDb.insert(order);
      _logger.i('创建转移联单成功，本地ID: $id, offlineId: $offlineId');

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        try {
          await _syncSingleOrder(order);
        } catch (e) {
          _logger.w('立即同步转移联单失败，将在下次同步时重试: $e');
        }
      }

      return {...order, 'id': id};
    } catch (e) {
      _logger.e('创建转移联单失败: $e');
      rethrow;
    }
  }

  Future<void> _syncSingleOrder(Map<String, dynamic> order) async {
    try {
      final response = await _apiService.post(
        '/transfer-order/add',
        data: order,
      );

      String? orderId = response.data['data']?['orderId'];
      await _transferOrderDb.updateSyncStatus(
        order['offline_id'],
        1,
        syncTime: DateTime.now().toIso8601String(),
        orderId: orderId,
      );
      _logger.d('转移联单同步成功: ${order['offline_id']}');
    } catch (e) {
      _logger.e('同步转移联单失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransferOrderList({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? status,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _transferOrderDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        status: status,
        syncStatus: syncStatus,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取转移联单列表失败: $e');
      return [];
    }
  }

  Future<int> getTransferOrderCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? status,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      return await _transferOrderDb.queryCount(
        keyword: keyword,
        wasteCode: wasteCode,
        wasteCategory: wasteCategory,
        status: status,
        syncStatus: syncStatus,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取转移联单数量失败: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getTransferOrderDetail(String offlineId) async {
    try {
      Map<String, dynamic>? order = await _transferOrderDb.queryByOfflineId(offlineId);
      if (order != null) {
        return order;
      }

      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (hasNetwork) {
        final response = await _apiService.get('/transfer-order/$offlineId');
        if (response.data['data'] != null) {
          Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data']);
          return data;
        }
      }
      return null;
    } catch (e) {
      _logger.e('获取转移联单详情失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTransferOrderByOrderNo(String orderNo) async {
    try {
      return await _transferOrderDb.queryByOrderNo(orderNo);
    } catch (e) {
      _logger.e('根据联单号获取转移联单失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    try {
      return await _transferOrderDb.queryUnsynced();
    } catch (e) {
      _logger.e('获取待同步转移联单失败: $e');
      return [];
    }
  }

  Future<int> getUnsyncedCount() async {
    try {
      return await _transferOrderDb.queryUnsyncedCount();
    } catch (e) {
      _logger.e('获取待同步转移联单数量失败: $e');
      return 0;
    }
  }

  Future<bool> updateOrderStatus(String offlineId, int status) async {
    try {
      int count = await _transferOrderDb.updateStatus(offlineId, status);
      return count > 0;
    } catch (e) {
      _logger.e('更新转移联单状态失败: $e');
      return false;
    }
  }

  Future<bool> updateTransferOrder(Map<String, dynamic> order) async {
    try {
      int count = await _transferOrderDb.update(order);
      if (count > 0) {
        bool hasNetwork = await _apiService.isNetworkAvailable();
        if (hasNetwork) {
          try {
            await _transferOrderDb.updateSyncStatus(
              order['offline_id'],
              0,
            );
          } catch (e) {
            _logger.w('更新同步状态失败: $e');
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('更新转移联单失败: $e');
      return false;
    }
  }

  Future<void> syncTransferOrders() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，跳过转移联单同步');
        return;
      }

      List<Map<String, dynamic>> unsynced = await _transferOrderDb.queryUnsynced();
      if (unsynced.isEmpty) {
        _logger.d('无待同步转移联单');
        return;
      }

      _logger.i('开始同步转移联单，数量: ${unsynced.length}');

      for (var order in unsynced) {
        try {
          await _syncSingleOrder(order);
        } catch (e) {
          _logger.w('同步转移联单失败: ${order['offline_id']}, $e');
        }
      }

      _logger.i('转移联单同步完成');
    } catch (e) {
      _logger.e('同步转移联单失败: $e');
    }
  }

  Future<bool> deleteTransferOrder(String offlineId) async {
    try {
      int count = await _transferOrderDb.deleteByOfflineId(offlineId);
      return count > 0;
    } catch (e) {
      _logger.e('删除转移联单失败: $e');
      return false;
    }
  }

  Future<bool> startTransport(int orderId) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('无网络连接，请联网后重试');
      }
      await _apiService.put('/transfer-order/start-transport/$orderId');
      _logger.i('开始运输成功, orderId: $orderId');
      return true;
    } catch (e) {
      _logger.e('开始运输失败: $e');
      rethrow;
    }
  }

  Future<bool> arrive(int orderId, {String? location}) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('无网络连接，请联网后重试');
      }
      final params = <String, dynamic>{};
      if (location != null && location.isNotEmpty) {
        params['location'] = location;
      }
      await _apiService.put(
        '/transfer-order/arrive/$orderId',
        queryParameters: params,
      );
      _logger.i('到达确认成功, orderId: $orderId');
      return true;
    } catch (e) {
      _logger.e('到达确认失败: $e');
      rethrow;
    }
  }

  Future<bool> signOrder(int orderId, {String? signPhoto}) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('无网络连接，请联网后重试');
      }
      final params = <String, dynamic>{};
      if (signPhoto != null && signPhoto.isNotEmpty) {
        params['signPhoto'] = signPhoto;
      }
      await _apiService.put(
        '/transfer-order/sign-order/$orderId',
        queryParameters: params,
      );
      _logger.i('签收成功, orderId: $orderId');
      return true;
    } catch (e) {
      _logger.e('签收失败: $e');
      rethrow;
    }
  }

  Future<bool> completeOrder(int orderId, {String? receiptPhoto}) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('无网络连接，请联网后重试');
      }
      final params = <String, dynamic>{};
      if (receiptPhoto != null && receiptPhoto.isNotEmpty) {
        params['receiptPhoto'] = receiptPhoto;
      }
      await _apiService.put(
        '/transfer-order/complete-order/$orderId',
        queryParameters: params,
      );
      _logger.i('完成联单成功, orderId: $orderId');
      return true;
    } catch (e) {
      _logger.e('完成联单失败: $e');
      rethrow;
    }
  }

  Future<bool> cancelOrder(int orderId, {String? reason}) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('无网络连接，请联网后重试');
      }
      final params = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        params['reason'] = reason;
      }
      await _apiService.put(
        '/transfer-order/cancel-order/$orderId',
        queryParameters: params,
      );
      _logger.i('取消联单成功, orderId: $orderId');
      return true;
    } catch (e) {
      _logger.e('取消联单失败: $e');
      rethrow;
    }
  }

  Future<List<dynamic>?> getTimeline(int orderId) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        return null;
      }
      final response = await _apiService.get('/transfer-order/timeline/$orderId');
      if (response.data['data'] != null) {
        return response.data['data'] as List<dynamic>;
      }
      return null;
    } catch (e) {
      _logger.e('获取联单轨迹失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDetailFull(int orderId) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        return null;
      }
      final response = await _apiService.get('/transfer-order/detail-full/$orderId');
      if (response.data['data'] != null) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      return null;
    } catch (e) {
      _logger.e('获取联单完整详情失败: $e');
      return null;
    }
  }

  Future<String?> getQrCode(int orderId) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        return null;
      }
      final response = await _apiService.get('/transfer-order/qrcode/$orderId');
      if (response.data['data'] != null) {
        return response.data['data'] as String;
      }
      return null;
    } catch (e) {
      _logger.e('获取联单二维码失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    String? startTime,
    String? endTime,
  }) async {
    try {
      List<Map<String, dynamic>> allOrders = await _transferOrderDb.queryAll();

      double totalWeight = 0;
      double totalQuantity = 0;
      int totalCount = 0;
      int pendingCount = 0;
      int completedCount = 0;

      for (var order in allOrders) {
        if (order['is_deleted'] == 0) {
          totalWeight += (order['weight'] ?? 0) as double;
          totalQuantity += (order['quantity'] ?? 0) as double;
          totalCount++;

          int status = order['status'] as int? ?? 0;
          if (status == 0) {
            pendingCount++;
          } else if (status == 2) {
            completedCount++;
          }
        }
      }

      return {
        'total_count': totalCount,
        'total_weight': totalWeight,
        'total_quantity': totalQuantity,
        'pending_count': pendingCount,
        'completed_count': completedCount,
      };
    } catch (e) {
      _logger.e('获取转移联单统计失败: $e');
      return {
        'total_count': 0,
        'total_weight': 0.0,
        'total_quantity': 0.0,
        'pending_count': 0,
        'completed_count': 0,
      };
    }
  }
}
