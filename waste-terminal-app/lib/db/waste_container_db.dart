import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class WasteContainerDb {
  static final WasteContainerDb _instance = WasteContainerDb._internal();
  factory WasteContainerDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  WasteContainerDb._internal();

  Future<int> insert(Map<String, dynamic> container) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableWasteContainer, container);
      _logger.d('插入容器成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入容器失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> containerList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var container in containerList) {
        batch.insert(DatabaseTables.tableWasteContainer, container);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入容器成功，数量: ${containerList.length}');
    } catch (e) {
      _logger.e('批量插入容器失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteContainer,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'update_time DESC',
      );
    } catch (e) {
      _logger.e('查询容器列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? containerType,
    int? status,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (container_code LIKE ? OR container_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (containerType != null && containerType.isNotEmpty) {
        where += ' AND container_type = ?';
        whereArgs.add(containerType);
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      return await db.query(
        DatabaseTables.tableWasteContainer,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'update_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询容器失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? containerType,
    int? status,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (container_code LIKE ? OR container_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (containerType != null && containerType.isNotEmpty) {
        where += ' AND container_type = ?';
        whereArgs.add(containerType);
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWasteContainer} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询容器数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByContainerId(String containerId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteContainer,
        where: 'container_id = ? AND is_deleted = ?',
        whereArgs: [containerId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据ID查询容器失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByContainerCode(String containerCode) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteContainer,
        where: 'container_code = ? AND is_deleted = ?',
        whereArgs: [containerCode, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据编码查询容器失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByRfidCode(String rfidCode) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteContainer,
        where: 'rfid_code = ? AND is_deleted = ?',
        whereArgs: [rfidCode, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据RFID查询容器失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> container) async {
    try {
      final db = await _dbHelper.database;
      String? containerId = container['container_id'];
      if (containerId == null) {
        throw ArgumentError('container_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableWasteContainer,
        container,
        where: 'container_id = ?',
        whereArgs: [containerId],
      );
      _logger.d('更新容器成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新容器失败: $e');
      rethrow;
    }
  }

  Future<int> updateStatus(String containerId, int status) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableWasteContainer,
        {'status': status},
        where: 'container_id = ?',
        whereArgs: [containerId],
      );
      _logger.d('更新容器状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新容器状态失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByContainerId(String containerId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableWasteContainer,
        {'is_deleted': 1},
        where: 'container_id = ?',
        whereArgs: [containerId],
      );
      _logger.d('删除容器成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除容器失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableWasteContainer);
      _logger.d('清空容器成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空容器失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> containerList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableWasteContainer);
        Batch batch = txn.batch();
        for (var container in containerList) {
          batch.insert(DatabaseTables.tableWasteContainer, container);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换容器成功，数量: ${containerList.length}');
    } catch (e) {
      _logger.e('替换容器失败: $e');
      rethrow;
    }
  }
}
