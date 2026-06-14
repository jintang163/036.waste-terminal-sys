import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  static const String _keyToken = 'auth_token';
  static const String _keyUserInfo = 'user_info';
  static const String _keyEnterpriseInfo = 'enterprise_info';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyUsername = 'username';

  String? _token;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _enterpriseInfo;

  AuthService._internal();

  Future<void> init() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_keyToken);
      String? userInfoStr = prefs.getString(_keyUserInfo);
      String? enterpriseInfoStr = prefs.getString(_keyEnterpriseInfo);

      if (userInfoStr != null && userInfoStr.isNotEmpty) {
        _userInfo = jsonDecode(userInfoStr);
      }
      if (enterpriseInfoStr != null && enterpriseInfoStr.isNotEmpty) {
        _enterpriseInfo = jsonDecode(enterpriseInfoStr);
      }

      if (_token != null && _token!.isNotEmpty) {
        _apiService.setToken(_token);
      }

      _logger.i('认证服务初始化完成');
    } catch (e) {
      _logger.e('认证服务初始化失败: $e');
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      _logger.d('用户登录: $username');

      final response = await _apiService.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      Map<String, dynamic> data = response.data['data'];

      _token = data['token'];
      _userInfo = data['userInfo'];
      _enterpriseInfo = data['enterpriseInfo'];

      _apiService.setToken(_token);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_keyToken, _token!);
      }
      if (_userInfo != null) {
        await prefs.setString(_keyUserInfo, jsonEncode(_userInfo));
      }
      if (_enterpriseInfo != null) {
        await prefs.setString(_keyEnterpriseInfo, jsonEncode(_enterpriseInfo));
      }

      await prefs.setBool(_keyRememberMe, rememberMe);
      if (rememberMe) {
        await prefs.setString(_keyUsername, username);
      } else {
        await prefs.remove(_keyUsername);
      }

      _logger.i('用户登录成功: $username');
      return {
        'token': _token,
        'userInfo': _userInfo,
        'enterpriseInfo': _enterpriseInfo,
      };
    } catch (e) {
      _logger.e('用户登录失败: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      _logger.d('用户登出');

      try {
        await _apiService.post('/auth/logout');
      } catch (e) {
        _logger.w('登出接口调用失败: $e');
      }

      _token = null;
      _userInfo = null;
      _enterpriseInfo = null;
      _apiService.setToken(null);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      String? username = prefs.getString(_keyUsername);

      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserInfo);
      await prefs.remove(_keyEnterpriseInfo);

      if (rememberMe && username != null) {
        await prefs.setString(_keyUsername, username);
      }

      _logger.i('用户登出成功');
    } catch (e) {
      _logger.e('用户登出失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> autoLogin() async {
    try {
      _logger.d('尝试自动登录');

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(_keyToken);
      String? userInfoStr = prefs.getString(_keyUserInfo);
      String? enterpriseInfoStr = prefs.getString(_keyEnterpriseInfo);

      if (token == null || token.isEmpty) {
        throw Exception('未找到登录信息');
      }

      _token = token;
      if (userInfoStr != null && userInfoStr.isNotEmpty) {
        _userInfo = jsonDecode(userInfoStr);
      }
      if (enterpriseInfoStr != null && enterpriseInfoStr.isNotEmpty) {
        _enterpriseInfo = jsonDecode(enterpriseInfoStr);
      }
      _apiService.setToken(token);

      final response = await _apiService.get('/auth/check');
      if (response.statusCode == 200) {
        _logger.i('自动登录成功');
        return {
          'token': _token,
          'userInfo': _userInfo,
          'enterpriseInfo': _enterpriseInfo,
        };
      } else {
        throw Exception('Token已过期');
      }
    } catch (e) {
      _logger.w('自动登录失败: $e');
      _token = null;
      _userInfo = null;
      _enterpriseInfo = null;
      _apiService.setToken(null);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      _logger.d('刷新Token');

      final response = await _apiService.post('/auth/refresh');
      Map<String, dynamic> data = response.data['data'];

      String? newToken = data['token'];
      if (newToken != null && newToken.isNotEmpty) {
        _token = newToken;
        _apiService.setToken(newToken);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, newToken);
      }

      _logger.i('Token刷新成功');
      return {'token': _token};
    } catch (e) {
      _logger.e('刷新Token失败: $e');
      rethrow;
    }
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  String? get token => _token;

  Map<String, dynamic>? get userInfo => _userInfo;

  Map<String, dynamic>? get enterpriseInfo => _enterpriseInfo;

  Future<String?> getRememberedUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  Future<bool> getRememberMe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  Future<void> updateUserInfo(Map<String, dynamic> newUserInfo) async {
    try {
      _userInfo = newUserInfo;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserInfo, jsonEncode(newUserInfo));
      _logger.d('用户信息已更新');
    } catch (e) {
      _logger.e('更新用户信息失败: $e');
      rethrow;
    }
  }

  Future<void> updateEnterpriseInfo(Map<String, dynamic> newEnterpriseInfo) async {
    try {
      _enterpriseInfo = newEnterpriseInfo;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEnterpriseInfo, jsonEncode(newEnterpriseInfo));
      _logger.d('企业信息已更新');
    } catch (e) {
      _logger.e('更新企业信息失败: $e');
      rethrow;
    }
  }
}
