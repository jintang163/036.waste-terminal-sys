import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class SyncLogDb {
  static final SyncLogDb _instance = SyncLogDb._internal();
  factory SyncLogDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  SyncLogDb._internal();

  Future<int> insert(Map<String, dynamic> log) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableSyncLog, log);
      _logger.d('插入同步日志成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入同步日志失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableSyncLog,
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询同步日志失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? syncType,
    String? syncModule,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = '1=1';
      List<dynamic> whereArgs = [];

      if (syncType != null && syncType.isNotEmpty) {
        where += ' AND sync_type = ?';
        whereArgs.add(syncType);
      }

      if (syncModule != null && syncModule.isNotEmpty) {
        where += ' AND sync_module = ?';
        whereArgs.add(syncModule);
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND create_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND create_time <= ?';
        whereArgs.add(endTime);
      }

      return await db.query(
        DatabaseTables.tableSyncLog,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'create_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询同步日志失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? syncType,
    String? syncModule,
    int? syncStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = '1=1';
      List<dynamic> whereArgs = [];

      if (syncType != null && syncType.isNotEmpty) {
        where += ' AND sync_type = ?';
        whereArgs.add(syncType);
      }

      if (syncModule != null && syncModule.isNotEmpty) {
        where += ' AND sync_module = ?';
        whereArgs.add(syncModule);
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND create_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND create_time <= ?';
        whereArgs.add(endTime);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableSyncLog} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询同步日志数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByLogId(String logId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableSyncLog,
        where: 'log_id = ?',
        whereArgs: [logId],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据日志ID查询同步日志失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLatestSync(String? syncModule) async {
    try {
      final db = await _dbHelper.database;
      String where = 'sync_status = 1';
      List<dynamic> whereArgs = [];
      if (syncModule != null && syncModule.isNotEmpty) {
        where += ' AND sync_module = ?';
        whereArgs.add(syncModule);
      }
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableSyncLog,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'sync_end_time DESC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('获取最近同步记录失败: $e');
      rethrow;
    }
  }

  Future<int> deleteById(int id) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(
        DatabaseTables.tableSyncLog,
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.d('删除同步日志成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除同步日志失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableSyncLog);
      _logger.d('清空同步日志成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空同步日志失败: $e');
      rethrow;
    }
  }

  Future<int> deleteOldLogs(int keepDays) async {
    try {
      final db = await _dbHelper.database;
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      String cutoffStr = cutoffDate.toIso8601String();
      int count = await db.delete(
        DatabaseTables.tableSyncLog,
        where: 'create_time < ?',
        whereArgs: [cutoffStr],
      );
      _logger.d('删除旧同步日志成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除旧同步日志失败: $e');
      rethrow;
    }
  }
}
