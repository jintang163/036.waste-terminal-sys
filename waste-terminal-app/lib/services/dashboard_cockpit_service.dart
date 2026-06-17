import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_tables.dart';

class DailyInboundStat {
  final String date;
  final int count;
  final double weight;

  DailyInboundStat({required this.date, this.count = 0, this.weight = 0});
}

class CategoryProportion {
  final String category;
  final String wasteCode;
  final double weight;
  final int count;

  CategoryProportion({
    required this.category,
    this.wasteCode = '',
    this.weight = 0,
    this.count = 0,
  });
}

class WarningStat {
  final int total;
  final int unhandled;
  final int level1Count;
  final int level2Count;
  final int level3Count;
  final List<Map<String, dynamic>> recentWarnings;

  WarningStat({
    this.total = 0,
    this.unhandled = 0,
    this.level1Count = 0,
    this.level2Count = 0,
    this.level3Count = 0,
    this.recentWarnings = const [],
  });
}

class ProductionPoint {
  final String name;
  final String? warehouseId;

  ProductionPoint({required this.name, this.warehouseId});
}

class DashboardOverview {
  final int totalInboundCount;
  final double totalInboundWeight;
  final int totalWarningCount;
  final int totalCategoryCount;

  DashboardOverview({
    this.totalInboundCount = 0,
    this.totalInboundWeight = 0,
    this.totalWarningCount = 0,
    this.totalCategoryCount = 0,
  });
}

class DashboardCockpitService {
  static final DashboardCockpitService _instance =
      DashboardCockpitService._internal();
  factory DashboardCockpitService() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Logger _logger = Logger();

  DashboardCockpitService._internal();

  String _monthStartDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _appendWarehouseFilter(
    String warehouseId,
    StringBuffer where,
    List<dynamic> args, {
    String tableAlias = '',
    String column = 'warehouse_id',
  }) {
    final prefix = tableAlias.isNotEmpty ? '$tableAlias.' : '';
    where.write(' AND ${prefix}$column = ?');
    args.add(warehouseId);
  }

  void _appendWarehouseFilterForWarning(
    String warehouseId,
    StringBuffer where,
    List<dynamic> args,
  ) {
    where.write(
      ' AND container_code IN (SELECT container_code FROM ${DatabaseTables.tableWasteInventory} WHERE warehouse_id = ? AND is_deleted = 0)',
    );
    args.add(warehouseId);
  }

  Future<DashboardOverview> getOverview({String? warehouseId}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _monthStartDate();

      final inWhere = StringBuffer('is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL');
      final inArgs = <dynamic>[startDate];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilter(warehouseId, inWhere, inArgs);
      }

