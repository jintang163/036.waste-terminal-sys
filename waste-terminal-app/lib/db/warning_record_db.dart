import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class WarningRecordDb {
  static final WarningRecordDb _instance = WarningRecordDb._internal();
  factory WarningRecordDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  WarningRecordDb._internal();

  Future<int> insert(Map<String, dynamic> warning) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableWarningRecord, warning);
      _logger.d('插入预警成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入预警失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> warningList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var warning in warningList) {
        batch.insert(DatabaseTables.tableWarningRecord, warning);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入预警成功，数量: ${warningList.length}');
    } catch (e) {
      _logger.e('批量插入预警失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWarningRecord,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'warning_time DESC',
      );
    } catch (e) {
      _logger.e('查询预警列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? warningType,
    int? warningLevel,
    int? status,
    String? wasteCode,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (warning_title LIKE ? OR warning_content LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (warningType != null && warningType.isNotEmpty) {
        where += ' AND warning_type = ?';
        whereArgs.add(warningType);
      }

      if (warningLevel != null) {
        where += ' AND warning_level = ?';
        whereArgs.add(warningLevel);
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (wasteCode != null && wasteCode.isNotEmpty) {
        where += ' AND waste_code = ?';
        whereArgs.add(wasteCode);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND warning_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND warning_time <= ?';
        whereArgs.add(endTime);
      }

      return await db.query(
        DatabaseTables.tableWarningRecord,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'warning_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询预警失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? warningType,
    int? warningLevel,
    int? status,
    String? wasteCode,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (warning_title LIKE ? OR warning_content LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (warningType != null && warningType.isNotEmpty) {
        where += ' AND warning_type = ?';
        whereArgs.add(warningType);
      }

      if (warningLevel != null) {
        where += ' AND warning_level = ?';
        whereArgs.add(warningLevel);
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (wasteCode != null && wasteCode.isNotEmpty) {
        where += ' AND waste_code = ?';
        whereArgs.add(wasteCode);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND warning_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND warning_time <= ?';
        whereArgs.add(endTime);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWarningRecord} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询预警数量失败: $e');
      rethrow;
    }
  }

  Future<int> queryUnreadCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWarningRecord} WHERE status = ? AND is_deleted = ?',
        [0, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询未处理预警数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByWarningId(String warningId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWarningRecord,
        where: 'warning_id = ? AND is_deleted = ?',
        whereArgs: [warningId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据预警ID查询预警失败: $e');
      rethrow;
    }
  }

  Future<int> updateHandleStatus(
    String warningId,
    int status, {
    String? handleTime,
    String? handler,
    String? handlerId,
    String? handleRemark,
  }) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'status': status,
        if (handleTime != null) 'handle_time': handleTime,
        if (handler != null) 'handler': handler,
        if (handlerId != null) 'handler_id': handlerId,
        if (handleRemark != null) 'handle_remark': handleRemark,
      };
      int count = await db.update(
        DatabaseTables.tableWarningRecord,
        values,
        where: 'warning_id = ?',
        whereArgs: [warningId],
      );
      _logger.d('更新预警处理状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新预警处理状态失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> warning) async {
    try {
      final db = await _dbHelper.database;
      String? warningId = warning['warning_id'];
      if (warningId == null) {
        throw ArgumentError('warning_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableWarningRecord,
        warning,
        where: 'warning_id = ?',
        whereArgs: [warningId],
      );
      _logger.d('更新预警成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新预警失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByWarningId(String warningId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableWarningRecord,
        {'is_deleted': 1},
        where: 'warning_id = ?',
        whereArgs: [warningId],
      );
      _logger.d('删除预警成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除预警失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableWarningRecord);
      _logger.d('清空预警成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空预警失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> warningList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableWarningRecord);
        Batch batch = txn.batch();
        for (var warning in warningList) {
          batch.insert(DatabaseTables.tableWarningRecord, warning);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换预警成功，数量: ${warningList.length}');
    } catch (e) {
      _logger.e('替换预警失败: $e');
      rethrow;
    }
  }
}
