import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class TransportTrackDb {
  static final TransportTrackDb _instance = TransportTrackDb._internal();
  factory TransportTrackDb() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  TransportTrackDb._internal();

  Future<int> insert(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableTransportTrack, record);
      _logger.d('插入运输轨迹成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<int> update(Map<String, dynamic> record) async {
    try {
      final db = await _dbHelper.database;
      String? trackId = record['track_id'];
      if (trackId == null) {
        throw ArgumentError('track_id不能为空');
      }
      int count = await db.update(
        DatabaseTables.tableTransportTrack,
        record,
        where: 'track_id = ?',
        whereArgs: [trackId],
      );
      _logger.d('更新运输轨迹成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<int> delete(String trackId) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.update(
        DatabaseTables.tableTransportTrack,
        {'is_deleted': 1},
        where: 'track_id = ?',
        whereArgs: [trackId],
      );
      _logger.d('删除运输轨迹成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('删除运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryById(String trackId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransportTrack,
        where: 'track_id = ? AND is_deleted = ?',
        whereArgs: [trackId, 0],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('根据轨迹ID查询运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportTrack,
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('查询运输轨迹列表失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByTransferOrderId(String transferOrderId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportTrack,
        where: 'transfer_order_id = ? AND is_deleted = ?',
        whereArgs: [transferOrderId, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据转运单ID查询运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryByVehicleId(String vehicleId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportTrack,
        where: 'vehicle_id = ? AND is_deleted = ?',
        whereArgs: [vehicleId, 0],
        orderBy: 'create_time DESC',
      );
    } catch (e) {
      _logger.e('根据车辆ID查询运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> queryCurrentTrack(String vehicleId) async {
    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> result = await db.query(
        DatabaseTables.tableTransportTrack,
        where: 'vehicle_id = ? AND status = ? AND is_deleted = ?',
        whereArgs: [vehicleId, 1, 0],
        orderBy: 'start_time DESC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('查询车辆当前运输轨迹失败: $e');
      rethrow;
    }
  }

  Future<int> replaceAll(List<Map<String, dynamic>> records) async {
    try {
      final db = await _dbHelper.database;
      int count = 0;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.tableTransportTrack);
        for (var record in records) {
          await txn.insert(DatabaseTables.tableTransportTrack, record);
          count++;
        }
      });
      _logger.d('替换运输轨迹数据成功，共插入: $count 条');
      return count;
    } catch (e) {
      _logger.e('替换运输轨迹数据失败: $e');
      rethrow;
    }
  }

  Future<int> insertPoint(Map<String, dynamic> point) async {
    try {
      final db = await _dbHelper.database;
      int id = await db.insert(DatabaseTables.tableTransportTrackPoint, point);
      _logger.d('插入轨迹点成功: $id');
      return id;
    } catch (e) {
      _logger.e('插入轨迹点失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryPointsByTrackId(String trackId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportTrackPoint,
        where: 'track_id = ?',
        whereArgs: [trackId],
        orderBy: 'gps_time ASC',
      );
    } catch (e) {
      _logger.e('根据轨迹ID查询轨迹点失败: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryUnsyncedPoints() async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        DatabaseTables.tableTransportTrackPoint,
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'create_time ASC',
      );
    } catch (e) {
      _logger.e('查询待同步轨迹点失败: $e');
      rethrow;
    }
  }

  Future<int> updatePointSyncStatus(String pointId, int synced, {String? syncTime}) async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> values = {
        'synced': synced,
        if (syncTime != null) 'create_time': syncTime,
      };
      int count = await db.update(
        DatabaseTables.tableTransportTrackPoint,
        values,
        where: 'point_id = ?',
        whereArgs: [pointId],
      );
      _logger.d('更新轨迹点同步状态成功，影响行数: $count');
      return count;
    } catch (e) {
      _logger.e('更新轨迹点同步状态失败: $e');
      rethrow;
    }
  }

  Future<int> batchInsertPoints(List<Map<String, dynamic>> points) async {
    try {
      final db = await _dbHelper.database;
      int count = 0;
      await db.transaction((txn) async {
        for (var point in points) {
          await txn.insert(DatabaseTables.tableTransportTrackPoint, point);
          count++;
        }
      });
      _logger.d('批量插入轨迹点成功，共插入: $count 条');
      return count;
    } catch (e) {
      _logger.e('批量插入轨迹点失败: $e');
      rethrow;
    }
  }
}
