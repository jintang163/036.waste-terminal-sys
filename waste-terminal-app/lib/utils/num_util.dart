import 'package:decimal/decimal.dart';

class NumUtil {
  NumUtil._();

  static num? parseNum(dynamic value, [num? defaultValue]) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static int? parseInt(dynamic value, [int? defaultValue]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static double? parseDouble(dynamic value, [double? defaultValue]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static String formatNum(num? value, [int fractionDigits = 2]) {
    if (value == null) return '';
    return value.toStringAsFixed(fractionDigits);
  }

  static String formatNumWithoutZero(num? value, [int fractionDigits = 2]) {
    if (value == null) return '';
    final str = value.toStringAsFixed(fractionDigits);
    if (str.contains('.')) {
      return str.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  static String formatWithComma(num? value, [int fractionDigits = 2]) {
    if (value == null) return '';
    final str = formatNum(value, fractionDigits);
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  static String formatWeight(num? value, [String unit = 'kg']) {
    if (value == null) return '';
    if (value >= 1000) {
      return '${formatNum(value / 1000, 2)} t';
    }
    return '${formatNum(value, 2)} $unit';
  }

  static String formatStorage(num? bytes) {
    if (bytes == null) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${formatNum(value, 2)} ${units[unitIndex]}';
  }

  static String formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '0秒';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}天');
    if (hours > 0) parts.add('${hours}小时');
    if (minutes > 0) parts.add('${minutes}分');
    if (secs > 0 || parts.isEmpty) parts.add('${secs}秒');
    return parts.join('');
  }

  static num add(num a, num b) {
    return (Decimal.parse(a.toString()) + Decimal.parse(b.toString())).toDouble();
  }

  static num subtract(num a, num b) {
    return (Decimal.parse(a.toString()) - Decimal.parse(b.toString())).toDouble();
  }

  static num multiply(num a, num b) {
    return (Decimal.parse(a.toString()) * Decimal.parse(b.toString())).toDouble();
  }

  static num divide(num a, num b) {
    if (b == 0) return 0;
    return (Decimal.parse(a.toString()) / Decimal.parse(b.toString())).toDouble();
  }

  static bool isZero(num? value) {
    if (value == null) return true;
    return value.abs() < 0.000001;
  }

  static bool greaterThan(num a, num b) {
    return Decimal.parse(a.toString()) > Decimal.parse(b.toString());
  }

  static bool lessThan(num a, num b) {
    return Decimal.parse(a.toString()) < Decimal.parse(b.toString());
  }

  static bool greaterThanOrEqual(num a, num b) {
    return Decimal.parse(a.toString()) >= Decimal.parse(b.toString());
  }

  static bool lessThanOrEqual(num a, num b) {
    return Decimal.parse(a.toString()) <= Decimal.parse(b.toString());
  }

  static bool equals(num a, num b) {
    return Decimal.parse(a.toString()) == Decimal.parse(b.toString());
  }

  static num max(num a, num b) {
    return greaterThan(a, b) ? a : b;
  }

  static num min(num a, num b) {
    return lessThan(a, b) ? a : b;
  }

  static num clamp(num value, num min, num max) {
    if (lessThan(value, min)) return min;
    if (greaterThan(value, max)) return max;
    return value;
  }

  static num abs(num value) {
    return value.abs();
  }

  static num round(num value, [int fractionDigits = 0]) {
    final mod = pow(10, fractionDigits);
    return (value * mod).round() / mod;
  }

  static num floor(num value, [int fractionDigits = 0]) {
    final mod = pow(10, fractionDigits);
    return (value * mod).floor() / mod;
  }

  static num ceil(num value, [int fractionDigits = 0]) {
    final mod = pow(10, fractionDigits);
    return (value * mod).ceil() / mod;
  }

  static num pow(num x, num exponent) {
    return x.pow(exponent);
  }

  static int getRandomInt(int min, int max) {
    return min + (DateTime.now().microsecondsSinceEpoch % (max - min + 1));
  }

  static double getRandomDouble() {
    return DateTime.now().microsecondsSinceEpoch % 1000000 / 1000000;
  }

  static double percentage(num? value, num? total) {
    if (value == null || total == null || total == 0) return 0;
    return (value / total * 100).toDouble();
  }

  static String percentageString(num? value, num? total, [int fractionDigits = 2]) {
    final percent = percentage(value, total);
    return '${formatNum(percent, fractionDigits)}%';
  }

  static String toRomanNumeral(int number) {
    if (number <= 0 || number >= 4000) return number.toString();
    const romanNumerals = [
      ('M', 1000),
      ('CM', 900),
      ('D', 500),
      ('CD', 400),
      ('C', 100),
      ('XC', 90),
      ('L', 50),
      ('XL', 40),
      ('X', 10),
      ('IX', 9),
      ('V', 5),
      ('IV', 4),
      ('I', 1),
    ];
    var result = '';
    var num = number;
    for (final (symbol, value) in romanNumerals) {
      while (num >= value) {
        result += symbol;
        num -= value;
      }
    }
    return result;
  }
}
