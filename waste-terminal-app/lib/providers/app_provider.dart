import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/auth_service.dart';

enum AppThemeMode { light, dark, system }
enum NetworkStatus { online, offline, unknown }

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  NetworkStatus _networkStatus = NetworkStatus.unknown;
  AppThemeMode _themeMode = AppThemeMode.system;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _enterpriseInfo;
  bool _isInitialized = false;

  NetworkStatus get networkStatus => _networkStatus;
  AppThemeMode get themeMode => _themeMode;
  Map<String, dynamic>? get userInfo => _userInfo;
  Map<String, dynamic>? get enterpriseInfo => _enterpriseInfo;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _userInfo != null;
  bool get isOnline => _networkStatus == NetworkStatus.online;

  Future<void> init() async {
    try {
      await _authService.init();
      _userInfo = _authService.userInfo;
      _enterpriseInfo = _authService.enterpriseInfo;

      await _checkNetworkStatus();
      _listenNetworkChanges();

      _isInitialized = true;
      notifyListeners();

      _logger.i('AppProvider初始化完成');
    } catch (e) {
      _logger.e('AppProvider初始化失败: $e');
    }
  }

  Future<void> _checkNetworkStatus() async {
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      _updateNetworkStatus(connectivityResult);
    } catch (e) {
      _logger.e('检查网络状态失败: $e');
    }
  }

  void _listenNetworkChanges() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateNetworkStatus(result);
    });
  }

  void _updateNetworkStatus(ConnectivityResult result) {
    NetworkStatus oldStatus = _networkStatus;

    if (result == ConnectivityResult.none) {
      _networkStatus = NetworkStatus.offline;
    } else {
      _networkStatus = NetworkStatus.online;
    }

    if (oldStatus != _networkStatus) {
      _logger.d('网络状态变化: $oldStatus -> $_networkStatus');
      notifyListeners();
    }
  }

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _logger.d('主题模式已更新: $mode');
  }

  void toggleTheme() {
    if (_themeMode == AppThemeMode.light) {
      _themeMode = AppThemeMode.dark;
    } else if (_themeMode == AppThemeMode.dark) {
      _themeMode = AppThemeMode.system;
    } else {
      _themeMode = AppThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final result = await _authService.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );

      _userInfo = result['userInfo'];
      _enterpriseInfo = result['enterpriseInfo'];

      notifyListeners();
      _logger.i('用户登录成功: $username');
    } catch (e) {
      _logger.e('用户登录失败: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      _userInfo = null;
      _enterpriseInfo = null;
      notifyListeners();
      _logger.i('用户登出成功');
    } catch (e) {
      _logger.e('用户登出失败: $e');
    }
  }

  Future<bool> autoLogin() async {
    try {
      final result = await _authService.autoLogin();
      _userInfo = result['userInfo'];
      _enterpriseInfo = result['enterpriseInfo'];
      notifyListeners();
      _logger.i('自动登录成功');
      return true;
    } catch (e) {
      _logger.w('自动登录失败: $e');
      return false;
    }
  }

  void updateUserInfo(Map<String, dynamic> newUserInfo) {
    _userInfo = newUserInfo;
    _authService.updateUserInfo(newUserInfo);
    notifyListeners();
  }

  void updateEnterpriseInfo(Map<String, dynamic> newEnterpriseInfo) {
    _enterpriseInfo = newEnterpriseInfo;
    _authService.updateEnterpriseInfo(newEnterpriseInfo);
    notifyListeners();
  }

  String? get username {
    if (_userInfo != null && _userInfo!['username'] != null) {
      return _userInfo!['username'].toString();
    }
    return null;
  }

  String? get enterpriseName {
    if (_enterpriseInfo != null && _enterpriseInfo!['name'] != null) {
      return _enterpriseInfo!['name'].toString();
    }
    return null;
  }

  AuthService get authService => _authService;
}
