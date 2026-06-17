import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class CarbonFootprintDb {
  static final CarbonFootprintDb _instance = CarbonFootprintDb._internal();
  factory CarbonFootprintDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  CarbonFootprintDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableCarbonFootprintRecord, record);
      _logger.d('插入碳足迹记录成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> recordList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var record in recordList) {
        batch.insert(DatabaseTables.tableCarbonFootprintRecord, record);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入碳足迹记录成功，数量: ${recordList.length}');
    } catch (e) {
      _logger.e('批量插入碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'record_time DESC',
      );
    } catch (e) {
      _logger.e('查询碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCategory,
    String? disposalMethod,
    DateTime? startTime,
    DateTime? endTime,
    int? syncStatus,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (waste_code LIKE ? OR waste_name LIKE ? OR transfer_order_no LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (disposalMethod != null && disposalMethod.isNotEmpty) {
        where += ' AND disposal_method = ?';
        whereArgs.add(disposalMethod);
      }

      if (startTime != null) {
        where += ' AND record_time >= ?';
        whereArgs.add(startTime.toIso8601String());
      }

      if (endTime != null) {
        where += ' AND record_time <= ?';
        whereArgs.add(endTime.toIso8601String());
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      return await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'record_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? wasteCategory,
    String? disposalMethod,
    DateTime? startTime,
    DateTime? endTime,
    int? syncStatus,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (waste_code LIKE ? OR waste_name LIKE ? OR transfer_order_no LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (disposalMethod != null && disposalMethod.isNotEmpty) {
        where += ' AND disposal_method = ?';
        whereArgs.add(disposalMethod);
      }

      if (startTime != null) {
        where += ' AND record_time >= ?';
        whereArgs.add(startTime.toIso8601String());
      }

      if (endTime != null) {
        where += ' AND record_time <= ?';
        whereArgs.add(endTime.toIso8601String());
      }

      if (syncStatus != null) {
        where += ' AND sync_status = ?';
        whereArgs.add(syncStatus);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableCarbonFootprintRecord} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询碳足迹记录数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryById(int id) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: 'id = ? AND is_deleted = ?',
        whereArgs: [id, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据ID查询碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByRecordId(String recordId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: 'record_id = ? AND is_deleted = ?',
        whereArgs: [recordId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据记录ID查询碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: 'offline_id = ? AND is_deleted = ?',
        whereArgs: [offlineId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据离线ID查询碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByTransferOrderNo(
      String transferOrderNo) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: 'transfer_order_no = ? AND is_deleted = ?',
        whereArgs: [transferOrderNo, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据转运联单号查询碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsynced() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableCarbonFootprintRecord,
        where: 'sync_status = ? AND is_deleted = ?',
        whereArgs: [0, 0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询未同步碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int? id = record['id'];
      if (id == null) {
        throw ArgumentError('id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableCarbonFootprintRecord,
        record,
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.d('更新碳足迹记录成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<int> updateSyncStatus(int id, int syncStatus, {String? syncTime}) async {
    try {
      final db = await _dbHelper.database;
      final Map<String, dynamic> values = {
        'sync_status': syncStatus,
        'sync_time': syncTime ?? DateTime.now().toIso8601String(),
        'update_time': DateTime.now().toIso8601String(),
      };
      int count = await db.update(
        DatabaseTables.tableCarbonFootprintRecord,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.d('更新碳足迹同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新碳足迹同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> deleteById(int id) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableCarbonFootprintRecord,
        {'is_deleted': 1, 'update_time': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.d('删除碳足迹记录成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableCarbonFootprintRecord);
      _logger.d('清空碳足迹记录成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (startTime != null) {
        where += ' AND record_time >= ?';
        whereArgs.add(startTime.toIso8601String());
      }

      if (endTime != null) {
        where += ' AND record_time <= ?';
        whereArgs.add(endTime.toIso8601String());
      }

      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_count,
          COALESCE(SUM(total_emission), 0) as total_emission,
          COALESCE(SUM(transport_emission), 0) as transport_emission,
          COALESCE(SUM(disposal_emission), 0) as disposal_emission,
          COALESCE(SUM(weight), 0) as total_weight
        FROM ${DatabaseTables.tableCarbonFootprintRecord}
        WHERE $where
        ''',
        whereArgs,
      );

      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      _logger.e('查询碳足迹统计失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (startTime != null) {
        where += ' AND record_time >= ?';
        whereArgs.add(startTime.toIso8601String());
      }

      if (endTime != null) {
        where += ' AND record_time <= ?';
        whereArgs.add(endTime.toIso8601String());
      }

      final result = await db.rawQuery(
        '''
        SELECT 
          waste_category,
          COUNT(*) as count,
          COALESCE(SUM(total_emission), 0) as total_emission,
          COALESCE(SUM(weight), 0) as total_weight
        FROM ${DatabaseTables.tableCarbonFootprintRecord}
        WHERE $where
        GROUP BY waste_category
        ORDER BY total_emission DESC
        ''',
        whereArgs,
      );

      return result;
    } catch (e) {
      _logger.e('查询分类碳足迹统计失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDailyStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (startTime != null) {
        where += ' AND record_time >= ?';
        whereArgs.add(startTime.toIso8601String());
      }

      if (endTime != null) {
        where += ' AND record_time <= ?';
        whereArgs.add(endTime.toIso8601String());
      }

      final result = await db.rawQuery(
        '''
        SELECT 
          DATE(record_time) as date,
          COUNT(*) as count,
          COALESCE(SUM(total_emission), 0) as total_emission,
          COALESCE(SUM(transport_emission), 0) as transport_emission,
          COALESCE(SUM(disposal_emission), 0) as disposal_emission
        FROM ${DatabaseTables.tableCarbonFootprintRecord}
        WHERE $where
        GROUP BY DATE(record_time)
        ORDER BY date DESC
        ''',
        whereArgs,
      );

      return result;
    } catch (e) {
      _logger.e('查询每日碳足迹统计失败: $e');
      rethrow;
    }
  }
}
