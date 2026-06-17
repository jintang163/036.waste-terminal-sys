import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../db/carbon_footprint_db.dart';
import '../models/carbon_footprint_record.dart';
import 'api_service.dart';

class CarbonFootprintService {
  static final CarbonFootprintService _instance =
      CarbonFootprintService._internal();
  factory CarbonFootprintService() => _instance;

  final CarbonFootprintDb _carbonFootprintDb = CarbonFootprintDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final _uuid = const Uuid();

  CarbonFootprintService._internal();

  static const Map<String, double> _transportEmissionFactors = {
    'truck': 0.302,
    'heavy_truck': 0.411,
    'train': 0.026,
    'ship': 0.058,
    'airplane': 0.602,
  };

  static const Map<String, Map<String, double>> _disposalEmissionFactors = {
    'HW01': {'incineration': 0.25, 'landfill': 0.12, 'recycling': 0.05},
    'HW02': {'incineration': 0.30, 'landfill': 0.15, 'recycling': 0.06},
    'HW03': {'incineration': 0.28, 'landfill': 0.13, 'recycling': 0.04},
    'HW04': {'incineration': 0.32, 'landfill': 0.18, 'recycling': 0.07},
    'HW05': {'incineration': 0.22, 'landfill': 0.10, 'recycling': 0.03},
    'HW06': {'incineration': 0.35, 'landfill': 0.20, 'recycling': 0.08},
    'HW07': {'incineration': 0.26, 'landfill': 0.14, 'recycling': 0.05},
    'HW08': {'incineration': 0.24, 'landfill': 0.11, 'recycling': 0.04},
    'HW09': {'incineration': 0.29, 'landfill': 0.16, 'recycling': 0.06},
    'HW10': {'incineration': 0.31, 'landfill': 0.17, 'recycling': 0.07},
    'HW11': {'incineration': 0.27, 'landfill': 0.13, 'recycling': 0.05},
    'HW12': {'incineration': 0.33, 'landfill': 0.19, 'recycling': 0.08},
    'HW13': {'incineration': 0.23, 'landfill': 0.10, 'recycling': 0.03},
    'HW14': {'incineration': 0.34, 'landfill': 0.20, 'recycling': 0.09},
    'HW15': {'incineration': 0.21, 'landfill': 0.09, 'recycling': 0.03},
    'HW16': {'incineration': 0.36, 'landfill': 0.21, 'recycling': 0.08},
    'HW17': {'incineration': 0.25, 'landfill': 0.12, 'recycling': 0.04},
    'HW18': {'incineration': 0.30, 'landfill': 0.15, 'recycling': 0.06},
    'HW19': {'incineration': 0.28, 'landfill': 0.14, 'recycling': 0.05},
    'HW20': {'incineration': 0.32, 'landfill': 0.17, 'recycling': 0.07},
    'HW21': {'incineration': 0.26, 'landfill': 0.13, 'recycling': 0.05},
    'HW22': {'incineration': 0.29, 'landfill': 0.15, 'recycling': 0.06},
    'HW23': {'incineration': 0.27, 'landfill': 0.14, 'recycling': 0.05},
    'HW24': {'incineration': 0.31, 'landfill': 0.17, 'recycling': 0.07},
    'HW25': {'incineration': 0.24, 'landfill': 0.11, 'recycling': 0.04},
    'HW26': {'incineration': 0.30, 'landfill': 0.16, 'recycling': 0.06},
    'HW27': {'incineration': 0.28, 'landfill': 0.14, 'recycling': 0.05},
    'HW28': {'incineration': 0.32, 'landfill': 0.17, 'recycling': 0.07},
    'HW29': {'incineration': 0.25, 'landfill': 0.12, 'recycling': 0.04},
    'HW30': {'incineration': 0.33, 'landfill': 0.18, 'recycling': 0.08},
    'HW31': {'incineration': 0.26, 'landfill': 0.13, 'recycling': 0.05},
    'HW32': {'incineration': 0.29, 'landfill': 0.15, 'recycling': 0.06},
    'HW33': {'incineration': 0.27, 'landfill': 0.13, 'recycling': 0.05},
    'HW34': {'incineration': 0.31, 'landfill': 0.16, 'recycling': 0.07},
    'HW35': {'incineration': 0.24, 'landfill': 0.11, 'recycling': 0.04},
    'HW36': {'incineration': 0.30, 'landfill': 0.16, 'recycling': 0.06},
    'HW37': {'incineration': 0.28, 'landfill': 0.14, 'recycling': 0.05},
    'HW38': {'incineration': 0.32, 'landfill': 0.18, 'recycling': 0.07},
    'HW39': {'incineration': 0.25, 'landfill': 0.12, 'recycling': 0.04},
    'HW40': {'incineration': 0.34, 'landfill': 0.19, 'recycling': 0.08},
    'HW41': {'incineration': 0.26, 'landfill': 0.13, 'recycling': 0.05},
    'HW42': {'incineration': 0.29, 'landfill': 0.15, 'recycling': 0.06},
    'HW43': {'incineration': 0.27, 'landfill': 0.14, 'recycling': 0.05},
    'HW44': {'incineration': 0.31, 'landfill': 0.17, 'recycling': 0.07},
    'HW45': {'incineration': 0.24, 'landfill': 0.11, 'recycling': 0.04},
    'HW46': {'incineration': 0.30, 'landfill': 0.16, 'recycling': 0.06},
    'HW47': {'incineration': 0.28, 'landfill': 0.14, 'recycling': 0.05},
    'HW48': {'incineration': 0.32, 'landfill': 0.17, 'recycling': 0.07},
    'HW49': {'incineration': 0.25, 'landfill': 0.12, 'recycling': 0.04},
    'HW50': {'incineration': 0.35, 'landfill': 0.20, 'recycling': 0.08},
  };

