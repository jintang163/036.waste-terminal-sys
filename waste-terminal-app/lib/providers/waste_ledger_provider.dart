import 'package:flutter/foundation.dart';

import '../models/waste_ledger.dart';
import '../services/waste_ledger_service.dart';
import '../utils/toast_util.dart';

class WasteLedgerProvider extends ChangeNotifier {
  final WasteLedgerService _ledgerService = WasteLedgerService();

  List<WasteLedger> _items = [];
  List<WasteLedger> get items => _items;

  WasteLedger? _currentLedger;
  WasteLedger? get currentLedger => _currentLedger;

  List<WasteLedgerDetail> _details = [];
  List<WasteLedgerDetail> get details => _details;

  List<WasteLedgerReportLog> _reportLogs = [];
  List<WasteLedgerReportLog> get reportLogs => _reportLogs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _total = 0;
  int get total => _total;

  int _pageNum = 1;
  int get pageNum => _pageNum;

  final int _pageSize = 10;
  int get pageSize => _pageSize;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _searchKeyword;

  Future<void> init() async {
  }

  String? _ledgerType;
  int? _periodYear;
  int? _periodMonth;
  int? _generateStatus;
  int? _reportStatus;

  Future<void> loadItems({bool refresh = false}) async {
    if (refresh) {
      _pageNum = 1;
      _hasMore = true;
      _items = [];
    }

    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _ledgerService.getLedgerPage(
        pageNum: _pageNum,
        pageSize: _pageSize,
        ledgerType: _ledgerType,
        periodYear: _periodYear,
        periodMonth: _periodMonth,
        generateStatus: _generateStatus,
        reportStatus: _reportStatus,
        keyword: _searchKeyword,
      );

      _total = result.total ?? 0;

      if (result.records != null && result.records!.isNotEmpty) {
        if (refresh) {
          _items = result.records!;
        } else {
          _items.addAll(result.records!);
        }
        _pageNum++;
      }

      _hasMore = _items.length < _total;
    } catch (e) {
      ToastUtil.showError('加载失败: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadItems(refresh: true);
  }

  void setSearchParams({
    String? keyword,
    String? ledgerType,
    int? periodYear,
    int? periodMonth,
    int? generateStatus,
    int? reportStatus,
  }) {
    _searchKeyword = keyword;
    _ledgerType = ledgerType;
    _periodYear = periodYear;
    _periodMonth = periodMonth;
    _generateStatus = generateStatus;
    _reportStatus = reportStatus;
  }

  void clearSearch() {
    _searchKeyword = null;
    _ledgerType = null;
    _periodYear = null;
    _periodMonth = null;
    _generateStatus = null;
    _reportStatus = null;
  }

  Future<WasteLedger?> loadDetail(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentLedger = await _ledgerService.getLedgerDetail(id);
      return _currentLedger;
    } catch (e) {
      ToastUtil.showError('加载详情失败: ${e.toString()}');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<WasteLedgerDetail>> loadDetails(int ledgerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _details = await _ledgerService.getLedgerDetails(ledgerId);
      return _details;
    } catch (e) {
      ToastUtil.showError('加载明细失败: ${e.toString()}');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<WasteLedgerReportLog>> loadReportLogs(int ledgerId, {bool refresh = false}) async {
    if (refresh) {
      _reportLogs = [];
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _ledgerService.getReportLogs(ledgerId: ledgerId);
      _reportLogs = result.records ?? [];
      return _reportLogs;
    } catch (e) {
      ToastUtil.showError('加载上报日志失败: ${e.toString()}');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<WasteLedger?> generateLedger({
    required String ledgerType,
    required int periodYear,
    int? periodMonth,
    String? remark,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ledger = await _ledgerService.generateLedger(
        ledgerType: ledgerType,
        periodYear: periodYear,
        periodMonth: periodMonth,
        remark: remark,
      );
      ToastUtil.showSuccess('台账生成任务已提交，请稍后查看');
      return ledger;
    } catch (e) {
      ToastUtil.showError('生成失败: ${e.toString()}');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> regenerateLedger(int id) async {
    try {
      await _ledgerService.regenerateLedger(id);
      ToastUtil.showSuccess('重新生成任务已提交');
      return true;
    } catch (e) {
      ToastUtil.showError('重新生成失败: ${e.toString()}');
      return false;
    }
  }

  Future<String?> previewLedger(int id) async {
    try {
      final url = await _ledgerService.previewLedger(id);
      return url;
    } catch (e) {
      ToastUtil.showError('预览失败: ${e.toString()}');
      return null;
    }
  }

  Future<bool> reportLedger(int id, {String reportType = 'MANUAL'}) async {
    try {
      await _ledgerService.reportLedger(id, reportType: reportType);
      ToastUtil.showSuccess('上报任务已提交');
      return true;
    } catch (e) {
      ToastUtil.showError('上报失败: ${e.toString()}');
      return false;
    }
  }

  Future<bool> retryReport(int id) async {
    try {
      await _ledgerService.retryReport(id);
      ToastUtil.showSuccess('重试上报任务已提交');
      return true;
    } catch (e) {
      ToastUtil.showError('重试失败: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteLedger(int id) async {
    try {
      await _ledgerService.deleteLedger(id);
      _items.removeWhere((item) => item.id == id);
      ToastUtil.showSuccess('删除成功');
      notifyListeners();
      return true;
    } catch (e) {
      ToastUtil.showError('删除失败: ${e.toString()}');
      return false;
    }
  }
}
