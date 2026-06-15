import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class AiCaptureEventDb {
  static final AiCaptureEventDb _instance = AiCaptureEventDb._internal();
  factory AiCaptureEventDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  AiCaptureEventDb._internal();

  Future<int> insert(Map<String, dynamic> event) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableAiCaptureEvent, event);
      _logger.d('插入AI抓拍事件成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> eventList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var event in eventList) {
        batch.insert(DatabaseTables.tableAiCaptureEvent, event,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入AI抓拍事件成功，数量: ${eventList.length}');
    } catch (e) {
      _logger.e('批量插入AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableAiCaptureEvent,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'capture_time DESC',
      );
    } catch (e) {
      _logger.e('查询AI抓拍事件列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnhandled() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableAiCaptureEvent,
        where: 'handle_status = ? AND is_deleted = ?',
        whereArgs: [0, 0],
        orderBy: 'capture_time DESC',
      );
    } catch (e) {
      _logger.e('查询未处理AI事件失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? cameraCode,
    String? eventType,
    String? eventCategory,
    int? handleStatus,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (cameraCode != null && cameraCode.isNotEmpty) {
        where += ' AND camera_code = ?';
        whereArgs.add(cameraCode);
      }

      if (eventType != null && eventType.isNotEmpty) {
        where += ' AND event_type = ?';
        whereArgs.add(eventType);
      }

      if (eventCategory != null && eventCategory.isNotEmpty) {
        where += ' AND event_category = ?';
        whereArgs.add(eventCategory);
      }

      if (handleStatus != null) {
        where += ' AND handle_status = ?';
        whereArgs.add(handleStatus);
      }

      if (startTime != null && startTime.isNotEmpty) {
        where += ' AND capture_time >= ?';
        whereArgs.add(startTime);
      }

      if (endTime != null && endTime.isNotEmpty) {
        where += ' AND capture_time <= ?';
        whereArgs.add(endTime);
      }

      return await db.query(
        DatabaseTables.tableAiCaptureEvent,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'capture_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询AI抓拍事件失败: $e');
      rethrow;
    }
  }

  Future<int> queryUnhandledCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableAiCaptureEvent} WHERE handle_status = ? AND is_deleted = ?',
        [0, 0],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询未处理AI事件数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByEventNo(String eventNo) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableAiCaptureEvent,
        where: 'event_no = ? AND is_deleted = ?',
        whereArgs: [eventNo, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据事件编号查询AI事件失败: $e');
      rethrow;
    }
  }

  Future<int> updateHandleStatus(
    String eventNo,
    int status, {
    String? handleTime,
    String? handleRemark,
  }) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'handle_status': status,
        if (handleTime != null) 'handle_time': handleTime,
        if (handleRemark != null) 'handle_remark': handleRemark,
      };
      int count = await db.update(
        DatabaseTables.tableAiCaptureEvent,
        values,
        where: 'event_no = ?',
        whereArgs: [eventNo],
      );
      _logger.d('更新AI事件处理状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新AI事件处理状态失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByEventNo(String eventNo) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableAiCaptureEvent,
        {'is_deleted': 1},
        where: 'event_no = ?',
        whereArgs: [eventNo],
      );
      _logger.d('删除AI事件成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除AI事件失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> eventList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableAiCaptureEvent);
        Batch batch = txn.batch();
        for (var event in eventList) {
          batch.insert(DatabaseTables.tableAiCaptureEvent, event);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换AI抓拍事件成功，数量: ${eventList.length}');
    } catch (e) {
      _logger.e('替换AI抓拍事件失败: $e');
      rethrow;
    }
  }
}
