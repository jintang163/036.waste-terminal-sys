import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class TransportDriverDb {
  static final TransportDriverDb _instance = TransportDriverDb._internal();
  factory TransportDriverDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  TransportDriverDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableTransportDriver, record);
      _logger.d('插入驾驶员成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入驾驶员失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      String? driverId = record['driver_id'];
      if (driverId == null) {
        throw ArgumentError('driver_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableTransportDriver,
        record,
        where: 'driver_id = ?',
        whereArgs: [driverId],
      );
      _logger.d('更新驾驶员成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新驾驶员失败: $e');
      rethrow;
    }
  }

  Future<int> delete(String driverId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableTransportDriver,
        {'is_deleted': 1},
        where: 'driver_id = ?',
        whereArgs: [driverId],
      );
      _logger.d('删除驾驶员成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除驾驶员失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryById(String driverId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransportDriver,
        where: 'driver_id = ? AND is_deleted = ?',
        whereArgs: [driverId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据驾驶员ID查询驾驶员失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportDriver,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询驾驶员列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByName(String driverName) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportDriver,
        where: 'driver_name LIKE ? AND is_deleted = ?',
        whereArgs: ['%$driverName%', 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据姓名查询驾驶员失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryList({
    String? keyword,
    int? status,
    String? vehicleId,
    String? licenseType,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (driver_name LIKE ? OR phone LIKE ? OR id_card LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (vehicleId != null && vehicleId.isNotEmpty) {
        where += ' AND vehicle_id = ?';
        whereArgs.add(vehicleId);
      }

      if (licenseType != null && licenseType.isNotEmpty) {
        where += ' AND driver_license_type = ?';
        whereArgs.add(licenseType);
      }

      return await db.query(
        DatabaseTables.tableTransportDriver,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'create_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询驾驶员失败: $e');
      rethrow;
    }
  }

  Future<int> replaceAll(List<Map<String, dynamic>> records) async {
    try {
      final db = await _dbHelper.database;
      int count = 0;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableTransportDriver);
        for (var record in records) {
          await txn.insert(DatabaseTables.tableTransportDriver, record);
          count++;
        }
      });
      _logger.d('替换驾驶员数据成功，共插入: $count 条');
      return count;
    } catch (e) {
      _logger.e('替换驾驶员数据失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByStatus(int status) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportDriver,
        where: 'status = ? AND is_deleted = ?',
        whereArgs: [status, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据状态查询驾驶员失败: $e');
      rethrow;
    }
  }

  Future<int> count({
    String? keyword,
    int? status,
    String? vehicleId,
    String? licenseType,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (driver_name LIKE ? OR phone LIKE ? OR id_card LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (vehicleId != null && vehicleId.isNotEmpty) {
        where += ' AND vehicle_id = ?';
        whereArgs.add(vehicleId);
      }

      if (licenseType != null && licenseType.isNotEmpty) {
        where += ' AND driver_license_type = ?';
        whereArgs.add(licenseType);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableTransportDriver} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询驾驶员数量失败: $e');
      rethrow;
    }
  }
}
