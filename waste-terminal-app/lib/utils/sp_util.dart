import 'package:shared_preferences/shared_preferences.dart';

class SpUtil {
  SpUtil._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences? get prefs => _prefs;

  static Future<bool> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
    return true;
  }

  static Future<bool> putString(String key, String value) async {
    await _ensureInitialized();
    return _prefs!.setString(key, value);
  }

  static String? getString(String key, [String? defaultValue]) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  static Future<bool> putInt(String key, int value) async {
    await _ensureInitialized();
    return _prefs!.setInt(key, value);
  }

  static int? getInt(String key, [int? defaultValue]) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  static Future<bool> putDouble(String key, double value) async {
    await _ensureInitialized();
    return _prefs!.setDouble(key, value);
  }

  static double? getDouble(String key, [double? defaultValue]) {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  static Future<bool> putBool(String key, bool value) async {
    await _ensureInitialized();
    return _prefs!.setBool(key, value);
  }

  static bool? getBool(String key, [bool? defaultValue]) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  static Future<bool> putStringList(String key, List<String> value) async {
    await _ensureInitialized();
    return _prefs!.setStringList(key, value);
  }

  static List<String>? getStringList(String key, [List<String>? defaultValue]) {
    return _prefs?.getStringList(key) ?? defaultValue;
  }

  static Future<bool> remove(String key) async {
    await _ensureInitialized();
    return _prefs!.remove(key);
  }

  static Future<bool> clear() async {
    await _ensureInitialized();
    return _prefs!.clear();
  }

  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  static Set<String> getKeys() {
    return _prefs?.getKeys() ?? <String>{};
  }

  static Future<bool> putObject(String key, Object value) async {
    await _ensureInitialized();
    return _prefs!.setString(key, value.toString());
  }

  static Future<void> setToken(String token) async {
    await putString('token', token);
  }

  static String? getToken() {
    return getString('token');
  }

  static Future<void> removeToken() async {
    await remove('token');
  }

  static Future<bool> hasToken() async {
    await _ensureInitialized();
    return containsKey('token') && getString('token')?.isNotEmpty == true;
  }

  static Future<void> setUserId(int userId) async {
    await putInt('user_id', userId);
  }

  static int? getUserId() {
    return getInt('user_id');
  }

  static Future<void> setUsername(String username) async {
    await putString('username', username);
  }

  static String? getUsername() {
    return getString('username');
  }

  static Future<void> setEnterpriseId(int enterpriseId) async {
    await putInt('enterprise_id', enterpriseId);
  }

  static int? getEnterpriseId() {
    return getInt('enterprise_id');
  }

  static Future<void> setThemeMode(String mode) async {
    await putString('theme_mode', mode);
  }

  static String? getThemeMode() {
    return getString('theme_mode', 'light');
  }

  static Future<void> setLanguage(String language) async {
    await putString('language', language);
  }

  static String? getLanguage() {
    return getString('language', 'zh');
  }

  static Future<void> setFirstLaunch(bool isFirst) async {
    await putBool('is_first_launch', isFirst);
  }

  static bool? isFirstLaunch() {
    return getBool('is_first_launch', true);
  }

  static Future<void> setLastSyncTime(DateTime time) async {
    await putString('last_sync_time', time.toIso8601String());
  }

  static DateTime? getLastSyncTime() {
    final timeStr = getString('last_sync_time');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  static Future<void> setDeviceId(String deviceId) async {
    await putString('device_id', deviceId);
  }

  static String? getDeviceId() {
    return getString('device_id');
  }

  static Future<void> saveLoginUsername(String username) async {
    await putString('login_username', username);
  }

  static String? getLoginUsername() {
    return getString('login_username');
  }
}