      final inResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInRecord} WHERE $inWhere',
        inArgs,
      );

      final catWhere = StringBuffer('is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL');
      final catArgs = <dynamic>[startDate];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilter(warehouseId, catWhere, catArgs);
      }

      final catResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT waste_category) as cnt FROM ${DatabaseTables.tableWasteInRecord} WHERE $catWhere',
        catArgs,
      );

      final warnWhere = StringBuffer('is_deleted = 0 AND warning_time >= ?');
      final warnArgs = <dynamic>[startDate];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilterForWarning(warehouseId, warnWhere, warnArgs);
      }

      final warnResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $warnWhere',
        warnArgs,
      );

      return DashboardOverview(
        totalInboundCount: Sqflite.firstIntValue(inResult) ?? 0,
        totalInboundWeight:
            (inResult.first['total_weight'] as num?)?.toDouble() ?? 0,
        totalCategoryCount: Sqflite.firstIntValue(catResult) ?? 0,
        totalWarningCount: Sqflite.firstIntValue(warnResult) ?? 0,
      );
    } catch (e) {
      _logger.e('获取驾驶舱概览数据失败: $e');
      return DashboardOverview();
    }
  }

  Future<List<DailyInboundStat>> getDailyInboundTrend(
      {String? warehouseId}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _monthStartDate();

      final where = StringBuffer('is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL');
      final args = <dynamic>[startDate];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilter(warehouseId, where, args);
      }

      final result = await db.rawQuery(
        "SELECT DATE(in_time) as day, COUNT(*) as cnt, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInRecord} WHERE $where GROUP BY DATE(in_time) ORDER BY day ASC",
        args,
      );

      Map<String, DailyInboundStat> statMap = {};
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final diff = now.difference(firstDayOfMonth).inDays;
      for (int i = diff; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        statMap[key] = DailyInboundStat(date: key);
      }

      for (var row in result) {
        final day = row['day'] as String?;
        if (day != null && statMap.containsKey(day)) {
          statMap[day] = DailyInboundStat(
            date: day,
            count: (row['cnt'] as num?)?.toInt() ?? 0,
            weight: (row['total_weight'] as num?)?.toDouble() ?? 0,
          );
        }
      }

      return statMap.values.toList();
    } catch (e) {
      _logger.e('获取入库趋势数据失败: $e');
      return [];
    }
  }

  Future<List<CategoryProportion>> getCategoryProportion(
      {String? warehouseId}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _monthStartDate();

      final where = StringBuffer('is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL');
      final args = <dynamic>[startDate];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilter(warehouseId, where, args);
      }

      final result = await db.rawQuery(
        "SELECT COALESCE(waste_category, '未分类') as cat, waste_code, COUNT(*) as cnt, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInRecord} WHERE $where GROUP BY waste_category, waste_code ORDER BY total_weight DESC",
        args,
      );

      return result.map((row) {
        return CategoryProportion(
          category: row['cat'] as String? ?? '未分类',
          wasteCode: row['waste_code'] as String? ?? '',
          count: (row['cnt'] as num?)?.toInt() ?? 0,
          weight: (row['total_weight'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e) {
      _logger.e('获取危废类别占比数据失败: $e');
      return [];
    }
  }

  Future<WarningStat> getWarningStat({String? warehouseId}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _monthStartDate();

      final baseWhere = StringBuffer('is_deleted = 0 AND warning_time >= ?');
      final baseArgs = <dynamic>[startDate];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilterForWarning(warehouseId, baseWhere, baseArgs);
      }

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $baseWhere',
        baseArgs,
      );

      final unhandledWhere = StringBuffer(baseWhere.toString())..write(' AND status = 0');
      final unhandledResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $unhandledWhere',
        baseArgs,
      );

      final level1Where = StringBuffer(baseWhere.toString())..write(' AND warning_level = 1');
      final level1Result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $level1Where',
        baseArgs,
      );

      final level2Where = StringBuffer(baseWhere.toString())..write(' AND warning_level = 2');
      final level2Result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $level2Where',
        baseArgs,
      );

      final level3Where = StringBuffer(baseWhere.toString())..write(' AND warning_level = 3');
      final level3Result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $level3Where',
        baseArgs,
      );

      final recentResult = await db.query(
        DatabaseTables.tableWarningRecord,
        where: baseWhere.toString(),
        whereArgs: baseArgs,
        orderBy: 'warning_time DESC',
        limit: 5,
      );

      return WarningStat(
        total: Sqflite.firstIntValue(totalResult) ?? 0,
        unhandled: Sqflite.firstIntValue(unhandledResult) ?? 0,
        level1Count: Sqflite.firstIntValue(level1Result) ?? 0,
        level2Count: Sqflite.firstIntValue(level2Result) ?? 0,
        level3Count: Sqflite.firstIntValue(level3Result) ?? 0,
        recentWarnings: recentResult,
      );
    } catch (e) {
      _logger.e('获取预警统计失败: $e');
      return WarningStat();
    }
  }

  Future<List<ProductionPoint>> getProductionPoints() async {
    try {
      final db = await _dbHelper.database;

      final result = await db.rawQuery(
        'SELECT DISTINCT warehouse_id, warehouse FROM ${DatabaseTables.tableWasteInventory} WHERE is_deleted = 0 AND warehouse_id IS NOT NULL AND warehouse_id != "" ORDER BY warehouse',
      );

      final points = <ProductionPoint>[
        ProductionPoint(name: '全部产废点'),
      ];

      for (var row in result) {
        final name = row['warehouse'] as String?;
        final id = row['warehouse_id'] as String?;
        if (id != null && id.isNotEmpty) {
          points.add(ProductionPoint(
            name: (name != null && name.isNotEmpty) ? name : id,
            warehouseId: id,
          ));
        }
      }

      if (points.length <= 1) {
        final fallbackResult = await db.rawQuery(
          'SELECT DISTINCT warehouse_id, warehouse FROM ${DatabaseTables.tableWasteInRecord} WHERE is_deleted = 0 AND warehouse_id IS NOT NULL AND warehouse_id != "" ORDER BY warehouse',
        );

        for (var row in fallbackResult) {
          final name = row['warehouse'] as String?;
          final id = row['warehouse_id'] as String?;
          if (id != null && id.isNotEmpty) {
            points.add(ProductionPoint(
              name: (name != null && name.isNotEmpty) ? name : id,
              warehouseId: id,
            ));
          }
        }
      }

      return points;
    } catch (e) {
      _logger.e('获取产废点列表失败: $e');
      return [ProductionPoint(name: '全部产废点')];
    }
  }

  Future<List<Map<String, dynamic>>> getInboundDetailsByDate(
      String date, String? warehouseId) async {
    try {
      final db = await _dbHelper.database;

      final where = StringBuffer('is_deleted = 0 AND DATE(in_time) = ?');
      final args = <dynamic>[date];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilter(warehouseId, where, args);
      }

      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: where.toString(),
        whereArgs: args,
        orderBy: 'in_time DESC',
      );
    } catch (e) {
      _logger.e('按日期获取入库明细失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInboundDetailsByCategory(
      String category, String? warehouseId) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _monthStartDate();

      final where = StringBuffer('is_deleted = 0 AND in_time >= ? AND waste_category = ?');
      final args = <dynamic>[startDate, category];
      if (warehouseId != null && warehouseId.isNotEmpty) {
        _appendWarehouseFilter(warehouseId, where, args);
      }

      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: where.toString(),
        whereArgs: args,
        orderBy: 'in_time DESC',
      );
    } catch (e) {
      _logger.e('按类别获取入库明细失败: $e');
      return [];
    }
  }
}
