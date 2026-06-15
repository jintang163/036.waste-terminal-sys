import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class FaceAuthRecordDb {
  static final FaceAuthRecordDb _instance = FaceAuthRecordDb._internal();
  factory FaceAuthRecordDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  FaceAuthRecordDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableFaceAuthRecord, record);
      _logger.d('插入人脸认证记录成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> recordList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var record in recordList) {
        batch.insert(DatabaseTables.tableFaceAuthRecord, record,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入人脸认证记录成功，数量: ${recordList.length}');
    } catch (e) {
      _logger.e('批量插入人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableFaceAuthRecord,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'auth_time DESC',
      );
    } catch (e) {
      _logger.e('查询人脸认证记录列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsynced() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableFaceAuthRecord,
        where: 'sync_status = ? AND is_deleted = ?',
        whereArgs: [0, 0],
        orderBy: 'auth_time ASC',
      );
    } catch (e) {
      _logger.e('查询未同步人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByBusiness(String businessType, String businessId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableFaceAuthRecord,
        where: 'business_type = ? AND business_id = ? AND is_deleted = ?',
        whereArgs: [businessType, businessId, 0],
        orderBy: 'auth_time DESC',
      );
    } catch (e) {
      _logger.e('根据业务查询人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByUserId(int userId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableFaceAuthRecord,
        where: 'user_id = ? AND is_deleted = ?',
        whereArgs: [userId, 0],
        orderBy: 'auth_time DESC',
      );
    } catch (e) {
      _logger.e('根据用户查询人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByAuthId(String authId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableFaceAuthRecord,
        where: 'auth_id = ? AND is_deleted = ?',
        whereArgs: [authId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据authId查询人脸认证记录失败: $e');
      rethrow;
    }
  }

  Future<int> updateSyncStatus(String authId, int syncStatus) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableFaceAuthRecord,
        {
          'sync_status': syncStatus,
          'sync_time': DateTime.now().toIso8601String(),
        },
        where: 'auth_id = ?',
        whereArgs: [authId],
      );
      _logger.d('更新人脸认证记录同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新人脸认证记录同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> batchUpdateSyncStatus(List<String> authIds, int syncStatus) async {
    if (authIds.isEmpty) return 0;
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (var authId in authIds) {
        batch.update(
          DatabaseTables.tableFaceAuthRecord,
          {'sync_status': syncStatus, 'sync_time': now},
          where: 'auth_id = ?',
          whereArgs: [authId],
        );
      }
      final results = await batch.commit();
      final count = results.where((r) => r is int && r > 0).length;
      _logger.d('批量更新同步状态成功，数量: $count');
      return count;
    } catch (e) {
      _logger.e('批量更新同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableFaceAuthRecord);
      _logger.d('清空人脸认证记录成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空人脸认证记录失败: $e');
      rethrow;
    }
  }
}
