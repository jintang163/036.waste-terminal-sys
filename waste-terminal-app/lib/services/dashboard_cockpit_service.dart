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
  final String? id;

  ProductionPoint({required this.name, this.id});
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

  String _dateRangeStart() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }

  String _dateRangeEnd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DashboardOverview> getOverview({String? warehouse}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _dateRangeStart();

      String inWhere =
          'is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL';
      List<dynamic> inArgs = [startDate];
      if (warehouse != null && warehouse.isNotEmpty) {
        inWhere += ' AND warehouse = ?';
        inArgs.add(warehouse);
      }

      final inResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInRecord} WHERE $inWhere',
        inArgs,
      );

      String catWhere =
          'is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL';
      List<dynamic> catArgs = [startDate];
      if (warehouse != null && warehouse.isNotEmpty) {
        catWhere += ' AND warehouse = ?';
        catArgs.add(warehouse);
      }

      final catResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT waste_category) as cnt FROM ${DatabaseTables.tableWasteInRecord} WHERE $catWhere',
        catArgs,
      );

      String warnWhere = 'is_deleted = 0';
      List<dynamic> warnArgs = [];
      if (warehouse != null && warehouse.isNotEmpty) {
        warnWhere += ' AND container_code IN (SELECT container_code FROM ${DatabaseTables.tableWasteInventory} WHERE warehouse = ? AND is_deleted = 0)';
        warnArgs.add(warehouse);
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
      {String? warehouse}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _dateRangeStart();

      String where =
          'is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL';
      List<dynamic> args = [startDate];
      if (warehouse != null && warehouse.isNotEmpty) {
        where += ' AND warehouse = ?';
        args.add(warehouse);
      }

      final result = await db.rawQuery(
        "SELECT DATE(in_time) as day, COUNT(*) as cnt, COALESCE(SUM(weight), 0) as total_weight FROM ${DatabaseTables.tableWasteInRecord} WHERE $where GROUP BY DATE(in_time) ORDER BY day ASC",
        args,
      );

      Map<String, DailyInboundStat> statMap = {};
      final now = DateTime.now();
      for (int i = 30; i >= 0; i--) {
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
      {String? warehouse}) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _dateRangeStart();

      String where =
          'is_deleted = 0 AND in_time >= ? AND in_time IS NOT NULL';
      List<dynamic> args = [startDate];
      if (warehouse != null && warehouse.isNotEmpty) {
        where += ' AND warehouse = ?';
        args.add(warehouse);
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

  Future<WarningStat> getWarningStat({String? warehouse}) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = 0';
      List<dynamic> args = [];
      if (warehouse != null && warehouse.isNotEmpty) {
        where +=
            ' AND container_code IN (SELECT container_code FROM ${DatabaseTables.tableWasteInventory} WHERE warehouse = ? AND is_deleted = 0)';
        args.add(warehouse);
      }

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $where',
        args,
      );

      String unhandledWhere = '$where AND status = 0';
      final unhandledResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $unhandledWhere',
        args,
      );

      final level1Result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $where AND warning_level = 1',
        args,
      );
      final level2Result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $where AND warning_level = 2',
        args,
      );
      final level3Result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWarningRecord} WHERE $where AND warning_level = 3',
        args,
      );

      String recentWhere = '$where ORDER BY warning_time DESC LIMIT 5';
      final recentResult = await db.query(
        DatabaseTables.tableWarningRecord,
        where: where.isNotEmpty ? 'is_deleted = 0' : null,
        whereArgs: args.isNotEmpty ? args : null,
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
        'SELECT DISTINCT warehouse FROM ${DatabaseTables.tableWasteInRecord} WHERE is_deleted = 0 AND warehouse IS NOT NULL AND warehouse != "" ORDER BY warehouse',
      );

      final points = <ProductionPoint>[
        ProductionPoint(name: '全部产废点'),
      ];

      for (var row in result) {
        final name = row['warehouse'] as String?;
        if (name != null && name.isNotEmpty) {
          points.add(ProductionPoint(name: name, id: name));
        }
      }

      return points;
    } catch (e) {
      _logger.e('获取产废点列表失败: $e');
      return [ProductionPoint(name: '全部产废点')];
    }
  }

  Future<List<Map<String, dynamic>>> getInboundDetailsByDate(
      String date, String? warehouse) async {
    try {
      final db = await _dbHelper.database;

      String where = 'is_deleted = 0 AND DATE(in_time) = ?';
      List<dynamic> args = [date];
      if (warehouse != null && warehouse.isNotEmpty) {
        where += ' AND warehouse = ?';
        args.add(warehouse);
      }

      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: where,
        whereArgs: args,
        orderBy: 'in_time DESC',
      );
    } catch (e) {
      _logger.e('按日期获取入库明细失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInboundDetailsByCategory(
      String category, String? warehouse) async {
    try {
      final db = await _dbHelper.database;
      final startDate = _dateRangeStart();

      String where =
          'is_deleted = 0 AND in_time >= ? AND waste_category = ?';
      List<dynamic> args = [startDate, category];
      if (warehouse != null && warehouse.isNotEmpty) {
        where += ' AND warehouse = ?';
        args.add(warehouse);
      }

      return await db.query(
        DatabaseTables.tableWasteInRecord,
        where: where,
        whereArgs: args,
        orderBy: 'in_time DESC',
      );
    } catch (e) {
      _logger.e('按类别获取入库明细失败: $e');
      return [];
    }
  }
}
