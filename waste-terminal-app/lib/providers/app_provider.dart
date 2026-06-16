import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/device_self_check_service.dart';
import '../services/operation_log_service.dart';
import '../services/heartbeat_service.dart';
import '../utils/sp_util.dart';

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

      _onLoginSuccess();
    } catch (e) {
      _logger.e('用户登录失败: $e');
      rethrow;
    }
  }

  Future<void> _onLoginSuccess() async {
    try {
      await OperationLogService().logInfo(
        '用户登录成功',
        category: 'auth',
        userId: SpUtil.getUserId(),
      );
    } catch (_) {}

    try {
      await HeartbeatService().start();
      _logger.i('登录后心跳服务已启动');
    } catch (e) {
      _logger.e('登录后心跳服务启动失败: $e');
    }

    try {
      await DeviceSelfCheckService().performSelfCheck();
      _logger.i('登录后设备自检完成');
    } catch (e) {
      _logger.e('登录后设备自检失败: $e');
    }
  }

  Future<void> logout() async {
    try {
      HeartbeatService().stop();
      _logger.i('登出后心跳服务已停止');
    } catch (_) {}

    try {
      await OperationLogService().logInfo(
        '用户登出',
        category: 'auth',
        userId: SpUtil.getUserId(),
      );
    } catch (_) {}

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

      _onLoginSuccess();
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

  String? get deviceId => SpUtil.getDeviceId();

  Future<void> loginWithFace({
    required int userId,
    required String username,
    String? faceAuthId,
  }) async {
    try {
      final apiService = ApiService();
      final faceLoginResult = await apiService.faceLogin(
        userId: userId,
        username: username,
        faceAuthId: faceAuthId,
      );

      _userInfo = faceLoginResult['userInfo'];
      _enterpriseInfo = faceLoginResult['enterpriseInfo'];

      notifyListeners();
      _logger.i('人脸登录成功: $username');
    } catch (e) {
      _logger.w('服务器人脸登录失败，尝试本地登录: $e');

      final savedUserInfo = _authService.userInfo;
      if (savedUserInfo != null &&
          savedUserInfo['userId'] == userId &&
          savedUserInfo['username'] == username) {
        _userInfo = savedUserInfo;
        _enterpriseInfo = _authService.enterpriseInfo;
        notifyListeners();
        _logger.i('本地人脸登录成功: $username');
        return;
      }

      rethrow;
    }
  }
}
