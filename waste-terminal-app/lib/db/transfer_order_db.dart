import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class TransferOrderDb {
  static final TransferOrderDb _instance = TransferOrderDb._internal();
  factory TransferOrderDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  TransferOrderDb._internal();

  Future<int> insert(Map<String, dynamic> order) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableTransferOrder, order);
      _logger.d('插入转移联单成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入转移联单失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransferOrder,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询转移联单列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
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
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (order_no LIKE ? OR waste_code LIKE ? OR waste_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCode != null && wasteCode.isNotEmpty) {
        where += ' AND waste_code = ?';
        whereArgs.add(wasteCode);
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND start_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND end_time <= ?';
        whereArgs.add(endTime);
      }

      return await db.query(
        DatabaseTables.tableTransferOrder,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'create_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询转移联单失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? status,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (order_no LIKE ? OR waste_code LIKE ? OR waste_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCode != null && wasteCode.isNotEmpty) {
        where += ' AND waste_code = ?';
        whereArgs.add(wasteCode);
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND start_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND end_time <= ?';
        whereArgs.add(endTime);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableTransferOrder} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询转移联单数量失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsynced() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransferOrder,
        where: 'sync_status = ? AND is_deleted = ?',
        whereArgs: [0, 0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询待同步转移联单失败: $e');
      rethrow;
    }
  }

  Future<int> queryUnsyncedCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableTransferOrder} WHERE sync_status = ? AND is_deleted = ?',
        [0, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询待同步转移联单数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransferOrder,
        where: 'offline_id = ? AND is_deleted = ?',
        whereArgs: [offlineId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据离线ID查询转移联单失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByOrderId(String orderId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransferOrder,
        where: 'order_id = ? AND is_deleted = ?',
        whereArgs: [orderId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据联单ID查询转移联单失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByOrderNo(String orderNo) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransferOrder,
        where: 'order_no = ? AND is_deleted = ?',
        whereArgs: [orderNo, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据联单号查询转移联单失败: $e');
      rethrow;
    }
  }

  Future<int> updateStatus(String offlineId, int status) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableTransferOrder,
        {'status': status},
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新转移联单状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新转移联单状态失败: $e');
      rethrow;
    }
  }

  Future<int> updateSyncStatus(String offlineId, int syncStatus, {String? syncTime, String? orderId}) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'sync_status': syncStatus,
        if (syncTime != null) 'sync_time': syncTime,
        if (orderId != null) 'order_id': orderId,
      };
      int count = await db.update(
        DatabaseTables.tableTransferOrder,
        values,
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新转移联单同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新转移联单同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> order) async {
    try {
      final db = await _dbHelper.database;
      String? offlineId = order['offline_id'];
      if (offlineId == null) {
        throw ArgumentError('offline_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableTransferOrder,
        order,
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新转移联单成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新转移联单失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableTransferOrder,
        {'is_deleted': 1},
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('删除转移联单成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除转移联单失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableTransferOrder);
      _logger.d('清空转移联单成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空转移联单失败: $e');
      rethrow;
    }
  }
}
