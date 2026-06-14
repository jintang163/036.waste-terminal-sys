import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class WasteCatalogDb {
  static final WasteCatalogDb _instance = WasteCatalogDb._internal();
  factory WasteCatalogDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  WasteCatalogDb._internal();

  Future<int> insert(Map<String, dynamic> catalog) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableWasteCatalog, catalog);
      _logger.d('插入危废名录成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入危废名录失败: $e');
      rethrow;
    }
  }

  Future<void> batchInsert(List<Map<String, dynamic>> catalogList) async {
    try {
      final db = await _dbHelper.database;
      Batch batch = db.batch();
      for (var catalog in catalogList) {
        batch.insert(DatabaseTables.tableWasteCatalog, catalog);
      }
      await batch.commit(noResult: true);
      _logger.d('批量插入危废名录成功，数量: ${catalogList.length}');
    } catch (e) {
      _logger.e('批量插入危废名录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableWasteCatalog,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'update_time DESC',
      );
    } catch (e) {
      _logger.e('查询危废名录失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryWithPagination({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCategory,
    String? wasteType,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (waste_code LIKE ? OR waste_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (wasteType != null && wasteType.isNotEmpty) {
        where += ' AND waste_type = ?';
        whereArgs.add(wasteType);
      }

      return await db.query(
        DatabaseTables.tableWasteCatalog,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'update_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询危废名录失败: $e');
      rethrow;
    }
  }

  Future<int> queryCount({
    String? keyword,
    String? wasteCategory,
    String? wasteType,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (waste_code LIKE ? OR waste_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (wasteCategory != null && wasteCategory.isNotEmpty) {
        where += ' AND waste_category = ?';
        whereArgs.add(wasteCategory);
      }

      if (wasteType != null && wasteType.isNotEmpty) {
        where += ' AND waste_type = ?';
        whereArgs.add(wasteType);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableWasteCatalog} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询危废名录数量失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByCatalogId(String catalogId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteCatalog,
        where: 'catalog_id = ? AND is_deleted = ?',
        whereArgs: [catalogId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据ID查询危废名录失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByWasteCode(String wasteCode) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableWasteCatalog,
        where: 'waste_code = ? AND is_deleted = ?',
        whereArgs: [wasteCode, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据废物代码查询危废名录失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> catalog) async {
    try {
      final db = await _dbHelper.database;
      String? catalogId = catalog['catalog_id'];
      if (catalogId == null) {
        throw ArgumentError('catalog_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableWasteCatalog,
        catalog,
        where: 'catalog_id = ?',
        whereArgs: [catalogId],
      );
      _logger.d('更新危废名录成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新危废名录失败: $e');
      rethrow;
    }
  }

  Future<int> deleteByCatalogId(String catalogId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableWasteCatalog,
        {'is_deleted': 1},
        where: 'catalog_id = ?',
        whereArgs: [catalogId],
      );
      _logger.d('删除危废名录成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除危废名录失败: $e');
      rethrow;
    }
  }

  Future<int> deleteAll() async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete(DatabaseTables.tableWasteCatalog);
      _logger.d('清空危废名录成功，删除行数: $count');
      return count;
    } catch (e) {
      _logger.e('清空危废名录失败: $e');
      rethrow;
    }
  }

  Future<void> replaceAll(List<Map<String, dynamic>> catalogList) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableWasteCatalog);
        Batch batch = txn.batch();
        for (var catalog in catalogList) {
          batch.insert(DatabaseTables.tableWasteCatalog, catalog);
        }
        await batch.commit(noResult: true);
      });
      _logger.d('替换危废名录成功，数量: ${catalogList.length}');
    } catch (e) {
      _logger.e('替换危废名录失败: $e');
      rethrow;
    }
  }
}
