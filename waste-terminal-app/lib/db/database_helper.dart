import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

import 'database_tables.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;
  final Logger _logger = Logger();

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, DatabaseTables.dbName);

    _logger.d('数据库路径: $path');

    return await openDatabase(
      path,
      version: DatabaseTables.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    _logger.i('创建数据库，版本: $version');
    Batch batch = db.batch();
    for (String sql in DatabaseTables.getAllCreateTableSql()) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
    _logger.i('数据库表创建完成');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.i('数据库升级: $oldVersion -> $newVersion');
    if (oldVersion < 2) {
      Batch batch = db.batch();
      batch.execute(DatabaseTables.createTableUserFace);
      batch.execute(DatabaseTables.createTableFaceAuthRecord);
      await batch.commit(noResult: true);
      _logger.i('数据库升级到v2完成，已添加人脸相关表');
    }
    if (oldVersion < 3) {
      Batch batch = db.batch();
      batch.execute('ALTER TABLE ${DatabaseTables.tableWasteInRecord} ADD COLUMN face_auth_id TEXT');
      batch.execute('ALTER TABLE ${DatabaseTables.tableWasteInRecord} ADD COLUMN face_id TEXT');
      batch.execute('ALTER TABLE ${DatabaseTables.tableWasteInRecord} ADD COLUMN operator_face_image TEXT');
      batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN face_auth_id TEXT');
      batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN face_id TEXT');
      batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN operator_face_image TEXT');
      await batch.commit(noResult: true);
      _logger.i('数据库升级到v3完成，已添加入库出库人脸追溯字段');
    }
    if (oldVersion < 4) {
      Batch batch = db.batch();
      batch.execute('ALTER TABLE ${DatabaseTables.tableFaceAuthRecord} ADD COLUMN liveness_score REAL');
      batch.execute('ALTER TABLE ${DatabaseTables.tableFaceAuthRecord} ADD COLUMN face_quality INTEGER');
      batch.execute('ALTER TABLE ${DatabaseTables.tableFaceAuthRecord} ADD COLUMN sync_status INTEGER DEFAULT 0');
      batch.execute('ALTER TABLE ${DatabaseTables.tableFaceAuthRecord} ADD COLUMN sync_time TEXT');
      await batch.commit(noResult: true);
      _logger.i('数据库升级到v4完成，已添加活体检测和同步字段');
    }
    if (oldVersion < 5) {
      Batch batch = db.batch();
      batch.execute(DatabaseTables.createTableTransportVehicle);
      batch.execute(DatabaseTables.createTableTransportDriver);
      batch.execute(DatabaseTables.createTableTransportTrack);
      batch.execute(DatabaseTables.createTableTransportTrackPoint);
      await batch.commit(noResult: true);
      _logger.i('数据库升级到v5完成，已添加运输车辆/驾驶员/轨迹相关表');
    }
    if (oldVersion < 6) {
      Batch batch = db.batch();
      try {
        batch.execute(
          'ALTER TABLE ${DatabaseTables.tableTransportTrack} ADD COLUMN expected_duration_hours REAL DEFAULT 24.0',
        );
      } catch (e) {
        _logger.w('添加列 expected_duration_hours 失败(可能已存在): $e');
      }
      try {
        batch.execute(
          'ALTER TABLE ${DatabaseTables.tableTransportTrack} ADD COLUMN expected_arrival_time TEXT',
        );
      } catch (e) {
        _logger.w('添加列 expected_arrival_time 失败(可能已存在): $e');
      }
      await batch.commit(noResult: true);
      _logger.i('数据库升级到v6完成，已添加运输预计到达时长字段');
    }
    if (oldVersion < 7) {
      Batch batch = db.batch();
      try {
        batch.execute(DatabaseTables.createTableWasteOutReview);
      } catch (e) {
        _logger.w('创建表 waste_out_review 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN review_status INTEGER DEFAULT 0');
      } catch (e) {
        _logger.w('添加列 review_status 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN review_time TEXT');
      } catch (e) {
        _logger.w('添加列 review_time 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN review_remark TEXT');
      } catch (e) {
        _logger.w('添加列 review_remark 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN reviewer_id INTEGER');
      } catch (e) {
        _logger.w('添加列 reviewer_id 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN reviewer_name TEXT');
      } catch (e) {
        _logger.w('添加列 reviewer_name 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN reviewer_face_auth_id TEXT');
      } catch (e) {
        _logger.w('添加列 reviewer_face_auth_id 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN reviewer_face_id TEXT');
      } catch (e) {
        _logger.w('添加列 reviewer_face_id 失败(可能已存在): $e');
      }
      try {
        batch.execute('ALTER TABLE ${DatabaseTables.tableWasteOutRecord} ADD COLUMN reviewer_face_image TEXT');
      } catch (e) {
        _logger.w('添加列 reviewer_face_image 失败(可能已存在): $e');
      }
      await batch.commit(noResult: true);
      _logger.i('数据库升级到v7完成，已添加出库双人复核相关表和字段');
    }
  }

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    _logger.w('数据库降级: $oldVersion -> $newVersion');
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, DatabaseTables.dbName);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.i('数据库已关闭');
    }
  }

  Future<void> deleteDatabase() async {
    String path = await getDatabasePath();
    if (await File(path).exists()) {
      await File(path).delete();
      _database = null;
      _logger.i('数据库已删除');
    }
  }

  Future<int> getTableCount(String tableName) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearTable(String tableName) async {
    final db = await database;
    await db.delete(tableName);
    _logger.d('清空表: $tableName');
  }

  Future<List<Map<String, dynamic>>> queryAll(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  Future<List<Map<String, dynamic>>> queryById(
    String tableName,
    int id, {
    String idColumn = 'id',
  }) async {
    final db = await database;
    return await db.query(
      tableName,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  Future<int> insert(String tableName, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(tableName, values);
  }

  Future<int> update(
    String tableName,
    Map<String, dynamic> values, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(tableName, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String tableName, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(tableName, where: where, whereArgs: whereArgs);
  }

  Future<void> batchInsert(
    String tableName,
    List<Map<String, dynamic>> valuesList,
  ) async {
    final db = await database;
    Batch batch = db.batch();
    for (var values in valuesList) {
      batch.insert(tableName, values);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> queryWithPagination(
    String tableName, {
    int page = 1,
    int pageSize = 20,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    int offset = (page - 1) * pageSize;
    return await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: pageSize,
      offset: offset,
    );
  }

  Future<int> queryCount(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
