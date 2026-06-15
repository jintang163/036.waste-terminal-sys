import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_face_model.dart';
import 'database_helper.dart';
import 'database_tables.dart';

class UserFaceDb {
  static final UserFaceDb _instance = UserFaceDb._internal();
  factory UserFaceDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  UserFaceDb._internal();

  Future<int> insertUserFace(UserFaceModel face) async {
    try {
      final db = await _dbHelper.database;
      final dbMap = face.toDbMap();
      int id = await db.insert(DatabaseTables.tableUserFace, dbMap,
          conflictAlgorithm: ConflictAlgorithm.replace);
      _logger.d('插入人脸信息成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入人脸信息失败: $e');
      rethrow;
    }
  }

  Future<int> insert(Map<String, dynamic> face) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableUserFace, face,
          conflictAlgorithm: ConflictAlgorithm.replace);
      _logger.d('插入人脸信息成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入人脸信息失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> faceList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var face in faceList) {
        batch.insert(DatabaseTables.tableUserFace, face,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入人脸信息成功，数量: ${faceList.length}');
    } catch (e) {
      _logger.e('批量插入人脸信息失败: $e');
      rethrow;
    }
  }

  Future<List<UserFaceModel>> queryAllModels() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseTables.tableUserFace,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
      return maps.map((map) => UserFaceModel.fromDbMap(map)).toList();
    } catch (e) {
      _logger.e('查询人脸信息列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableUserFace,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询人脸信息列表失败: $e');
      rethrow;
    }
  }

  Future<List<UserFaceModel>> queryEnabledModels() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseTables.tableUserFace,
        where: 'status = ? AND is_deleted = ?',
        whereArgs: [1, 0],
        orderBy: 'create_time DESC',
      );
      return maps.map((map) => UserFaceModel.fromDbMap(map)).toList();
    } catch (e) {
      _logger.e('查询启用人脸失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryEnabled() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableUserFace,
        where: 'status = ? AND is_deleted = ?',
        whereArgs: [1, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询启用人脸失败: $e');
      rethrow;
    }
  }

  Future<UserFaceModel?> queryModelByUserId(int userId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableUserFace,
        where: 'user_id = ? AND is_deleted = ?',
        whereArgs: [userId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? UserFaceModel.fromDbMap(result.first) : null;
    } catch (e) {
      _logger.e('根据用户ID查询人脸失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByUserId(int userId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableUserFace,
        where: 'user_id = ? AND is_deleted = ?',
        whereArgs: [userId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据用户ID查询人脸失败: $e');
      rethrow;
    }
  }

  Future<UserFaceModel?> queryModelByUsername(String username) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableUserFace,
        where: 'username = ? AND is_deleted = ?',
        whereArgs: [username, 0],
        limit: 1,
      );
      return result.isNotEmpty ? UserFaceModel.fromDbMap(result.first) : null;
    } catch (e) {
      _logger.e('根据用户名查询人脸失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByUsername(String username) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableUserFace,
        where: 'username = ? AND is_deleted = ?',
        whereArgs: [username, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据用户名查询人脸失败: $e');
      rethrow;
    }
  }

  Future<UserFaceModel?> queryModelByFaceId(String faceId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableUserFace,
        where: 'face_id = ? AND is_deleted = ?',
        whereArgs: [faceId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? UserFaceModel.fromDbMap(result.first) : null;
    } catch (e) {
      _logger.e('根据faceId查询人脸失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByFaceId(String faceId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableUserFace,
        where: 'face_id = ? AND is_deleted = ?',
        whereArgs: [faceId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据faceId查询人脸失败: $e');
      rethrow;
    }
  }

  Future<int> updateStatus(String faceId, int status) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableUserFace,
        {'status': status, 'update_time': DateTime.now().toIso8601String()},
        where: 'face_id = ?',
        whereArgs: [faceId],
      );
      _logger.d('更新人脸状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新人脸状态失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByFaceId(String faceId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableUserFace,
        {'is_deleted': 1, 'update_time': DateTime.now().toIso8601String()},
        where: 'face_id = ?',
        whereArgs: [faceId],
      );
      _logger.d('删除人脸信息成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除人脸信息失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableUserFace);
      _logger.d('清空人脸信息成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空人脸信息失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> faceList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableUserFace);
        Batch batch = txn.batch();
        for (var face in faceList) {
          batch.insert(DatabaseTables.tableUserFace, face);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换人脸信息成功，数量: ${faceList.length}');
    } catch (e) {
      _logger.e('替换人脸信息失败: $e');
      rethrow;
    }
  }
}
