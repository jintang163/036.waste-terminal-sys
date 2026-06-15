import 'dart:convert';

import '../models/api_response.dart';
import '../models/waste_ledger.dart';
import 'api_service.dart';

class WasteLedgerService {
  final ApiService _apiService = ApiService();

  Future<WasteLedgerPageResult> getLedgerPage({
    int pageNum = 1,
    int pageSize = 10,
    String? ledgerType,
    int? periodYear,
    int? periodMonth,
    int? generateStatus,
    int? reportStatus,
    String? keyword,
    int? enterpriseId,
  }) async {
    final params = <String, dynamic>{
      'pageNum': pageNum,
      'pageSize': pageSize,
      if (ledgerType != null) 'ledgerType': ledgerType,
      if (periodYear != null) 'periodYear': periodYear,
      if (periodMonth != null) 'periodMonth': periodMonth,
      if (generateStatus != null) 'generateStatus': generateStatus,
      if (reportStatus != null) 'reportStatus': reportStatus,
      if (keyword != null && keyword.isNotEmpty) 'ledgerNo': keyword,
      if (enterpriseId != null) 'enterpriseId': enterpriseId,
    };

    final response = await _apiService.get('/waste-ledger/page', params: params);
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedgerPageResult.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '获取台账列表失败');
    }

    return apiResponse.data!;
  }

  Future<WasteLedger> getLedgerDetail(int id) async {
    final response = await _apiService.get('/waste-ledger/$id');
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedger.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '获取台账详情失败');
    }

    return apiResponse.data!;
  }

  Future<List<WasteLedgerDetail>> getLedgerDetails(int ledgerId) async {
    final response = await _apiService.get('/waste-ledger/$ledgerId/details');
    final apiResponse = ApiResponse.fromJson(response, (data) {
      final list = data as List<dynamic>;
      return list.map((e) => WasteLedgerDetail.fromJson(e as Map<String, dynamic>)).toList();
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '获取台账明细失败');
    }

    return apiResponse.data!;
  }

  Future<WasteLedgerReportLogPageResult> getReportLogs({
    required int ledgerId,
    int pageNum = 1,
    int pageSize = 10,
    int? enterpriseId,
  }) async {
    final params = <String, dynamic>{
      'pageNum': pageNum,
      'pageSize': pageSize,
      if (enterpriseId != null) 'enterpriseId': enterpriseId,
    };

    final response = await _apiService.get('/waste-ledger/$ledgerId/report-logs', params: params);
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedgerReportLogPageResult.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '获取上报日志失败');
    }

    return apiResponse.data!;
  }

  Future<WasteLedger> generateLedger({
    required String ledgerType,
    required int periodYear,
    int? periodMonth,
    String? remark,
    int? enterpriseId,
  }) async {
    final body = <String, dynamic>{
      'ledgerType': ledgerType,
      'periodYear': periodYear,
      if (periodMonth != null) 'periodMonth': periodMonth,
      if (remark != null) 'remark': remark,
    };

    final params = <String, dynamic>{
      if (enterpriseId != null) 'enterpriseId': enterpriseId,
    };

    final response = await _apiService.post(
      '/waste-ledger/generate',
      body: body,
      params: params,
    );
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedger.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '生成台账失败');
    }

    return apiResponse.data!;
  }

  Future<WasteLedger> regenerateLedger(int id) async {
    final response = await _apiService.post('/waste-ledger/$id/regenerate');
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedger.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '重新生成台账失败');
    }

    return apiResponse.data!;
  }

  Future<String> previewLedger(int id) async {
    final response = await _apiService.get('/waste-ledger/$id/preview');
    final apiResponse = ApiResponse.fromJson(response, (data) => data as String);

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '预览台账失败');
    }

    return apiResponse.data!;
  }

  Future<void> reportLedger(int id, {String reportType = 'MANUAL'}) async {
    final params = <String, dynamic>{
      'reportType': reportType,
    };

    final response = await _apiService.post('/waste-ledger/$id/report', params: params);
    final apiResponse = ApiResponse.fromJson(response, (data) => null);

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '上报台账失败');
    }
  }

  Future<void> batchReport(List<int> ids) async {
    final response = await _apiService.post('/waste-ledger/batch-report', body: ids);
    final apiResponse = ApiResponse.fromJson(response, (data) => null);

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '批量上报失败');
    }
  }

  Future<void> retryReport(int id) async {
    final response = await _apiService.post('/waste-ledger/$id/retry-report');
    final apiResponse = ApiResponse.fromJson(response, (data) => null);

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '重试上报失败');
    }
  }

  Future<WasteLedger> generateMonthlyLedger({
    required int year,
    required int month,
    int? enterpriseId,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
      if (enterpriseId != null) 'enterpriseId': enterpriseId,
    };

    final response = await _apiService.post('/waste-ledger/generate-monthly', params: params);
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedger.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '生成月度台账失败');
    }

    return apiResponse.data!;
  }

  Future<WasteLedger> generateYearlyLedger({
    required int year,
    int? enterpriseId,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      if (enterpriseId != null) 'enterpriseId': enterpriseId,
    };

    final response = await _apiService.post('/waste-ledger/generate-yearly', params: params);
    final apiResponse = ApiResponse.fromJson(response, (data) {
      return WasteLedger.fromJson(data as Map<String, dynamic>);
    });

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '生成年度台账失败');
    }

    return apiResponse.data!;
  }

  Future<void> deleteLedger(int id) async {
    final response = await _apiService.delete('/waste-ledger/$id');
    final apiResponse = ApiResponse.fromJson(response, (data) => null);

    if (apiResponse.code != 200) {
      throw Exception(apiResponse.message ?? '删除台账失败');
    }
  }
}
