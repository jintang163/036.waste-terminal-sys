import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class InventoryCheckDb {
  static final InventoryCheckDb _instance = InventoryCheckDb._internal();
  factory InventoryCheckDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  InventoryCheckDb._internal();

  Future<int> insertCheck(Map<String, dynamic> check) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableInventoryCheck, check);
      _logger.d('创建盘点单成功: $id');
      return id;
    } catch (e) {
      _logger.e('创建盘点单失败: $e');
      rethrow;
    }
  }

  Future<int> insertDetail(Map<String, dynamic> detail) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableInventoryCheckDetail, detail);
      _logger.d('添加盘点明细成功: $id');
      return id;
    } catch (e) {
      _logger.e('添加盘点明细失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsertDetails(List<Map<String, dynamic>> detailList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var detail in detailList) {
        batch.insert(DatabaseTables.tableInventoryCheckDetail, detail);
      }
      await batch.commit(noResult: true);
      _logger.d('批量添加盘点明细成功，数量: ${detailList.length}');
    } catch (e) {
      _logger.e('批量添加盘点明细失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAllChecks() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableInventoryCheck,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'check_time DESC',
      );
    } catch (e) {
      _logger.e('查询盘点列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryChecksWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    int? status,
    int? syncStatus,
    String? checkType,
    String? warehouseId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (check_no LIKE ? OR checker LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (checkType != null && checkType.isNotEmpty) {
        where += ' AND check_type = ?';
        whereArgs.add(checkType);
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        where += ' AND warehouse_id = ?';
        whereArgs.add(warehouseId);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND check_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND check_time <= ?';
        whereArgs.add(endTime);
      }

      return await db.query(
        DatabaseTables.tableInventoryCheck,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'check_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询盘点列表失败: $e');
      rethrow;
    }
  }

  Future<int> queryChecksCount({
    String? keyword,
    int? status,
    int? syncStatus,
    String? checkType,
    String? warehouseId,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (check_no LIKE ? OR checker LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (checkType != null && checkType.isNotEmpty) {
        where += ' AND check_type = ?';
        whereArgs.add(checkType);
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        where += ' AND warehouse_id = ?';
        whereArgs.add(warehouseId);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND check_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND check_time <= ?';
        whereArgs.add(endTime);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableInventoryCheck} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询盘点数量失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsyncedChecks() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableInventoryCheck,
        where: 'sync_status = ? AND is_deleted = ?',
        whereArgs: [0, 0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询待同步盘点失败: $e');
      rethrow;
    }
  }

  Future<int> queryUnsyncedChecksCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableInventoryCheck} WHERE sync_status = ? AND is_deleted = ?',
        [0, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询待同步盘点数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryCheckByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableInventoryCheck,
        where: 'offline_id = ? AND is_deleted = ?',
        whereArgs: [offlineId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据离线ID查询盘点单失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryCheckByCheckId(String checkId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableInventoryCheck,
        where: 'check_id = ? AND is_deleted = ?',
        whereArgs: [checkId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据盘点ID查询盘点单失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryDetailsByCheckOfflineId(String checkOfflineId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableInventoryCheckDetail,
        where: 'check_offline_id = ? AND is_deleted = ?',
        whereArgs: [checkOfflineId, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询盘点明细失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryDetailsByCheckId(String checkId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableInventoryCheckDetail,
        where: 'check_id = ? AND is_deleted = ?',
        whereArgs: [checkId, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据盘点ID查询明细失败: $e');
      rethrow;
    }
  }

  Future<int> updateCheck(Map<String, dynamic> check) async {
    try {
      final db = await _dbHelper.database;
      String? offlineId = check['offline_id'];
      if (offlineId == null) {
        throw ArgumentError('offline_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableInventoryCheck,
        check,
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新盘点单成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新盘点单失败: $e');
      rethrow;
    }
  }

  Future<int> updateCheckSyncStatus(String offlineId, int syncStatus, {String? syncTime, String? checkId}) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'sync_status': syncStatus,
        if (syncTime != null) 'sync_time': syncTime,
        if (checkId != null) 'check_id': checkId,
      };
      int count = await db.update(
        DatabaseTables.tableInventoryCheck,
        values,
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新盘点同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新盘点同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> updateDetail(Map<String, dynamic> detail) async {
    try {
      final db = await _dbHelper.database;
      String? detailId = detail['detail_id'];
      if (detailId == null) {
        throw ArgumentError('detail_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableInventoryCheckDetail,
        detail,
        where: 'detail_id = ?',
        whereArgs: [detailId],
      );
      _logger.d('更新盘点明细成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新盘点明细失败: $e');
      rethrow;
    }
  }

  Future<int> deleteCheckByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableInventoryCheck,
        {'is_deleted': 1},
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      await db.update(
        DatabaseTables.tableInventoryCheckDetail,
        {'is_deleted': 1},
        where: 'check_offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('删除盘点单成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除盘点单失败: $e');
      rethrow;
    }
  }

  Future<int> deleteDetailByDetailId(String detailId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableInventoryCheckDetail,
        {'is_deleted': 1},
        where: 'detail_id = ?',
        whereArgs: [detailId],
      );
      _logger.d('删除盘点明细成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除盘点明细失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAllChecks() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableInventoryCheck);
      await db.delete(DatabaseTables.tableInventoryCheckDetail);
      _logger.d('清空盘点成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空盘点失败: $e');
      rethrow;
    }
  }
}
