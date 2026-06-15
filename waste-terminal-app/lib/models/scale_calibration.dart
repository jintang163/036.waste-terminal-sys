import 'dart:convert';

/// 归零/去皮协同模式
enum CalibrationSynergyMode {
  /// 硬件指令优先，失败自动回落软件补偿
  hardwareFirst,

  /// 仅软件偏移（不发送硬件指令）
  softwareOnly,

  /// 仅硬件指令，失败则报错不做软件补偿
  hardwareOnly,
}

/// 归零/去皮操作类型
enum CalibrationActionType {
  /// 纯硬件指令（成功）
  hardware,

  /// 纯软件补偿
  software,

  /// 硬件失败，软件补偿
  hardwareFallbackSoftware,
}

/// 地磅校准点
class ScaleCalibrationPoint {
  final double knownWeight;
  final double rawReading;
  final DateTime timestamp;

  ScaleCalibrationPoint({
    required this.knownWeight,
    required this.rawReading,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'knownWeight': knownWeight,
      'rawReading': rawReading,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ScaleCalibrationPoint.fromMap(Map<String, dynamic> map) {
    return ScaleCalibrationPoint(
      knownWeight: (map['knownWeight'] as num).toDouble(),
      rawReading: (map['rawReading'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

/// 地磅校准参数（两点线性校准）
class ScaleCalibrationParams {
  final double slope;
  final double intercept;

  /// 硬件端已执行归零后的基础零点（由硬件寄存器维护，不再用软件再扣）
  final double hardwareZeroOffset;

  /// 软件附加零点补偿（硬件指令失败或不可用时启用）
  final double softwareZeroOffset;

  /// 硬件端已去皮的皮重值
  final double hardwareTare;

  /// 软件附加皮重补偿
  final double softwareTare;

  final List<ScaleCalibrationPoint> calibrationPoints;
  final DateTime lastCalibrationTime;
  final String? deviceAddress;
  final String? deviceName;
  final int calibrationCount;
  final bool isCalibrated;
  final CalibrationSynergyMode synergyMode;

  ScaleCalibrationParams({
    this.slope = 1.0,
    this.intercept = 0.0,
    this.hardwareZeroOffset = 0.0,
    this.softwareZeroOffset = 0.0,
    this.hardwareTare = 0.0,
    this.softwareTare = 0.0,
    this.calibrationPoints = const [],
    required this.lastCalibrationTime,
    this.deviceAddress,
    this.deviceName,
    this.calibrationCount = 0,
    this.isCalibrated = false,
    this.synergyMode = CalibrationSynergyMode.hardwareFirst,
  });

  /// 总零点 = 硬件已生效零点 + 软件补偿零点（通常只有其一有值）
  double get totalZeroOffset => hardwareZeroOffset + softwareZeroOffset;

  /// 总皮重 = 硬件已生效皮重 + 软件补偿皮重
  double get totalTare => hardwareTare + softwareTare;

  /// 当前使用的总皮重（向后兼容字段）
  double get currentTare => totalTare;

  /// 当前使用的总零点（向后兼容字段）
  double get zeroOffset => totalZeroOffset;

  /// 应用校准公式校正原始读数（不含皮重和零点）
  double apply(double rawReading) {
    return rawReading * slope + intercept;
  }

  /// 获取去除零点和皮重后的净重量
  double getNetWeight(double rawReading) {
    final calibrated = apply(rawReading);
    final net = calibrated - totalZeroOffset - totalTare;
    return net < 0 ? 0.0 : net;
  }

  Map<String, dynamic> toMap() {
    return {
      'slope': slope,
      'intercept': intercept,
      'hardwareZeroOffset': hardwareZeroOffset,
      'softwareZeroOffset': softwareZeroOffset,
      'hardwareTare': hardwareTare,
      'softwareTare': softwareTare,
      'calibrationPoints': calibrationPoints.map((e) => e.toMap()).toList(),
      'lastCalibrationTime': lastCalibrationTime.toIso8601String(),
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
      'calibrationCount': calibrationCount,
      'isCalibrated': isCalibrated,
      'synergyMode': synergyMode.index,
    };
  }

  factory ScaleCalibrationParams.fromMap(Map<String, dynamic> map) {
    final modeIdx = map['synergyMode'] as int? ?? 0;
    return ScaleCalibrationParams(
      slope: (map['slope'] as num?)?.toDouble() ?? 1.0,
      intercept: (map['intercept'] as num?)?.toDouble() ?? 0.0,
      hardwareZeroOffset: (map['hardwareZeroOffset'] as num?)?.toDouble() ??
          (map['zeroOffset'] as num?)?.toDouble() ??
          0.0,
      softwareZeroOffset:
          (map['softwareZeroOffset'] as num?)?.toDouble() ?? 0.0,
      hardwareTare: (map['hardwareTare'] as num?)?.toDouble() ?? 0.0,
      softwareTare: (map['softwareTare'] as num?)?.toDouble() ??
          (map['currentTare'] as num?)?.toDouble() ??
          0.0,
      calibrationPoints: (map['calibrationPoints'] as List<dynamic>?)
              ?.map((e) =>
                  ScaleCalibrationPoint.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lastCalibrationTime: DateTime.tryParse(
              map['lastCalibrationTime'] as String? ?? '') ??
          DateTime.now(),
      deviceAddress: map['deviceAddress'] as String?,
      deviceName: map['deviceName'] as String?,
      calibrationCount: map['calibrationCount'] as int? ?? 0,
      isCalibrated: map['isCalibrated'] as bool? ?? false,
      synergyMode: modeIdx >= 0 && modeIdx < CalibrationSynergyMode.values.length
          ? CalibrationSynergyMode.values[modeIdx]
          : CalibrationSynergyMode.hardwareFirst,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ScaleCalibrationParams.fromJson(String source) =>
      ScaleCalibrationParams.fromMap(jsonDecode(source) as Map<String, dynamic>);

  ScaleCalibrationParams copyWith({
    double? slope,
    double? intercept,
    double? hardwareZeroOffset,
    double? softwareZeroOffset,
    double? hardwareTare,
    double? softwareTare,
    List<ScaleCalibrationPoint>? calibrationPoints,
    DateTime? lastCalibrationTime,
    String? deviceAddress,
    String? deviceName,
    int? calibrationCount,
    bool? isCalibrated,
    CalibrationSynergyMode? synergyMode,
  }) {
    return ScaleCalibrationParams(
      slope: slope ?? this.slope,
      intercept: intercept ?? this.intercept,
      hardwareZeroOffset: hardwareZeroOffset ?? this.hardwareZeroOffset,
      softwareZeroOffset: softwareZeroOffset ?? this.softwareZeroOffset,
      hardwareTare: hardwareTare ?? this.hardwareTare,
      softwareTare: softwareTare ?? this.softwareTare,
      calibrationPoints: calibrationPoints ?? this.calibrationPoints,
      lastCalibrationTime: lastCalibrationTime ?? this.lastCalibrationTime,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      deviceName: deviceName ?? this.deviceName,
      calibrationCount: calibrationCount ?? this.calibrationCount,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      synergyMode: synergyMode ?? this.synergyMode,
    );
  }

  String get statusText {
    if (!isCalibrated) return '未校准';
    if (calibrationPoints.isEmpty) return '零点已设置';
    return '已校准(${calibrationPoints.length}点)';
  }

  String get synergyModeText {
    switch (synergyMode) {
      case CalibrationSynergyMode.hardwareFirst:
        return '硬件优先+软件回退';
      case CalibrationSynergyMode.softwareOnly:
        return '仅软件补偿';
      case CalibrationSynergyMode.hardwareOnly:
        return '仅硬件指令';
    }
  }

  String get lastCalibrationTimeText {
    if (!isCalibrated) return '—';
    return '${lastCalibrationTime.year.toString().padLeft(4, '0')}-'
        '${lastCalibrationTime.month.toString().padLeft(2, '0')}-'
        '${lastCalibrationTime.day.toString().padLeft(2, '0')} '
        '${lastCalibrationTime.hour.toString().padLeft(2, '0')}:'
        '${lastCalibrationTime.minute.toString().padLeft(2, '0')}';
  }
}

/// 地磅校准历史记录
class ScaleCalibrationRecord {
  final String id;
  final DateTime timestamp;
  final String deviceAddress;
  final String deviceName;
  final double oldSlope;
  final double oldIntercept;
  final double newSlope;
  final double newIntercept;
  final double oldZero;
  final double newZero;
  final double oldTare;
  final double newTare;
  final CalibrationActionType actionType;
  final String? operatorName;
  final String? remark;

  ScaleCalibrationRecord({
    required this.id,
    required this.timestamp,
    required this.deviceAddress,
    required this.deviceName,
    required this.oldSlope,
    required this.oldIntercept,
    required this.newSlope,
    required this.newIntercept,
    required this.oldZero,
    required this.newZero,
    required this.oldTare,
    required this.newTare,
    required this.actionType,
    this.operatorName,
    this.remark,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
      'oldSlope': oldSlope,
      'oldIntercept': oldIntercept,
      'newSlope': newSlope,
      'newIntercept': newIntercept,
      'oldZero': oldZero,
      'newZero': newZero,
      'oldTare': oldTare,
      'newTare': newTare,
      'actionType': actionType.index,
      'operatorName': operatorName,
      'remark': remark,
    };
  }

  factory ScaleCalibrationRecord.fromMap(Map<String, dynamic> map) {
    final idx = map['actionType'] as int? ?? 1;
    return ScaleCalibrationRecord(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      deviceAddress: map['deviceAddress'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? '',
      oldSlope: (map['oldSlope'] as num).toDouble(),
      oldIntercept: (map['oldIntercept'] as num).toDouble(),
      newSlope: (map['newSlope'] as num).toDouble(),
      newIntercept: (map['newIntercept'] as num).toDouble(),
      oldZero: (map['oldZero'] as num?)?.toDouble() ?? 0.0,
      newZero: (map['newZero'] as num?)?.toDouble() ?? 0.0,
      oldTare: (map['oldTare'] as num?)?.toDouble() ?? 0.0,
      newTare: (map['newTare'] as num?)?.toDouble() ?? 0.0,
      actionType:
          idx >= 0 && idx < CalibrationActionType.values.length
              ? CalibrationActionType.values[idx]
              : CalibrationActionType.software,
      operatorName: map['operatorName'] as String?,
      remark: map['remark'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ScaleCalibrationRecord.fromJson(String source) =>
      ScaleCalibrationRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String get actionTypeText {
    switch (actionType) {
      case CalibrationActionType.hardware:
        return '硬件指令';
      case CalibrationActionType.software:
        return '软件补偿';
      case CalibrationActionType.hardwareFallbackSoftware:
        return '硬件失败→软件';
    }
  }
}
