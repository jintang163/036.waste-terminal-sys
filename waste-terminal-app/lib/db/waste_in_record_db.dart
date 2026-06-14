import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class WasteInRecordDb {
  static final WasteInRecordDb _instance = WasteInRecordDb._internal();
  factory WasteInRecordDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  WasteInRecordDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableWasteInRecord, record);
      _logger.d('插入入库记录成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入入库记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'in_time DESC',
      );
    } catch (e) {
      _logger.e('查询入库记录列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
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
        where += ' AND (record_no LIKE ? OR waste_code LIKE ? OR waste_name LIKE ?)';
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

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND in_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND in_time <= ?';
        whereArgs.add(endTime);
      }

      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'in_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询入库记录失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (record_no LIKE ? OR waste_code LIKE ? OR waste_name LIKE ?)';
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

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND in_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND in_time <= ?';
        whereArgs.add(endTime);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWasteInRecord} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询入库记录数量失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsynced() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: 'sync_status = ? AND is_deleted = ?',
        whereArgs: [0, 0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询待同步入库记录失败: $e');
      rethrow;
    }
  }

  Future<int> queryUnsyncedCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWasteInRecord} WHERE sync_status = ? AND is_deleted = ?',
        [0, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询待同步入库记录数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteInRecord,
        where: 'offline_id = ? AND is_deleted = ?',
        whereArgs: [offlineId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据离线ID查询入库记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByRecordId(String recordId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteInRecord,
        where: 'record_id = ? AND is_deleted = ?',
        whereArgs: [recordId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据记录ID查询入库记录失败: $e');
      rethrow;
    }
  }

  Future<int> updateSyncStatus(String offlineId, int syncStatus, {String? syncTime, String? recordId}) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'sync_status': syncStatus,
        if (syncTime != null) 'sync_time': syncTime,
        if (recordId != null) 'record_id': recordId,
      };
      int count = await db.update(
        DatabaseTables.tableWasteInRecord,
        values,
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新入库记录同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新入库记录同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      String? offlineId = record['offline_id'];
      if (offlineId == null) {
        throw ArgumentError('offline_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableWasteInRecord,
        record,
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('更新入库记录成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新入库记录失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableWasteInRecord,
        {'is_deleted': 1},
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
      _logger.d('删除入库记录成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除入库记录失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableWasteInRecord);
      _logger.d('清空入库记录成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空入库记录失败: $e');
      rethrow;
    }
  }
}