  static const Map<String, String> _transportModeNames = {
    'truck': '轻型货车',
    'heavy_truck': '重型货车',
    'train': '铁路运输',
    'ship': '水路运输',
    'airplane': '航空运输',
  };

  static const Map<String, String> _disposalMethodNames = {
    'incineration': '焚烧处置',
    'landfill': '填埋处置',
    'recycling': '回收利用',
  };

  static const List<String> wasteCategories = [
    'HW01',
    'HW02',
    'HW03',
    'HW04',
    'HW05',
    'HW06',
    'HW07',
    'HW08',
    'HW09',
    'HW10',
    'HW11',
    'HW12',
    'HW13',
    'HW14',
    'HW15',
    'HW16',
    'HW17',
    'HW18',
    'HW19',
    'HW20',
    'HW21',
    'HW22',
    'HW23',
    'HW24',
    'HW25',
    'HW26',
    'HW27',
    'HW28',
    'HW29',
    'HW30',
    'HW31',
    'HW32',
    'HW33',
    'HW34',
    'HW35',
    'HW36',
    'HW37',
    'HW38',
    'HW39',
    'HW40',
    'HW41',
    'HW42',
    'HW43',
    'HW44',
    'HW45',
    'HW46',
    'HW47',
    'HW48',
    'HW49',
    'HW50',
  ];

  static const Map<String, String> wasteCategoryNames = {
    'HW01': '医院临床废物',
    'HW02': '医药废物',
    'HW03': '废药物、药品',
    'HW04': '农药废物',
    'HW05': '木材防腐剂废物',
    'HW06': '废有机溶剂与含有机溶剂废物',
    'HW07': '热处理含氰废物',
    'HW08': '废矿物油与含矿物油废物',
    'HW09': '油/水、烃/水混合物或乳化液',
    'HW10': '多氯（溴）联苯类废物',
    'HW11': '精（蒸）馏残渣',
    'HW12': '染料、涂料废物',
    'HW13': '有机树脂类废物',
    'HW14': '新化学物质废物',
    'HW15': '爆炸性废物',
    'HW16': '感光材料废物',
    'HW17': '表面处理废物',
    'HW18': '焚烧处置残渣',
    'HW19': '含金属羰基化合物废物',
    'HW20': '含铍废物',
    'HW21': '含铬废物',
    'HW22': '含铜废物',
    'HW23': '含锌废物',
    'HW24': '含砷废物',
    'HW25': '含硒废物',
    'HW26': '含镉废物',
    'HW27': '含锑废物',
    'HW28': '含碲废物',
    'HW29': '含汞废物',
    'HW30': '含铊废物',
    'HW31': '含铅废物',
    'HW32': '无机氟化物废物',
    'HW33': '无机氰化物废物',
    'HW34': '废酸',
    'HW35': '废碱',
    'HW36': '石棉废物',
    'HW37': '有机磷化合物废物',
    'HW38': '有机氰化物废物',
    'HW39': '含酚废物',
    'HW40': '含醚废物',
    'HW41': '废卤化有机溶剂',
    'HW42': '废有机溶剂',
    'HW43': '含多氯苯并呋喃类废物',
    'HW44': '含多氯苯并二恶英废物',
    'HW45': '含有机卤化物废物',
    'HW46': '含镍废物',
    'HW47': '含钡废物',
    'HW48': '有色金属冶炼废物',
    'HW49': '其他废物',
    'HW50': '废催化剂',
  };

