import 'dart:convert';

class WasteLedger {
  final int? id;
  final String? ledgerNo;
  final String? ledgerType;
  final int? periodYear;
  final int? periodMonth;
  final String? startDate;
  final String? endDate;
  final int? enterpriseId;
  final String? enterpriseName;
  final String? enterpriseCode;
  final int? totalInCount;
  final double? totalInWeight;
  final int? totalOutCount;
  final double? totalOutWeight;
  final double? beginInventoryWeight;
  final double? endInventoryWeight;
  final int? fileId;
  final String? fileUrl;
  final String? fileName;
  final int? generateStatus;
  final String? generateTime;
  final String? generateFailReason;
  final int? reportStatus;
  final String? reportTime;
  final String? reportFailReason;
  final String? platformLedgerNo;
  final int? retryCount;
  final int? operatorId;
  final String? operatorName;
  final String? remark;
  final String? createTime;
  final String? updateTime;

  WasteLedger({
    this.id,
    this.ledgerNo,
    this.ledgerType,
    this.periodYear,
    this.periodMonth,
    this.startDate,
    this.endDate,
    this.enterpriseId,
    this.enterpriseName,
    this.enterpriseCode,
    this.totalInCount,
    this.totalInWeight,
    this.totalOutCount,
    this.totalOutWeight,
    this.beginInventoryWeight,
    this.endInventoryWeight,
    this.fileId,
    this.fileUrl,
    this.fileName,
    this.generateStatus,
    this.generateTime,
    this.generateFailReason,
    this.reportStatus,
    this.reportTime,
    this.reportFailReason,
    this.platformLedgerNo,
    this.retryCount,
    this.operatorId,
    this.operatorName,
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory WasteLedger.fromJson(Map<String, dynamic> json) => WasteLedger(
        id: json['id'] as int?,
        ledgerNo: json['ledgerNo'] as String?,
        ledgerType: json['ledgerType'] as String?,
        periodYear: json['periodYear'] as int?,
        periodMonth: json['periodMonth'] as int?,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        enterpriseId: json['enterpriseId'] as int?,
        enterpriseName: json['enterpriseName'] as String?,
        enterpriseCode: json['enterpriseCode'] as String?,
        totalInCount: json['totalInCount'] as int?,
        totalInWeight: (json['totalInWeight'] as num?)?.toDouble(),
        totalOutCount: json['totalOutCount'] as int?,
        totalOutWeight: (json['totalOutWeight'] as num?)?.toDouble(),
        beginInventoryWeight: (json['beginInventoryWeight'] as num?)?.toDouble(),
        endInventoryWeight: (json['endInventoryWeight'] as num?)?.toDouble(),
        fileId: json['fileId'] as int?,
        fileUrl: json['fileUrl'] as String?,
        fileName: json['fileName'] as String?,
        generateStatus: json['generateStatus'] as int?,
        generateTime: json['generateTime'] as String?,
        generateFailReason: json['generateFailReason'] as String?,
        reportStatus: json['reportStatus'] as int?,
        reportTime: json['reportTime'] as String?,
        reportFailReason: json['reportFailReason'] as String?,
        platformLedgerNo: json['platformLedgerNo'] as String?,
        retryCount: json['retryCount'] as int?,
        operatorId: json['operatorId'] as int?,
        operatorName: json['operatorName'] as String?,
        remark: json['remark'] as String?,
        createTime: json['createTime'] as String?,
        updateTime: json['updateTime'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerNo': ledgerNo,
        'ledgerType': ledgerType,
        'periodYear': periodYear,
        'periodMonth': periodMonth,
        'startDate': startDate,
        'endDate': endDate,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'enterpriseCode': enterpriseCode,
        'totalInCount': totalInCount,
        'totalInWeight': totalInWeight,
        'totalOutCount': totalOutCount,
        'totalOutWeight': totalOutWeight,
        'beginInventoryWeight': beginInventoryWeight,
        'endInventoryWeight': endInventoryWeight,
        'fileId': fileId,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'generateStatus': generateStatus,
        'generateTime': generateTime,
        'generateFailReason': generateFailReason,
        'reportStatus': reportStatus,
        'reportTime': reportTime,
        'reportFailReason': reportFailReason,
        'platformLedgerNo': platformLedgerNo,
        'retryCount': retryCount,
        'operatorId': operatorId,
        'operatorName': operatorName,
        'remark': remark,
        'createTime': createTime,
        'updateTime': updateTime,
      };

  String get ledgerTypeText {
    switch (ledgerType) {
      case 'MONTHLY':
        return '月报';
      case 'YEARLY':
        return '年报';
      default:
        return '未知';
    }
  }

  String get generateStatusText {
    switch (generateStatus) {
      case 0:
        return '待生成';
      case 1:
        return '生成中';
      case 2:
        return '已生成';
      case 3:
        return '生成失败';
      default:
        return '未知';
    }
  }

  String get reportStatusText {
    switch (reportStatus) {
      case 0:
        return '待上报';
      case 1:
        return '上报中';
      case 2:
        return '已上报';
      case 3:
        return '上报失败';
      case 4:
        return '无需上报';
      default:
        return '未知';
    }
  }

  String get periodText {
    if (ledgerType == 'MONTHLY') {
      return '$periodYear年$periodMonth月';
    } else {
      return '$periodYear年度';
    }
  }
}

class WasteLedgerDetail {
  final int? id;
  final int? ledgerId;
  final String? ledgerNo;
  final String? detailType;
  final int? wasteId;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final String? hazardCode;
  final int? containerId;
  final String? containerCode;
  final String? recordNo;
  final double? weight;
  final String? changeType;
  final String? operateTime;
  final String? operatorName;
  final String? remark;
  final String? createTime;
  final String? updateTime;

  WasteLedgerDetail({
    this.id,
    this.ledgerId,
    this.ledgerNo,
    this.detailType,
    this.wasteId,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.hazardCode,
    this.containerId,
    this.containerCode,
    this.recordNo,
    this.weight,
    this.changeType,
    this.operateTime,
    this.operatorName,
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory WasteLedgerDetail.fromJson(Map<String, dynamic> json) => WasteLedgerDetail(
        id: json['id'] as int?,
        ledgerId: json['ledgerId'] as int?,
        ledgerNo: json['ledgerNo'] as String?,
        detailType: json['detailType'] as String?,
        wasteId: json['wasteId'] as int?,
        wasteCode: json['wasteCode'] as String?,
        wasteName: json['wasteName'] as String?,
        wasteCategory: json['wasteCategory'] as String?,
        hazardCode: json['hazardCode'] as String?,
        containerId: json['containerId'] as int?,
        containerCode: json['containerCode'] as String?,
        recordNo: json['recordNo'] as String?,
        weight: (json['weight'] as num?)?.toDouble(),
        changeType: json['changeType'] as String?,
        operateTime: json['operateTime'] as String?,
        operatorName: json['operatorName'] as String?,
        remark: json['remark'] as String?,
        createTime: json['createTime'] as String?,
        updateTime: json['updateTime'] as String?,
      );

  String get detailTypeText {
    switch (detailType) {
      case 'IN':
        return '入库';
      case 'OUT':
        return '出库';
      case 'INVENTORY_CHANGE':
        return '库存变动';
      default:
        return '未知';
    }
  }

  String get changeTypeText {
    switch (changeType) {
      case 'IN':
        return '入库';
      case 'OUT':
        return '出库';
      case 'ADJUST':
        return '调整';
      case 'LOSS':
        return '损耗';
      default:
        return '未知';
    }
  }
}

class WasteLedgerReportLog {
  final int? id;
  final String? logNo;
  final int? ledgerId;
  final String? ledgerNo;
  final String? reportType;
  final int? reportStatus;
  final String? reportTime;
  final String? requestPayload;
  final String? responsePayload;
  final String? failReason;
  final String? platformLedgerNo;
  final int? durationMs;
  final int? operatorId;
  final String? operatorName;
  final int? enterpriseId;
  final String? createTime;
  final String? updateTime;

  WasteLedgerReportLog({
    this.id,
    this.logNo,
    this.ledgerId,
    this.ledgerNo,
    this.reportType,
    this.reportStatus,
    this.reportTime,
    this.requestPayload,
    this.responsePayload,
    this.failReason,
    this.platformLedgerNo,
    this.durationMs,
    this.operatorId,
    this.operatorName,
    this.enterpriseId,
    this.createTime,
    this.updateTime,
  });

  factory WasteLedgerReportLog.fromJson(Map<String, dynamic> json) => WasteLedgerReportLog(
        id: json['id'] as int?,
        logNo: json['logNo'] as String?,
        ledgerId: json['ledgerId'] as int?,
        ledgerNo: json['ledgerNo'] as String?,
        reportType: json['reportType'] as String?,
        reportStatus: json['reportStatus'] as int?,
        reportTime: json['reportTime'] as String?,
        requestPayload: json['requestPayload'] as String?,
        responsePayload: json['responsePayload'] as String?,
        failReason: json['failReason'] as String?,
        platformLedgerNo: json['platformLedgerNo'] as String?,
        durationMs: json['durationMs'] as int?,
        operatorId: json['operatorId'] as int?,
        operatorName: json['operatorName'] as String?,
        enterpriseId: json['enterpriseId'] as int?,
        createTime: json['createTime'] as String?,
        updateTime: json['updateTime'] as String?,
      );

  String get reportTypeText {
    switch (reportType) {
      case 'AUTO':
        return '自动上报';
      case 'MANUAL':
        return '手动上报';
      case 'RETRY':
        return '重试上报';
      default:
        return '未知';
    }
  }

  String get reportStatusText {
    switch (reportStatus) {
      case 1:
        return '成功';
      case 2:
        return '失败';
      default:
        return '未知';
    }
  }
}

class WasteLedgerPageResult {
  final List<WasteLedger>? records;
  final int? total;
  final int? pageNum;
  final int? pageSize;

  WasteLedgerPageResult({
    this.records,
    this.total,
    this.pageNum,
    this.pageSize,
  });

  factory WasteLedgerPageResult.fromJson(Map<String, dynamic> json) => WasteLedgerPageResult(
        records: (json['records'] as List<dynamic>?)
            ?.map((e) => WasteLedger.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int?,
        pageNum: json['pageNum'] as int?,
        pageSize: json['pageSize'] as int?,
      );
}

class WasteLedgerReportLogPageResult {
  final List<WasteLedgerReportLog>? records;
  final int? total;
  final int? pageNum;
  final int? pageSize;

  WasteLedgerReportLogPageResult({
    this.records,
    this.total,
    this.pageNum,
    this.pageSize,
  });

  factory WasteLedgerReportLogPageResult.fromJson(Map<String, dynamic> json) =>
      WasteLedgerReportLogPageResult(
        records: (json['records'] as List<dynamic>?)
            ?.map((e) => WasteLedgerReportLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int?,
        pageNum: json['pageNum'] as int?,
        pageSize: json['pageSize'] as int?,
      );
}
