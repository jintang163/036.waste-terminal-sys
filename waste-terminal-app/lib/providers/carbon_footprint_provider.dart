import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../models/carbon_footprint_record.dart';
import '../services/carbon_footprint_service.dart';

enum CarbonFootprintState { idle, loading, success, error }

class CarbonFootprintProvider extends ChangeNotifier {
  final CarbonFootprintService _service = CarbonFootprintService();
  final Logger _logger = Logger();

  List<CarbonFootprintRecord> _records = [];
  CarbonFootprintState _state = CarbonFootprintState.idle;
  String? _errorMessage;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  int _totalCount = 0;

  String? _keyword;
  String? _wasteCategory;
  String? _disposalMethod;
  DateTime? _startTime;
  DateTime? _endTime;
  int? _syncStatus;

  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _categoryStats = [];
  List<Map<String, dynamic>> _dailyStats = [];

  double? _totalEmission;
  double? _transportEmission;
  double? _disposalEmission;
  double? _totalWeight;
  int _recordCount = 0;

  CarbonFootprintCalculationResult? _calculationResult;

  String? _selectedWasteCategory;
  String? _selectedTransportMode = 'heavy_truck';
  String? _selectedDisposalMethod = 'incineration';

  List<CarbonFootprintRecord> get records => _records;
  CarbonFootprintState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == CarbonFootprintState.loading;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;

  Map<String, dynamic>? get statistics => _statistics;
  List<Map<String, dynamic>> get categoryStats => _categoryStats;
  List<Map<String, dynamic>> get dailyStats => _dailyStats;

  double? get totalEmission => _totalEmission;
  double? get transportEmission => _transportEmission;
  double? get disposalEmission => _disposalEmission;
  double? get totalWeight => _totalWeight;
  int get recordCount => _recordCount;

  CarbonFootprintCalculationResult? get calculationResult => _calculationResult;

  String? get selectedWasteCategory => _selectedWasteCategory;
  String? get selectedTransportMode => _selectedTransportMode;
  String? get selectedDisposalMethod => _selectedDisposalMethod;

  List<String> get transportModes => CarbonFootprintService.transportModes;
  List<String> get disposalMethods => CarbonFootprintService.disposalMethods;
  List<String> get wasteCategories => CarbonFootprintService.wasteCategories;

  void setSearchParams({
    String? keyword,
    String? wasteCategory,
    String? disposalMethod,
    DateTime? startTime,
    DateTime? endTime,
    int? syncStatus,
  }) {
    _keyword = keyword;
    _wasteCategory = wasteCategory;
    _disposalMethod = disposalMethod;
    _startTime = startTime;
    _endTime = endTime;
    _syncStatus = syncStatus;
    notifyListeners();
  }

  void setSelectedWasteCategory(String? category) {
    _selectedWasteCategory = category;
    _calculationResult = null;
    notifyListeners();
  }

  void setSelectedTransportMode(String? mode) {
    _selectedTransportMode = mode;
    _calculationResult = null;
    notifyListeners();
  }

  void setSelectedDisposalMethod(String? method) {
    _selectedDisposalMethod = method;
    _calculationResult = null;
    notifyListeners();
  }

  void calculatePreview({
    required double weight,
    required double transportDistance,
  }) {
    if (_selectedWasteCategory == null || _selectedTransportMode == null || _selectedDisposalMethod == null) {
      return;
    }

    _calculationResult = _service.calculate(
      wasteCategory: _selectedWasteCategory!,
      weight: weight,
      transportDistance: transportDistance,
      transportMode: _selectedTransportMode!,
      disposalMethod: _selectedDisposalMethod!,
    );
    notifyListeners();
  }

  void clearCalculation() {
    _calculationResult = null;
    notifyListeners();
  }