  static List<String> get transportModes =>
      _transportEmissionFactors.keys.toList();

  static List<String> get disposalMethods => ['incineration', 'landfill', 'recycling'];

  static String getTransportModeName(String mode) {
    return _transportModeNames[mode] ?? mode;
  }

  static String getDisposalMethodName(String method) {
    return _disposalMethodNames[method] ?? method;
  }

  static String getWasteCategoryName(String category) {
    return wasteCategoryNames[category] ?? category;
  }

  double getTransportEmissionFactor(String transportMode) {
    return _transportEmissionFactors[transportMode] ?? 0.302;
  }

  double getDisposalEmissionFactor(String wasteCategory, String disposalMethod) {
    final categoryFactors = _disposalEmissionFactors[wasteCategory];
    if (categoryFactors != null) {
      return categoryFactors[disposalMethod] ?? 0.25;
    }
    switch (disposalMethod) {
      case 'incineration':
        return 0.28;
      case 'landfill':
        return 0.14;
      case 'recycling':
        return 0.05;
      default:
        return 0.25;
    }
  }

  CarbonFootprintCalculationResult calculate({
    required String wasteCategory,
    required double weight,
    required double transportDistance,
    required String transportMode,
    required String disposalMethod,
  }) {
    final transportFactor = getTransportEmissionFactor(transportMode);
    final disposalFactor = getDisposalEmissionFactor(wasteCategory, disposalMethod);

    final transportEmission = transportDistance * weight * transportFactor;
    final disposalEmission = weight * disposalFactor;
    final totalEmission = transportEmission + disposalEmission;

    return CarbonFootprintCalculationResult(
      transportEmission: transportEmission,
      disposalEmission: disposalEmission,
      totalEmission: totalEmission,
      unit: 'kgCO₂e',
      transportFactor: transportFactor,
      disposalFactor: disposalFactor,
    );
  }

  Future<CarbonFootprintRecord> createAndSaveRecord({
    String? wasteCode,
    String? wasteName,
    required String wasteCategory,
    required double weight,
    String weightUnit = 'kg',
    required double transportDistance,
    String transportDistanceUnit = 'km',
    required String transportMode,
    required String disposalMethod,
    String? transferOrderId,
    String? transferOrderNo,
    String? operator,
    String? operatorId,
    String? remark,
  }) async {
    try {
      final calculation = calculate(
        wasteCategory: wasteCategory,
        weight: weight,
        transportDistance: transportDistance,
        transportMode: transportMode,
        disposalMethod: disposalMethod,
      );

      final now = DateTime.now();
      final offlineId = _uuid.v4();

      final record = CarbonFootprintRecord(
        offlineId: offlineId,
        wasteCode: wasteCode,
        wasteName: wasteName,
        wasteCategory: wasteCategory,
        weight: weight,
        weightUnit: weightUnit,
        transportDistance: transportDistance,
        transportDistanceUnit: transportDistanceUnit,
        transportMode: transportMode,
        disposalMethod: disposalMethod,
        transportEmission: calculation.transportEmission,
        disposalEmission: calculation.disposalEmission,
        totalEmission: calculation.totalEmission,
        emissionUnit: calculation.unit,
        transferOrderId: transferOrderId,
        transferOrderNo: transferOrderNo,
        operator: operator,
        operatorId: operatorId,
        remark: remark,
        syncStatus: 0,
        recordTime: now,
        createTime: now,
        updateTime: now,
        isDeleted: 0,
      );

      final id = await _carbonFootprintDb.insert(record.toJson());
      _logger.d('创建碳足迹记录成功: $id');

      return record.copyWith(id: id);
    } catch (e) {
      _logger.e('创建碳足迹记录失败: $e');
      rethrow;
    }
  }

