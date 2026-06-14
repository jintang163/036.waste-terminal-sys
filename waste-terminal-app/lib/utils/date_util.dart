import 'package:intl/intl.dart';

class DateUtil {
  DateUtil._();

  static const String formatDefault = 'yyyy-MM-dd HH:mm:ss';
  static const String formatDate = 'yyyy-MM-dd';
  static const String formatTime = 'HH:mm:ss';
  static const String formatDateTimeShort = 'yyyy-MM-dd HH:mm';
  static const String formatMonthDay = 'MM-dd';
  static const String formatYearMonth = 'yyyy-MM';
  static const String formatChineseDate = 'yyyy年MM月dd日';
  static const String formatChineseDateTime = 'yyyy年MM月dd日 HH:mm';

  static String formatDateByPattern(
    DateTime? date, [
    String pattern = formatDefault,
  ]) {
    if (date == null) return '';
    return DateFormat(pattern).format(date);
  }

  static String formatDateTime(DateTime? date) {
    return formatDateByPattern(date, formatDefault);
  }

  static String formatDateOnly(DateTime? date) {
    return formatDateByPattern(date, formatDate);
  }

  static String formatTimeOnly(DateTime? date) {
    return formatDateByPattern(date, formatTime);
  }

  static String formatDateTimeShort(DateTime? date) {
    return formatDateByPattern(date, formatDateTimeShort);
  }

  static DateTime? parseDateTime(String? dateStr, [String? pattern]) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      if (pattern != null) {
        return DateFormat(pattern).parse(dateStr);
      }
      return DateTime.tryParse(dateStr);
    } catch (e) {
      return null;
    }
  }

  static String? formatString(
    String? dateStr, [
    String pattern = formatDefault,
    String? targetPattern,
  ]) {
    final date = parseDateTime(dateStr, pattern);
    if (date == null) return dateStr;
    return formatDateByPattern(date, targetPattern ?? formatDefault);
  }

  static String getNowString([String pattern = formatDefault]) {
    return formatDateByPattern(DateTime.now(), pattern);
  }

  static int getNowTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  static int getTodayStartTimestamp() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return start.millisecondsSinceEpoch;
  }

  static int getTodayEndTimestamp() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return end.millisecondsSinceEpoch;
  }

  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static int daysBetween(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return endDate.difference(startDate).inDays;
  }

  static DateTime addDays(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  static DateTime addHours(DateTime date, int hours) {
    return date.add(Duration(hours: hours));
  }

  static DateTime addMinutes(DateTime date, int minutes) {
    return date.add(Duration(minutes: minutes));
  }

  static String formatDuration(Duration? duration) {
    if (duration == null) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static String friendlyTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else if (date.year == now.year) {
      return formatDateByPattern(date, 'MM-dd HH:mm');
    } else {
      return formatDateByPattern(date, 'yyyy-MM-dd');
    }
  }

  static String friendlyTimeFromNow(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final isFuture = date.isAfter(now);
    final diff = isFuture
        ? date.difference(now)
        : now.difference(date);

    if (diff.inSeconds < 60) {
      return isFuture ? '即将' : '刚刚';
    } else if (diff.inMinutes < 60) {
      return isFuture ? '${diff.inMinutes}分钟后' : '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return isFuture ? '${diff.inHours}小时后' : '${diff.inHours}小时前';
    } else if (diff.inDays < 30) {
      return isFuture ? '${diff.inDays}天后' : '${diff.inDays}天前';
    } else if (date.year == now.year) {
      return formatDateByPattern(date, 'MM-dd');
    } else {
      return formatDateByPattern(date, 'yyyy-MM-dd');
    }
  }

  static int getAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
