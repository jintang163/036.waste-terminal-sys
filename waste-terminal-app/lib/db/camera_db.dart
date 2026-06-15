import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class CameraDb {
  static final CameraDb _instance = CameraDb._internal();
  factory CameraDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  CameraDb._internal();

  Future<int> insert(Map<String, dynamic> camera) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableCamera, camera);
      _logger.d('插入摄像头成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入摄像头失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> cameraList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var camera in cameraList) {
        batch.insert(DatabaseTables.tableCamera, camera,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入摄像头成功，数量: ${cameraList.length}');
    } catch (e) {
      _logger.e('批量插入摄像头失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableCamera,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'camera_code ASC',
      );
    } catch (e) {
      _logger.e('查询摄像头列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryOnline() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableCamera,
        where: 'status = ? AND is_deleted = ?',
        whereArgs: [1, 0],
        orderBy: 'camera_code ASC',
      );
    } catch (e) {
      _logger.e('查询在线摄像头失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByCameraCode(String cameraCode) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableCamera,
        where: 'camera_code = ? AND is_deleted = ?',
        whereArgs: [cameraCode, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据编码查询摄像头失败: $e');
      rethrow;
    }
  }

  Future<int> updateStatus(String cameraCode, int status) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableCamera,
        {'status': status},
        where: 'camera_code = ?',
        whereArgs: [cameraCode],
      );
      _logger.d('更新摄像头状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新摄像头状态失败: $e');
      rethrow;
    }
  }

  Future<int> updateAiEnabled(String cameraCode, bool enabled) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableCamera,
        {'ai_enabled': enabled ? 1 : 0},
        where: 'camera_code = ?',
        whereArgs: [cameraCode],
      );
      _logger.d('更新摄像头AI状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新摄像头AI状态失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByCameraCode(String cameraCode) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableCamera,
        {'is_deleted': 1},
        where: 'camera_code = ?',
        whereArgs: [cameraCode],
      );
      _logger.d('删除摄像头成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除摄像头失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableCamera);
      _logger.d('清空摄像头成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空摄像头失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> cameraList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableCamera);
        Batch batch = txn.batch();
        for (var camera in cameraList) {
          batch.insert(DatabaseTables.tableCamera, camera);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换摄像头成功，数量: ${cameraList.length}');
    } catch (e) {
      _logger.e('替换摄像头失败: $e');
      rethrow;
    }
  }
}
