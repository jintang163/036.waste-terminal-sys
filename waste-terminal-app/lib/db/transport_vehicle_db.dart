import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class TransportVehicleDb {
  static final TransportVehicleDb _instance = TransportVehicleDb._internal();
  factory TransportVehicleDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  TransportVehicleDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableTransportVehicle, record);
      _logger.d('插入运输车辆成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入运输车辆失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      String? vehicleId = record['vehicle_id'];
      if (vehicleId == null) {
        throw ArgumentError('vehicle_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableTransportVehicle,
        record,
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
      );
      _logger.d('更新运输车辆成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新运输车辆失败: $e');
      rethrow;
    }
  }

  Future<int> delete(String vehicleId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableTransportVehicle,
        {'is_deleted': 1},
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
      );
      _logger.d('删除运输车辆成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除运输车辆失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryById(String vehicleId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransportVehicle,
        where: 'vehicle_id = ? AND is_deleted = ?',
        whereArgs: [vehicleId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据车辆ID查询运输车辆失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportVehicle,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询运输车辆列表失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryByVehicleNo(String vehicleNo) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransportVehicle,
        where: 'vehicle_no = ? AND is_deleted = ?',
        whereArgs: [vehicleNo, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据车牌号查询运输车辆失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryList({
    String? keyword,
    int? status,
    String? vehicleType,
    String? ownerUnit,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final db = await _dbHelper.database;
      int offset = (page - 1) * pageSize;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (vehicle_no LIKE ? OR vehicle_model LIKE ? OR driver_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (vehicleType != null && vehicleType.isNotEmpty) {
        where += ' AND vehicle_type = ?';
        whereArgs.add(vehicleType);
      }

      if (ownerUnit != null && ownerUnit.isNotEmpty) {
        where += ' AND owner_unit = ?';
        whereArgs.add(ownerUnit);
      }

      return await db.query(
        DatabaseTables.tableTransportVehicle,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'create_time DESC',
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      _logger.e('分页查询运输车辆失败: $e');
      rethrow;
    }
  }

  Future<int> replaceAll(List<Map<String, dynamic>> records) async {
    try {
      final db = await _dbHelper.database;
      int count = 0;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableTransportVehicle);
        for (var record in records) {
          await txn.insert(DatabaseTables.tableTransportVehicle, record);
          count++;
        }
      });
      _logger.d('替换运输车辆数据成功，共插入: $count 条');
      return count;
    } catch (e) {
      _logger.e('替换运输车辆数据失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByStatus(int status) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportVehicle,
        where: 'status = ? AND is_deleted = ?',
        whereArgs: [status, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据状态查询运输车辆失败: $e');
      rethrow;
    }
  }

  Future<int> count({
    String? keyword,
    int? status,
    String? vehicleType,
    String? ownerUnit,
  }) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = ?';
      List<dynamic> whereArgs = [0];

      if (keyword != null && keyword.isNotEmpty) {
        where += ' AND (vehicle_no LIKE ? OR vehicle_model LIKE ? OR driver_name LIKE ?)';
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
        whereArgs.add('%$keyword%');
      }

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status);
      }

      if (vehicleType != null && vehicleType.isNotEmpty) {
        where += ' AND vehicle_type = ?';
        whereArgs.add(vehicleType);
      }

      if (ownerUnit != null && ownerUnit.isNotEmpty) {
        where += ' AND owner_unit = ?';
        whereArgs.add(ownerUnit);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseTables.tableTransportVehicle} WHERE $where',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('查询运输车辆数量失败: $e');
      rethrow;
    }
  }
}