  Future<List<CarbonFootprintRecord>> getRecords({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? wasteCategory,
    String? disposalMethod,
    DateTime? startTime,
    DateTime? endTime,
    int? syncStatus,
  }) async {
    try {
      final results = await _carbonFootprintDb.queryWithPagination(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        wasteCategory: wasteCategory,
        disposalMethod: disposalMethod,
        startTime: startTime,
        endTime: endTime,
        syncStatus: syncStatus,
      );
      return results.map((e) => CarbonFootprintRecord.fromJson(e)).toList();
    } catch (e) {
      _logger.e('获取碳足迹记录失败: $e');
      return [];
    }
  }

  Future<int> getRecordCount({
    String? keyword,
    String? wasteCategory,
    String? disposalMethod,
    DateTime? startTime,
    DateTime? endTime,
    int? syncStatus,
  }) async {
    try {
      return await _carbonFootprintDb.queryCount(
        keyword: keyword,
        wasteCategory: wasteCategory,
        disposalMethod: disposalMethod,
        startTime: startTime,
        endTime: endTime,
        syncStatus: syncStatus,
      );
    } catch (e) {
      _logger.e('获取碳足迹记录数量失败: $e');
      return 0;
    }
  }

  Future<CarbonFootprintRecord?> getRecordById(int id) async {
    try {
      final result = await _carbonFootprintDb.queryById(id);
      return result != null ? CarbonFootprintRecord.fromJson(result) : null;
    } catch (e) {
      _logger.e('根据ID获取碳足迹记录失败: $e');
      return null;
    }
  }

  Future<List<CarbonFootprintRecord>> getRecordsByTransferOrderNo(
      String transferOrderNo) async {
    try {
      final results =
          await _carbonFootprintDb.queryByTransferOrderNo(transferOrderNo);
      return results.map((e) => CarbonFootprintRecord.fromJson(e)).toList();
    } catch (e) {
      _logger.e('根据转运联单号获取碳足迹记录失败: $e');
      return [];
    }
  }

  Future<List<CarbonFootprintRecord>> getUnsyncedRecords() async {
    try {
      final results = await _carbonFootprintDb.queryUnsynced();
      return results.map((e) => CarbonFootprintRecord.fromJson(e)).toList();
    } catch (e) {
      _logger.e('获取未同步碳足迹记录失败: $e');
      return [];
    }
  }

  Future<bool> syncRecord(int id) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.w('无网络，无法同步碳足迹记录');
        return false;
      }

      final record = await getRecordById(id);
      if (record == null) {
        _logger.w('未找到碳足迹记录: $id');
        return false;
      }

      await _carbonFootprintDb.updateSyncStatus(id, 1);
      _logger.d('碳足迹记录同步成功: $id');
      return true;
    } catch (e) {
      _logger.e('同步碳足迹记录失败: $e');
      return false;
    }
  }

  Future<int> syncAllUnsynced() async {
    try {
      final unsynced = await getUnsyncedRecords();
      if (unsynced.isEmpty) return 0;

      int successCount = 0;
      for (var record in unsynced) {
        if (record.id != null) {
          final success = await syncRecord(record.id!);
          if (success) successCount++;
        }
      }
      _logger.i('碳足迹记录同步完成，成功: $successCount/${unsynced.length}');
      return successCount;
    } catch (e) {
      _logger.e('批量同步碳足迹记录失败: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      return await _carbonFootprintDb.getStatistics(
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取碳足迹统计失败: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      return await _carbonFootprintDb.getCategoryStatistics(
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取分类碳足迹统计失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDailyStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      return await _carbonFootprintDb.getDailyStatistics(
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _logger.e('获取每日碳足迹统计失败: $e');
      return [];
    }
  }

  Future<bool> deleteRecord(int id) async {
    try {
      await _carbonFootprintDb.deleteById(id);
      return true;
    } catch (e) {
      _logger.e('删除碳足迹记录失败: $e');
      return false;
    }
  }
}

class CarbonFootprintCalculationResult {
  final double transportEmission;
  final double disposalEmission;
  final double totalEmission;
  final String unit;
  final double transportFactor;
  final double disposalFactor;

  CarbonFootprintCalculationResult({
    required this.transportEmission,
    required this.disposalEmission,
    required this.totalEmission,
    required this.unit,
    required this.transportFactor,
    required this.disposalFactor,
  });
}
