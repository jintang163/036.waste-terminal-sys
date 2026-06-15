import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class LocalRecordTaskDb {
  static final LocalRecordTaskDb _instance = LocalRecordTaskDb._internal();
  factory LocalRecordTaskDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  LocalRecordTaskDb._internal();

  Future<int> insert(Map<String, dynamic> task) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableLocalRecordTask, task);
      _logger.d('插入录像任务成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入录像任务失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableLocalRecordTask,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询录像任务列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsynced() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableLocalRecordTask,
        where: 'sync_status = ? AND status = ? AND is_deleted = ?',
        whereArgs: [0, 1, 0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询未同步录像任务失败: $e');
      rethrow;
    }
  }

  Future<int> queryUnsyncedCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableLocalRecordTask} WHERE sync_status = ? AND status = ? AND is_deleted = ?',
        [0, 1, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询未同步录像任务数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByTaskId(String taskId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableLocalRecordTask,
        where: 'task_id = ? AND is_deleted = ?',
        whereArgs: [taskId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据任务ID查询录像任务失败: $e');
      rethrow;
    }
  }

  Future<int> updateSyncStatus(String taskId, int syncStatus, {String? syncTime}) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'sync_status': syncStatus,
        if (syncTime != null) 'sync_time': syncTime,
      };
      int count = await db.update(
        DatabaseTables.tableLocalRecordTask,
        values,
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      _logger.d('更新录像任务同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新录像任务同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> updateRecordInfo(String taskId, {
    String? filePath,
    int? fileSize,
    int? durationSeconds,
    String? startTime,
    String? endTime,
    int? status,
  }) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {};
      if (filePath != null) values['file_path'] = filePath;
      if (fileSize != null) values['file_size'] = fileSize;
      if (durationSeconds != null) values['duration_seconds'] = durationSeconds;
      if (startTime != null) values['start_time'] = startTime;
      if (endTime != null) values['end_time'] = endTime;
      if (status != null) values['status'] = status;

      int count = await db.update(
        DatabaseTables.tableLocalRecordTask,
        values,
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      _logger.d('更新录像信息成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新录像信息失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByTaskId(String taskId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableLocalRecordTask,
        {'is_deleted': 1},
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      _logger.d('删除录像任务成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除录像任务失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableLocalRecordTask);
      _logger.d('清空录像任务成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空录像任务失败: $e');
      rethrow;
    }
  }

  Future<int> cleanupOldRecords(int retentionDays) async {
    try {
      final db = await _dbHelper.database;
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      int count = await db.update(
        DatabaseTables.tableLocalRecordTask,
        {'is_deleted': 1},
        where: 'sync_status = ? AND create_time < ?',
        whereArgs: [1, cutoff.toIso8601String()],
      );
      _logger.d('清理过期录像记录成功，数量: $count');
      return count;
    } catch (e) {
      _logger.e('清理过期录像记录失败: $e');
      rethrow;
    }
  }
}
