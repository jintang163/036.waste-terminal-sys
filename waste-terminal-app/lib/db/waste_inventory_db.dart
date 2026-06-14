import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class WasteInventoryDb {
  static final WasteInventoryDb _instance = WasteInventoryDb._internal();
  factory WasteInventoryDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  WasteInventoryDb._internal();

  Future<int> insert(Map<String, dynamic> inventory) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableWasteInventory, inventory);
      _logger.d('插入库存成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入库存失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> inventoryList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var inventory in inventoryList) {
        batch.insert(DatabaseTables.tableWasteInventory, inventory);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入库存成功，数量: ${inventoryList.length}');
    } catch (e) {
      _logger.e('批量插入库存失败: $e');
      rethrow;
    }
  }

  Future<void> batchUpsert(List<Map<String, dynamic>> inventoryList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (var inventory in inventoryList) {
          String? inventoryId = inventory['inventory_id'];
          String? wasteCode = inventory['waste_code'];
          String? containerId = inventory['container_id'];

          if (inventoryId != null && inventoryId.isNotEmpty) {
            List<Map<String, dynamic>> existing = await txn.query(
              DatabaseTables.tableWasteInventory,
              where: 'inventory_id = ? AND is_deleted = ?',
              whereArgs: [inventoryId, 0],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              await txn.update(
                DatabaseTables.tableWasteInventory,
                inventory,
                where: 'inventory_id = ?',
                whereArgs: [inventoryId],
              );
            } else {
              await txn.insert(DatabaseTables.tableWasteInventory, inventory);
            }
          } else if (wasteCode != null && containerId != null) {
            List<Map<String, dynamic>> existing = await txn.query(
              DatabaseTables.tableWasteInventory,
              where: 'waste_code = ? AND container_id = ? AND is_deleted = ?',
              whereArgs: [wasteCode, containerId, 0],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              await txn.update(
                DatabaseTables.tableWasteInventory,
                inventory,
                where: 'waste_code = ? AND container_id = ?',
                whereArgs: [wasteCode, containerId],
              );
            } else {
              await txn.insert(DatabaseTables.tableWasteInventory, inventory);
            }
          } else {
            await txn.insert(DatabaseTables.tableWasteInventory, inventory);
          }
        }
      });
      _logger.d('批量更新库存成功，数量: ${inventoryList.length}');
    } catch (e) {
      _logger.e('批量更新库存失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteInventory,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'update_time DESC',
      );
    } catch (e) {
      _logger.e('查询库存列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? warehouseId,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (waste_code LIKE ? OR waste_name LIKE ? OR container_code LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCode != null && wasteCode.isNotEmpty) {
        where += ' AND waste_code = ?';
        whereArgs.add(wasteCode);
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        where += ' AND warehouse_id = ?';
        whereArgs.add(warehouseId);
      }

      return await db.query(
        DatabaseTables.tableWasteInventory,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'update_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询库存失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? warehouseId,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (waste_code LIKE ? OR waste_name LIKE ? OR container_code LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCode != null && wasteCode.isNotEmpty) {
        where += ' AND waste_code = ?';
        whereArgs.add(wasteCode);
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        where += ' AND warehouse_id = ?';
        whereArgs.add(warehouseId);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWasteInventory} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询库存数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await _dbHelper.database;

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total_count, COALESCE(SUM(quantity), 0) as total_quantity, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInventory} WHERE is_deleted = ?',
        [0],
      );

      final categoryResult = await db.rawQuery(
        'SELECT waste_category, COUNT(*) as count, COALESCE(SUM(quantity), 0) as total_quantity, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInventory} WHERE is_deleted = ? GROUP BY waste_category',
        [0],
      );

      Map<String, dynamic> stats = {};
      if (totalResult.isNotEmpty) {
        stats['total_count'] = totalResult.first['total_count'];
        stats['total_quantity'] = totalResult.first['total_quantity'];
        stats['total_weight'] = totalResult.first['total_weight'];
      } else {
        stats['total_count'] = 0;
        stats['total_quantity'] = 0.0;
        stats['total_weight'] = 0.0;
      }
      stats['by_category'] = categoryResult;

      return stats;
    } catch (e) {
      _logger.e('统计库存失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByInventoryId(String inventoryId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteInventory,
        where: 'inventory_id = ? AND is_deleted = ?',
        whereArgs: [inventoryId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据ID查询库存失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByWasteCode(String wasteCode) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteInventory,
        where: 'waste_code = ? AND is_deleted = ?',
        whereArgs: [wasteCode, 0],
        orderBy: 'update_time DESC',
      );
    } catch (e) {
      _logger.e('根据废物代码查询库存失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByContainerId(String containerId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteInventory,
        where: 'container_id = ? AND is_deleted = ?',
        whereArgs: [containerId, 0],
        orderBy: 'update_time DESC',
      );
    } catch (e) {
      _logger.e('根据容器ID查询库存失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> inventory) async {
    try {
      final db = await _dbHelper.database;
      String? inventoryId = inventory['inventory_id'];
      if (inventoryId == null) {
        throw ArgumentError('inventory_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableWasteInventory,
        inventory,
        where: 'inventory_id = ?',
        whereArgs: [inventoryId],
      );
      _logger.d('更新库存成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新库存失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByInventoryId(String inventoryId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableWasteInventory,
        {'is_deleted': 1},
        where: 'inventory_id = ?',
        whereArgs: [inventoryId],
      );
      _logger.d('删除库存成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除库存失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableWasteInventory);
      _logger.d('清空库存成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空库存失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> inventoryList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableWasteInventory);
        Batch batch = txn.batch();
        for (var inventory in inventoryList) {
          batch.insert(DatabaseTables.tableWasteInventory, inventory);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换库存成功，数量: ${inventoryList.length}');
    } catch (e) {
      _logger.e('替换库存失败: $e');
      rethrow;
    }
  }
}
