import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';
import '../models/waste_out_review.dart';

class WasteOutReviewDb {
  static final WasteOutReviewDb _instance = WasteOutReviewDb._internal();
  factory WasteOutReviewDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  WasteOutReviewDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableWasteOutReview, record);
      _logger.d('插入出库复核记录成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入出库复核记录失败: $e');
      rethrow;
    }
  }

  Future<int> update(int id, Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int result = await db.update(
        DatabaseTables.tableWasteOutReview,
        record,
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.d('更新出库复核记录成功: $id');
      return result;
    } catch (e) {
      _logger.e('更新出库复核记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.tableWasteOutReview,
        where: 'id = ? AND is_deleted = ?',
        whereArgs: [id, 0],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      _logger.e('查询出库复核记录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getByReviewNo(String reviewNo) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.tableWasteOutReview,
        where: 'review_no = ? AND is_deleted = ?',
        whereArgs: [reviewNo, 0],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      _logger.e('根据复核单号查询失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getByOutNo(String outNo) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.tableWasteOutReview,
        where: 'out_no = ? AND is_deleted = ?',
        whereArgs: [outNo, 0],
        orderBy: 'create_time DESC',
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      _logger.e('根据出库单号查询复核记录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteOutReview,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询出库复核记录列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncList() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteOutReview,
        where: 'sync_status != ? AND is_deleted = ?',
        whereArgs: [2, 0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询待同步复核记录失败: $e');
      rethrow;
    }
  }

  Future<bool> checkByOfflineId(String offlineId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.tableWasteOutReview,
        where: 'offline_id = ? AND is_deleted = ?',
        whereArgs: [offlineId, 0],
      );
      return results.isNotEmpty;
    } catch (e) {
      _logger.e('检查离线ID是否存在失败: $e');
      return false;
    }
  }

  Future<int> updateSyncStatus(int id, int syncStatus, {String? syncTime}) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> updateData = {
        'sync_status': syncStatus,
        'update_time': syncTime ?? DateTime.now().toIso8601String(),
      };
      if (syncStatus == 2) {
        updateData['sync_time'] = syncTime ?? DateTime.now().toIso8601String();
      }
      return await db.update(
        DatabaseTables.tableWasteOutReview,
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logger.e('更新同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.update(
        DatabaseTables.tableWasteOutReview,
        {
          'is_deleted': 1,
          'update_time': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logger.e('删除出库复核记录失败: $e');
      rethrow;
    }
  }
}