  Future<void> loadRecords({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _records = [];
    }

    if (!_hasMore && !refresh) {
      return;
    }

    _state = CarbonFootprintState.loading;
    notifyListeners();

    try {
      final newRecords = await _service.getRecords(
        page: _currentPage,
        pageSize: _pageSize,
        keyword: _keyword,
        wasteCategory: _wasteCategory,
        disposalMethod: _disposalMethod,
        startTime: _startTime,
        endTime: _endTime,
        syncStatus: _syncStatus,
      );

      if (refresh) {
        _records = newRecords;
      } else {
        _records.addAll(newRecords);
      }

      _totalCount = await _service.getRecordCount(
        keyword: _keyword,
        wasteCategory: _wasteCategory,
        disposalMethod: _disposalMethod,
        startTime: _startTime,
        endTime: _endTime,
        syncStatus: _syncStatus,
      );

      _hasMore = newRecords.length >= _pageSize;
      if (_hasMore) {
        _currentPage++;
      }

      _state = CarbonFootprintState.success;
      _errorMessage = null;
    } catch (e) {
      _state = CarbonFootprintState.error;
      _errorMessage = e.toString();
      _logger.e('加载碳足迹记录失败: $e');
    }

    notifyListeners();
  }

  Future<void> loadStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    _state = CarbonFootprintState.loading;
    notifyListeners();

    try {
      _statistics = await _service.getStatistics(
        startTime: startTime,
        endTime: endTime,
      );

      _totalEmission = (_statistics?['total_emission'] as num?)?.toDouble();
      _transportEmission = (_statistics?['transport_emission'] as num?)?.toDouble();
      _disposalEmission = (_statistics?['disposal_emission'] as num?)?.toDouble();
      _totalWeight = (_statistics?['total_weight'] as num?)?.toDouble();
      _recordCount = (_statistics?['total_count'] as int?) ?? 0;

      _categoryStats = await _service.getCategoryStatistics(
        startTime: startTime,
        endTime: endTime,
      );

      _dailyStats = await _service.getDailyStatistics(
        startTime: startTime,
        endTime: endTime,
      );

      _state = CarbonFootprintState.success;
      _errorMessage = null;
    } catch (e) {
      _state = CarbonFootprintState.error;
      _errorMessage = e.toString();
      _logger.e('加载碳足迹统计失败: $e');
    }

    notifyListeners();
  }

  Future<bool> createRecord({
    String? wasteCode,
    String? wasteName,
    String? wasteCategory,
    required double weight,
    String weightUnit = 'kg',
    required double transportDistance,
    String transportDistanceUnit = 'km',
    String? transportMode,
    String? disposalMethod,
    String? transferOrderId,
    String? transferOrderNo,
    String? operator,
    String? operatorId,
    String? remark,
  }) async {
    try {
      final record = await _service.createAndSaveRecord(
        wasteCode: wasteCode,
        wasteName: wasteName,
        wasteCategory: wasteCategory ?? _selectedWasteCategory ?? 'HW08',
        weight: weight,
        weightUnit: weightUnit,
        transportDistance: transportDistance,
        transportDistanceUnit: transportDistanceUnit,
        transportMode: transportMode ?? _selectedTransportMode ?? 'heavy_truck',
        disposalMethod: disposalMethod ?? _selectedDisposalMethod ?? 'incineration',
        transferOrderId: transferOrderId,
        transferOrderNo: transferOrderNo,
        operator: operator,
        operatorId: operatorId,
        remark: remark,
      );

      _records.insert(0, record);
      _totalCount++;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('创建碳足迹记录失败: $e');
      return false;
    }
  }

  Future<bool> deleteRecord(int id) async {
    try {
      final success = await _service.deleteRecord(id);
      if (success) {
        _records.removeWhere((r) => r.id == id);
        _totalCount--;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.e('删除碳足迹记录失败: $e');
      return false;
    }
  }

  Future<int> syncUnsynced() async {
    try {
      final count = await _service.syncAllUnsynced();
      if (count > 0) {
        loadRecords(refresh: true);
      }
      return count;
    } catch (e) {
      _logger.e('同步碳足迹记录失败: $e');
      return 0;
    }
  }

  String getTransportModeName(String mode) {
    return CarbonFootprintService.getTransportModeName(mode);
  }

  String getDisposalMethodName(String method) {
    return CarbonFootprintService.getDisposalMethodName(method);
  }

  String getWasteCategoryName(String category) {
    return CarbonFootprintService.getWasteCategoryName(category);
  }

  void init() {
    _selectedTransportMode = 'heavy_truck';
    _selectedDisposalMethod = 'incineration';
    _calculationResult = null;
  }

  void resetSearch() {
    _keyword = null;
    _wasteCategory = null;
    _disposalMethod = null;
    _startTime = null;
    _endTime = null;
    _syncStatus = null;
    notifyListeners();
  }
}
