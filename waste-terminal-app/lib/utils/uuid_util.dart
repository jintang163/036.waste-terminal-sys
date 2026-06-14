import 'package:uuid/uuid.dart';

class UuidUtil {
  UuidUtil._();

  static const Uuid _uuid = Uuid();

  static String generateUuid() {
    return _uuid.v4();
  }

  static String generateUuidV1() {
    return _uuid.v1();
  }

  static String generateUuidV4() {
    return _uuid.v4();
  }

  static String generateUuidV5(String namespace, String name) {
    return _uuid.v5(namespace, name);
  }

  static String generateShortId() {
    return _uuid.v4().replaceAll('-', '').substring(0, 16);
  }

  static String generateMiniId() {
    return _uuid.v4().replaceAll('-', '').substring(0, 8);
  }

  static String generateOfflineId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = generateMiniId();
    return '${prefix}_${timestamp}_$random';
  }

  static String generateOrderNo(String prefix) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final random = generateMiniId().toUpperCase();
    return '$prefix$dateStr$timeStr$random';
  }

  static String generateWasteInNo() {
    return generateOrderNo('WI');
  }

  static String generateWasteOutNo() {
    return generateOrderNo('WO');
  }

  static String generateTransferOrderNo() {
    return generateOrderNo('TO');
  }

  static String generateCheckNo() {
    return generateOrderNo('IC');
  }

  static String generateWarningNo() {
    return generateOrderNo('WR');
  }

  static String generateSyncNo() {
    return generateOrderNo('SY');
  }

  static String generateContainerCode(String prefix, int seq) {
    return '$prefix${seq.toString().padLeft(6, '0')}';
  }

  static bool isValidUuid(String? uuid) {
    if (uuid == null) return false;
    const pattern =
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
    return RegExp(pattern, caseSensitive: false).hasMatch(uuid);
  }

  static bool isValidUuidWithoutDash(String? uuid) {
    if (uuid == null || uuid.length != 32) return false;
    const pattern = r'^[0-9a-f]{32}$';
    return RegExp(pattern, caseSensitive: false).hasMatch(uuid);
  }

  static String? formatUuid(String? uuid) {
    if (uuid == null) return null;
    final clean = uuid.replaceAll('-', '').toLowerCase();
    if (clean.length != 32) return uuid;
    return '${clean.substring(0, 8)}-'
        '${clean.substring(8, 12)}-'
        '${clean.substring(12, 16)}-'
        '${clean.substring(16, 20)}-'
        '${clean.substring(20)}';
  }

  static String? cleanUuid(String? uuid) {
    if (uuid == null) return null;
    return uuid.replaceAll('-', '').toLowerCase();
  }

  static String generateNumericId([int length = 16]) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = generateMiniId().hashCode.toString().padLeft(length - timestamp.length, '0');
    return '$timestamp${random.substring(0, length - timestamp.length)}';
  }

  static String generateToken() {
    return generateUuid() + generateUuid();
  }
}
