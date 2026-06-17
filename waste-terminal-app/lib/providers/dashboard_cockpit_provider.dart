import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/dashboard_cockpit_service.dart';

enum DashboardState { idle, loading, success, error }

class DashboardCockpitProvider extends ChangeNotifier {
  final DashboardCockpitService _service = DashboardCockpitService();
  final Logger _logger = Logger();

  DashboardState _state = DashboardState.idle;
  String? _errorMessage;

  DashboardOverview? _overview;
  List<DailyInboundStat> _dailyTrend = [];
  List<CategoryProportion> _categoryProportion = [];
  WarningStat? _warningStat;
  List<ProductionPoint> _productionPoints = [];

  String? _selectedWarehouse;
  int _selectedPointIndex = 0;

  List<DailyInboundStat> _inboundDetails = [];
  bool _showingDetails = false;
  String _detailTitle = '';

  DashboardState get state => _state;
  String? get errorMessage => _errorMessage;
  DashboardOverview? get overview => _overview;
  List<DailyInboundStat> get dailyTrend => _dailyTrend;
  List<CategoryProportion> get categoryProportion => _categoryProportion;
  WarningStat? get warningStat => _warningStat;
  List<ProductionPoint> get productionPoints => _productionPoints;
  String? get selectedWarehouse => _selectedWarehouse;
  int get selectedPointIndex => _selectedPointIndex;
  List<DailyInboundStat> get inboundDetails => _inboundDetails;
  bool get showingDetails => _showingDetails;
  String get detailTitle => _detailTitle;
  bool get isLoading => _state == DashboardState.loading;

  Future<void> init() async {
    await loadProductionPoints();
    await loadAllData();
  }

  Future<void> loadProductionPoints() async {
    try {
      _productionPoints = await _service.getProductionPoints();
      notifyListeners();
    } catch (e) {
      _logger.e('加载产废点列表失败: $e');
    }
  }

  Future<void> loadAllData() async {
    _state = DashboardState.loading;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getOverview(warehouse: _selectedWarehouse),
        _service.getDailyInboundTrend(warehouse: _selectedWarehouse),
        _service.getCategoryProportion(warehouse: _selectedWarehouse),
        _service.getWarningStat(warehouse: _selectedWarehouse),
      ]);

      _overview = results[0] as DashboardOverview;
      _dailyTrend = results[1] as List<DailyInboundStat>;
      _categoryProportion = results[2] as List<CategoryProportion>;
      _warningStat = results[3] as WarningStat;

      _state = DashboardState.success;
      _errorMessage = null;
    } catch (e) {
      _state = DashboardState.error;
      _errorMessage = e.toString();
      _logger.e('加载驾驶舱数据失败: $e');
    }

    notifyListeners();
  }

  Future<void> switchProductionPoint(int index) async {
    if (index < 0 || index >= _productionPoints.length) return;

    _selectedPointIndex = index;
    final point = _productionPoints[index];
    _selectedWarehouse = point.id;

    notifyListeners();
    await loadAllData();
  }

  Future<void> loadInboundDetailsByDate(String date) async {
    try {
      final records =
          await _service.getInboundDetailsByDate(date, _selectedWarehouse);
      _inboundDetails = [];
      _detailTitle = date;
      _showingDetails = true;
      notifyListeners();
    } catch (e) {
      _logger.e('加载入库明细失败: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getInboundDetailsByDate(
      String date) async {
    try {
      return await _service.getInboundDetailsByDate(date, _selectedWarehouse);
    } catch (e) {
      _logger.e('加载日期入库明细失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInboundDetailsByCategory(
      String category) async {
    try {
      return await _service.getInboundDetailsByCategory(
          category, _selectedWarehouse);
    } catch (e) {
      _logger.e('加载类别入库明细失败: $e');
      return [];
    }
  }

  void clearDetails() {
    _showingDetails = false;
    _detailTitle = '';
    _inboundDetails = [];
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadProductionPoints();
    await loadAllData();
  }
}
