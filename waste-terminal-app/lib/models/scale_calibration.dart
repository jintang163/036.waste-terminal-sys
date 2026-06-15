import 'dart:convert';

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
  final double zeroOffset;
  final double currentTare;
  final List<ScaleCalibrationPoint> calibrationPoints;
  final DateTime lastCalibrationTime;
  final String? deviceAddress;
  final String? deviceName;
  final int calibrationCount;
  final bool isCalibrated;

  ScaleCalibrationParams({
    this.slope = 1.0,
    this.intercept = 0.0,
    this.zeroOffset = 0.0,
    this.currentTare = 0.0,
    this.calibrationPoints = const [],
    required this.lastCalibrationTime,
    this.deviceAddress,
    this.deviceName,
    this.calibrationCount = 0,
    this.isCalibrated = false,
  });

  /// 应用校准公式校正原始读数
  double apply(double rawReading) {
    final calibrated = rawReading * slope + intercept;
    return calibrated;
  }

  /// 获取去除零点和皮重后的净重量
  double getNetWeight(double rawReading) {
    final calibrated = apply(rawReading);
    final net = calibrated - zeroOffset - currentTare;
    return net < 0 ? 0.0 : net;
  }

  Map<String, dynamic> toMap() {
    return {
      'slope': slope,
      'intercept': intercept,
      'zeroOffset': zeroOffset,
      'currentTare': currentTare,
      'calibrationPoints': calibrationPoints.map((e) => e.toMap()).toList(),
      'lastCalibrationTime': lastCalibrationTime.toIso8601String(),
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
      'calibrationCount': calibrationCount,
      'isCalibrated': isCalibrated,
    };
  }

  factory ScaleCalibrationParams.fromMap(Map<String, dynamic> map) {
    return ScaleCalibrationParams(
      slope: (map['slope'] as num?)?.toDouble() ?? 1.0,
      intercept: (map['intercept'] as num?)?.toDouble() ?? 0.0,
      zeroOffset: (map['zeroOffset'] as num?)?.toDouble() ?? 0.0,
      currentTare: (map['currentTare'] as num?)?.toDouble() ?? 0.0,
      calibrationPoints: (map['calibrationPoints'] as List<dynamic>?)
              ?.map((e) => ScaleCalibrationPoint.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lastCalibrationTime: DateTime.tryParse(map['lastCalibrationTime'] as String? ?? '') ??
          DateTime.now(),
      deviceAddress: map['deviceAddress'] as String?,
      deviceName: map['deviceName'] as String?,
      calibrationCount: map['calibrationCount'] as int? ?? 0,
      isCalibrated: map['isCalibrated'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ScaleCalibrationParams.fromJson(String source) =>
      ScaleCalibrationParams.fromMap(jsonDecode(source) as Map<String, dynamic>);

  ScaleCalibrationParams copyWith({
    double? slope,
    double? intercept,
    double? zeroOffset,
    double? currentTare,
    List<ScaleCalibrationPoint>? calibrationPoints,
    DateTime? lastCalibrationTime,
    String? deviceAddress,
    String? deviceName,
    int? calibrationCount,
    bool? isCalibrated,
  }) {
    return ScaleCalibrationParams(
      slope: slope ?? this.slope,
      intercept: intercept ?? this.intercept,
      zeroOffset: zeroOffset ?? this.zeroOffset,
      currentTare: currentTare ?? this.currentTare,
      calibrationPoints: calibrationPoints ?? this.calibrationPoints,
      lastCalibrationTime: lastCalibrationTime ?? this.lastCalibrationTime,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      deviceName: deviceName ?? this.deviceName,
      calibrationCount: calibrationCount ?? this.calibrationCount,
      isCalibrated: isCalibrated ?? this.isCalibrated,
    );
  }

  String get statusText {
    if (!isCalibrated) return '未校准';
    if (calibrationPoints.isEmpty) return '零点已设置';
    return '已校准(${calibrationPoints.length}点)';
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
      'operatorName': operatorName,
      'remark': remark,
    };
  }

  factory ScaleCalibrationRecord.fromMap(Map<String, dynamic> map) {
    return ScaleCalibrationRecord(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      deviceAddress: map['deviceAddress'] as String,
      deviceName: map['deviceName'] as String,
      oldSlope: (map['oldSlope'] as num).toDouble(),
      oldIntercept: (map['oldIntercept'] as num).toDouble(),
      newSlope: (map['newSlope'] as num).toDouble(),
      newIntercept: (map['newIntercept'] as num).toDouble(),
      oldZero: (map['oldZero'] as num).toDouble(),
      newZero: (map['newZero'] as num).toDouble(),
      operatorName: map['operatorName'] as String?,
      remark: map['remark'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ScaleCalibrationRecord.fromJson(String source) =>
      ScaleCalibrationRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
