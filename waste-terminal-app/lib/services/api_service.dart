import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../config/app_config.dart';
import '../config/app_constants.dart';
import '../models/api_response.dart';
import '../models/page_result.dart';
import '../models/user.dart';
import '../models/enterprise.dart';
import '../models/waste_catalog.dart';
import '../models/waste_container.dart';
import '../models/waste_inventory.dart';
import '../models/waste_in_record.dart';
import '../models/waste_out_record.dart';
import '../models/transfer_order.dart';
import '../models/inventory_check.dart';
import '../models/warning_record.dart';
import '../models/sys_file.dart';
import '../models/sync_record.dart';
import '../utils/logger_util.dart';
import '../utils/sp_util.dart';

/// API服务类
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();

  String? _token;
  String? _deviceId;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  ConnectivityResult _lastConnectivityResult = ConnectivityResult.none;

  ApiService._internal() {
    _initDio();
    _initConnectivityListener();
    _loadSavedToken();
  }

  /// 初始化Dio配置
  void _initDio() {
    BaseOptions options = BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
      sendTimeout: const Duration(milliseconds: AppConfig.sendTimeout),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (status) => true,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'WasteTerminalApp/${AppConfig.appVersion}',
        'App-Version': AppConfig.appVersion,
        'Build-Number': AppConfig.buildNumber.toString(),
        'Platform': Platform.operatingSystem,
        'Platform-Version': Platform.operatingSystemVersion,
      },
    );

    _dio = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }

          if (_deviceId != null && _deviceId!.isNotEmpty) {
            options.headers['Device-Id'] = _deviceId;
          }

          final enterpriseId = SpUtil.getEnterpriseId();
          if (enterpriseId != null) {
            options.headers['Enterprise-Id'] = enterpriseId.toString();
          }

          options.headers['Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
          options.headers['Nonce'] = _generateNonce();

          if (AppConfig.enableDebugLog) {
            LoggerUtil.apiRequest('${options.method} ${options.uri}', {
              'headers': options.headers,
              'data': options.data,
              'queryParameters': options.queryParameters,
            });
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (AppConfig.enableDebugLog) {
            LoggerUtil.apiResponse(
              '${response.requestOptions.method} ${response.requestOptions.uri}',
              response.data,
            );
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          LoggerUtil.apiError(
            '${error.requestOptions.method} ${error.requestOptions.uri}',
            error.message,
          );

          if (_shouldRetry(error)) {
            try {
              final response = await _retryRequest(error.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// 初始化网络状态监听
  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        final newResult = results.first;
        if (_lastConnectivityResult != newResult) {
          _lastConnectivityResult = newResult;
          LoggerUtil.info('网络状态变化: $_lastConnectivityResult');
        }
      }
    });
  }

  /// 加载已保存的Token
  Future<void> _loadSavedToken() async {
    _token = SpUtil.getToken();
    _deviceId = SpUtil.getDeviceId();
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = await _getDeviceId();
      if (_deviceId != null) {
        await SpUtil.setDeviceId(_deviceId!);
      }
    }
  }

  /// 获取设备唯一标识
  Future<String?> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      LoggerUtil.error('获取设备ID失败', e);
    }
    return null;
  }

  /// 生成随机字符串
  String _generateNonce() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
  }

  /// 判断是否需要重试
  bool _shouldRetry(DioException error) {
    if (error.requestOptions.extra['_retryCount'] != null &&
        error.requestOptions.extra['_retryCount'] >= AppConfig.maxRetryCount) {
      return false;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504;
      default:
        return false;
    }
  }

  /// 重试请求
  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final retryCount = (requestOptions.extra['_retryCount'] ?? 0) + 1;
    requestOptions.extra['_retryCount'] = retryCount;

    LoggerUtil.warning('重试请求第 $retryCount 次: ${requestOptions.uri}');

    await Future.delayed(Duration(milliseconds: AppConfig.retryInterval * retryCount));

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
        contentType: requestOptions.contentType,
        responseType: requestOptions.responseType,
      ),
    );
  }

  /// 设置Token
  void setToken(String? token) {
    _token = token;
    if (token != null && token.isNotEmpty) {
      SpUtil.setToken(token);
    } else {
      SpUtil.removeToken();
    }
    LoggerUtil.debug('Token已${token != null ? "设置" : "清除"}');
  }

  /// 获取当前Token
  String? get token => _token;

  /// 清除Token
  void clearToken() {
    setToken(null);
  }

  /// 检测网络是否可用
  Future<bool> isNetworkAvailable() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && results.first != ConnectivityResult.none;
  }

  /// 获取当前网络类型
  Future<String> getNetworkType() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return BusinessConstants.networkTypeNone;
    final result = results.first;
    switch (result) {
      case ConnectivityResult.wifi:
        return BusinessConstants.networkTypeWifi;
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        return BusinessConstants.networkTypeMobile;
      default:
        return BusinessConstants.networkTypeNone;
    }
  }

  /// 获取网络状态变化流
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  // ==================== 基础HTTP方法 ====================

  Future<Response> _request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool checkNetwork = true,
  }) async {
    try {
      if (checkNetwork) {
        bool hasNetwork = await isNetworkAvailable();
        if (!hasNetwork) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            error: '网络不可用，请检查网络连接',
            type: DioExceptionType.connectionError,
          );
        }
      }

      final response = await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options ?? Options(method: method),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _request('GET', path, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _request('POST', path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _request('PUT', path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _request('DELETE', path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  // ==================== 响应和错误处理 ====================

  Response _handleResponse(Response response) {
    if (response.statusCode == 401) {
      setToken(null);
      throw ApiException(
        code: 401,
        message: '登录已过期，请重新登录',
      );
    }

    if (response.statusCode == 403) {
      throw ApiException(
        code: 403,
        message: '没有权限访问该资源',
      );
    }

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int? ?? data['status'] as int?;
      final message = data['msg'] as String? ?? data['message'] as String?;

      if (code == 200 || code == 0) {
        return response;
      } else {
        throw ApiException(
          code: code ?? response.statusCode ?? -1,
          message: message ?? '请求失败',
        );
      }
    }

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return response;
    }

    throw ApiException(
      code: response.statusCode ?? -1,
      message: '请求失败: ${response.statusMessage}',
    );
  }

  ApiException _handleError(DioException error) {
    String errorMessage;
    int errorCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage = '连接超时，请检查网络';
        errorCode = HttpStatus.requestTimeout;
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = '发送超时，请检查网络';
        errorCode = HttpStatus.requestTimeout;
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = '接收超时，请检查网络';
        errorCode = HttpStatus.requestTimeout;
        break;
      case DioExceptionType.connectionError:
        errorMessage = '网络连接失败，请检查网络';
        errorCode = HttpStatus.serviceUnavailable;
        break;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          errorMessage = '登录已过期，请重新登录';
        } else if (statusCode == 403) {
          errorMessage = '没有权限访问';
        } else {
          errorMessage = _getHttpErrorMessage(statusCode);
        }
        errorCode = statusCode ?? HttpStatus.internalServerError;
        break;
      case DioExceptionType.cancel:
        errorMessage = '请求已取消';
        errorCode = -1;
        break;
      case DioExceptionType.badCertificate:
        errorMessage = '证书验证失败';
        errorCode = -2;
        break;
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          errorMessage = '网络连接失败，请检查网络';
        } else {
          errorMessage = error.message ?? '未知错误';
        }
        errorCode = -1;
        break;
      default:
        errorMessage = error.message ?? '未知错误';
        errorCode = -1;
    }

    return ApiException(code: errorCode, message: errorMessage);
  }

  String _getHttpErrorMessage(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '未授权，请重新登录';
      case 403:
        return '拒绝访问';
      case 404:
        return '请求资源不存在';
      case 405:
        return '请求方法不允许';
      case 408:
        return '请求超时';
      case 409:
        return '请求冲突';
      case 413:
        return '请求体过大';
      case 415:
        return '不支持的媒体类型';
      case 422:
        return '数据验证失败';
      case 429:
        return '请求过于频繁，请稍后再试';
      case 500:
        return '服务器内部错误';
      case 501:
        return '服务未实现';
      case 502:
        return '网关错误';
      case 503:
        return '服务不可用';
      case 504:
        return '网关超时';
      default:
        return '网络请求失败 (HTTP $statusCode)';
    }
  }

  // ==================== 解析响应数据 ====================

  T? parseData<T>(Response response, T Function(dynamic) fromJson) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final result = data['data'];
      if (result == null) return null;
      return fromJson(result);
    }
    return null;
  }

  List<T> parseList<T>(Response response, T Function(dynamic) fromJson) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final result = data['data'];
      if (result is List) {
        return result.map((e) => fromJson(e)).toList();
      }
    }
    return [];
  }

  PageResult<T> parsePage<T>(Response response, T Function(dynamic) fromJson) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final result = data['data'] as Map<String, dynamic>?;
      if (result != null) {
        return PageResult.fromJson(result, fromJson);
      }
    }
    return PageResult<T>(list: [], total: 0, pageNum: 1, pageSize: 10);
  }

  // ==================== 文件上传 ====================

  Future<Response> uploadFile(
    String filePath, {
    String fileKey = 'file',
    String? fileName,
    String? bizType,
    String? bizId,
    Map<String, dynamic>? extraData,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      bool hasNetwork = await isNetworkAvailable();
      if (!hasNetwork) {
        throw DioException(
          requestOptions: RequestOptions(path: ApiConstants.fileUpload),
          error: '网络不可用',
          type: DioExceptionType.connectionError,
        );
      }

      final formData = FormData.fromMap({
        fileKey: await MultipartFile.fromFile(
          filePath,
          filename: fileName ?? filePath.split('/').last,
        ),
        if (bizType != null) 'bizType': bizType,
        if (bizId != null) 'bizId': bizId,
        if (extraData != null) ...extraData,
      });

      final response = await _dio.post(
        ApiConstants.fileUpload,
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );

      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<SysFile>> uploadMultipleFiles(
    List<String> filePaths, {
    String fileKey = 'files',
    String? bizType,
    String? bizId,
    Map<String, dynamic>? extraData,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      bool hasNetwork = await isNetworkAvailable();
      if (!hasNetwork) {
        throw ApiException(code: -1, message: '网络不可用');
      }

      final files = <MultipartFile>[];
      for (final path in filePaths) {
        files.add(await MultipartFile.fromFile(
          path,
          filename: path.split('/').last,
        ));
      }

      final formData = FormData.fromMap({
        fileKey: files,
        if (bizType != null) 'bizType': bizType,
        if (bizId != null) 'bizId': bizId,
        if (extraData != null) ...extraData,
      });

      final response = await _dio.post(
        ApiConstants.fileBatchUpload,
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );

      final handledResponse = _handleResponse(response);
      return parseList<SysFile>(handledResponse, (e) => SysFile.fromJson(e));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ==================== 认证API ====================

  /// 用户登录
  Future<User> login(String username, String password) async {
    final response = await post(
      ApiConstants.authLogin,
      data: {
        'username': username,
        'password': password,
        'deviceId': _deviceId,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      setToken(token);
    }

    final userData = data['user'] ?? data;
    final user = User.fromJson(Map<String, dynamic>.from(userData));
    if (user.username != null) {
      await SpUtil.saveLoginUsername(user.username!);
    }
    if (user.id != null) {
      await SpUtil.setUserId(user.id!);
    }

    return user;
  }

  /// 用户登出
  Future<void> logout() async {
    try {
      await post(ApiConstants.authLogout);
    } catch (e) {
      LoggerUtil.warning('登出请求失败: $e');
    } finally {
      clearToken();
    }
  }

  /// 刷新Token
  Future<String?> refreshToken() async {
    try {
      final response = await post(ApiConstants.authRefreshToken);
      final data = response.data['data'] as Map<String, dynamic>?;
      final newToken = data?['token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        setToken(newToken);
        return newToken;
      }
    } catch (e) {
      LoggerUtil.error('刷新Token失败', e);
    }
    return null;
  }

  /// 获取当前用户信息
  Future<User> getUserInfo() async {
    final response = await get(ApiConstants.authUserInfo);
    final data = response.data['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final response = await post(
      ApiConstants.authChangePassword,
      data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );
    return response.data['code'] == 200;
  }

  // ==================== 企业API ====================

  /// 获取企业信息
  Future<Enterprise> getEnterpriseInfo() async {
    final response = await get(ApiConstants.enterpriseInfo);
    final data = response.data['data'] as Map<String, dynamic>;
    final enterprise = Enterprise.fromJson(data);
    if (enterprise.id != null) {
      await SpUtil.setEnterpriseId(enterprise.id!);
    }
    return enterprise;
  }

  // ==================== 危废名录API ====================

  /// 获取危废名录列表
  Future<List<WasteCatalog>> getWasteCatalogList({
    String? keyword,
    String? wasteCategory,
    String? wasteType,
  }) async {
    final response = await get(
      ApiConstants.wasteCatalogList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (wasteType != null) 'wasteType': wasteType,
      },
    );
    return parseList<WasteCatalog>(response, (e) => WasteCatalog.fromJson(e));
  }

  /// 分页获取危废名录
  Future<PageResult<WasteCatalog>> getWasteCatalogPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? wasteCategory,
    String? wasteType,
  }) async {
    final response = await get(
      ApiConstants.wasteCatalogPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (wasteType != null) 'wasteType': wasteType,
      },
    );
    return parsePage<WasteCatalog>(response, (e) => WasteCatalog.fromJson(e));
  }

  /// 获取危废名录详情
  Future<WasteCatalog?> getWasteCatalogDetail(int id) async {
    final response = await get('${ApiConstants.wasteCatalogDetail}/$id');
    return parseData<WasteCatalog>(response, (e) => WasteCatalog.fromJson(e));
  }

  // ==================== 容器API ====================

  /// 获取容器列表
  Future<List<WasteContainer>> getContainerList({
    String? keyword,
    String? containerType,
    int? status,
  }) async {
    final response = await get(
      ApiConstants.containerList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (containerType != null) 'containerType': containerType,
        if (status != null) 'status': status,
      },
    );
    return parseList<WasteContainer>(response, (e) => WasteContainer.fromJson(e));
  }

  /// 分页获取容器
  Future<PageResult<WasteContainer>> getContainerPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? containerType,
    int? status,
  }) async {
    final response = await get(
      ApiConstants.containerPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (containerType != null) 'containerType': containerType,
        if (status != null) 'status': status,
      },
    );
    return parsePage<WasteContainer>(response, (e) => WasteContainer.fromJson(e));
  }

  /// 获取容器详情
  Future<WasteContainer?> getContainerDetail(int id) async {
    final response = await get('${ApiConstants.containerDetail}/$id');
    return parseData<WasteContainer>(response, (e) => WasteContainer.fromJson(e));
  }

  /// 根据容器编码查询
  Future<WasteContainer?> getContainerByCode(String code) async {
    final response = await get(
      ApiConstants.containerDetail,
      queryParameters: {'containerCode': code},
    );
    return parseData<WasteContainer>(response, (e) => WasteContainer.fromJson(e));
  }

  // ==================== 库存API ====================

  /// 获取库存列表
  Future<List<WasteInventory>> getInventoryList({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? storageLocation,
  }) async {
    final response = await get(
      ApiConstants.inventoryList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (wasteCode != null) 'wasteCode': wasteCode,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (storageLocation != null) 'storageLocation': storageLocation,
      },
    );
    return parseList<WasteInventory>(response, (e) => WasteInventory.fromJson(e));
  }

  /// 分页获取库存
  Future<PageResult<WasteInventory>> getInventoryPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? storageLocation,
  }) async {
    final response = await get(
      ApiConstants.inventoryPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (wasteCode != null) 'wasteCode': wasteCode,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (storageLocation != null) 'storageLocation': storageLocation,
      },
    );
    return parsePage<WasteInventory>(response, (e) => WasteInventory.fromJson(e));
  }

  /// 获取库存详情
  Future<WasteInventory?> getInventoryDetail(int id) async {
    final response = await get('${ApiConstants.inventoryDetail}/$id');
    return parseData<WasteInventory>(response, (e) => WasteInventory.fromJson(e));
  }

  /// 根据容器ID获取库存
  Future<List<WasteInventory>> getInventoryByContainer(String containerCode) async {
    final response = await get(
      ApiConstants.inventoryByContainer,
      queryParameters: {'containerCode': containerCode},
    );
    return parseList<WasteInventory>(response, (e) => WasteInventory.fromJson(e));
  }

  /// 获取库存统计
  Future<Map<String, dynamic>> getInventoryStats() async {
    final response = await get(ApiConstants.inventoryStats);
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  // ==================== 入库API ====================

  /// 提交入库记录
  Future<WasteInRecord> submitWasteIn(WasteInRecord record) async {
    final response = await post(
      ApiConstants.wasteInAdd,
      data: record.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return WasteInRecord.fromJson(data);
  }

  /// 批量提交入库记录
  Future<List<WasteInRecord>> submitWasteInBatch(List<WasteInRecord> records) async {
    final response = await post(
      ApiConstants.wasteInBatchAdd,
      data: records.map((e) => e.toJson()).toList(),
    );
    return parseList<WasteInRecord>(response, (e) => WasteInRecord.fromJson(e));
  }

  /// 获取入库记录列表
  Future<List<WasteInRecord>> getWasteInList({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? containerCode,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.wasteInList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (wasteCode != null) 'wasteCode': wasteCode,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (containerCode != null) 'containerCode': containerCode,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parseList<WasteInRecord>(response, (e) => WasteInRecord.fromJson(e));
  }

  /// 分页获取入库记录
  Future<PageResult<WasteInRecord>> getWasteInPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? containerCode,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.wasteInPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (wasteCode != null) 'wasteCode': wasteCode,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (containerCode != null) 'containerCode': containerCode,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parsePage<WasteInRecord>(response, (e) => WasteInRecord.fromJson(e));
  }

  /// 获取入库记录详情
  Future<WasteInRecord?> getWasteInDetail(int id) async {
    final response = await get('${ApiConstants.wasteInDetail}/$id');
    return parseData<WasteInRecord>(response, (e) => WasteInRecord.fromJson(e));
  }

  // ==================== 出库API ====================

  /// 提交出库记录
  Future<WasteOutRecord> submitWasteOut(WasteOutRecord record) async {
    final response = await post(
      ApiConstants.wasteOutAdd,
      data: record.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return WasteOutRecord.fromJson(data);
  }

  /// 获取出库记录列表
  Future<List<WasteOutRecord>> getWasteOutList({
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? containerCode,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.wasteOutList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (wasteCode != null) 'wasteCode': wasteCode,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (containerCode != null) 'containerCode': containerCode,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parseList<WasteOutRecord>(response, (e) => WasteOutRecord.fromJson(e));
  }

  /// 分页获取出库记录
  Future<PageResult<WasteOutRecord>> getWasteOutPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? wasteCode,
    String? wasteCategory,
    String? containerCode,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.wasteOutPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (wasteCode != null) 'wasteCode': wasteCode,
        if (wasteCategory != null) 'wasteCategory': wasteCategory,
        if (containerCode != null) 'containerCode': containerCode,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parsePage<WasteOutRecord>(response, (e) => WasteOutRecord.fromJson(e));
  }

  /// 获取出库记录详情
  Future<WasteOutRecord?> getWasteOutDetail(int id) async {
    final response = await get('${ApiConstants.wasteOutDetail}/$id');
    return parseData<WasteOutRecord>(response, (e) => WasteOutRecord.fromJson(e));
  }

  // ==================== 联单API ====================

  /// 创建联单
  Future<TransferOrder> createTransferOrder(TransferOrder order) async {
    final response = await post(
      ApiConstants.transferOrderCreate,
      data: order.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return TransferOrder.fromJson(data);
  }

  /// 更新联单
  Future<TransferOrder> updateTransferOrder(TransferOrder order) async {
    final response = await put(
      ApiConstants.transferOrderUpdate,
      data: order.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return TransferOrder.fromJson(data);
  }

  /// 获取联单列表
  Future<List<TransferOrder>> getTransferOrderList({
    String? keyword,
    String? orderNo,
    int? status,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.transferOrderList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (orderNo != null) 'orderNo': orderNo,
        if (status != null) 'status': status,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parseList<TransferOrder>(response, (e) => TransferOrder.fromJson(e));
  }

  /// 分页获取联单
  Future<PageResult<TransferOrder>> getTransferOrderPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? orderNo,
    int? status,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.transferOrderPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (orderNo != null) 'orderNo': orderNo,
        if (status != null) 'status': status,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parsePage<TransferOrder>(response, (e) => TransferOrder.fromJson(e));
  }

  /// 获取联单详情
  Future<TransferOrder?> getTransferOrderDetail(int id) async {
    final response = await get('${ApiConstants.transferOrderDetail}/$id');
    return parseData<TransferOrder>(response, (e) => TransferOrder.fromJson(e));
  }

  /// 联单签收
  Future<bool> signTransferOrder(int orderId, {String? signPhoto}) async {
    final response = await post(
      ApiConstants.transferOrderSign,
      data: {
        'id': orderId,
        if (signPhoto != null) 'signPhoto': signPhoto,
      },
    );
    return response.data['code'] == 200;
  }

  /// 联单完成
  Future<bool> completeTransferOrder(int orderId, {String? receiptPhoto}) async {
    final response = await post(
      ApiConstants.transferOrderComplete,
      data: {
        'id': orderId,
        if (receiptPhoto != null) 'receiptPhoto': receiptPhoto,
      },
    );
    return response.data['code'] == 200;
  }

  /// 取消联单
  Future<bool> cancelTransferOrder(int orderId, {String? reason}) async {
    final response = await post(
      ApiConstants.transferOrderCancel,
      data: {
        'id': orderId,
        if (reason != null) 'reason': reason,
      },
    );
    return response.data['code'] == 200;
  }

  // ==================== 盘点API ====================

  /// 创建盘点单
  Future<InventoryCheck> createInventoryCheck(InventoryCheck check) async {
    final response = await post(
      ApiConstants.inventoryCheckCreate,
      data: check.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return InventoryCheck.fromJson(data);
  }

  /// 提交盘点结果
  Future<InventoryCheck> submitInventoryCheck(InventoryCheck check) async {
    final response = await post(
      ApiConstants.inventoryCheckSubmit,
      data: check.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return InventoryCheck.fromJson(data);
  }

  /// 获取盘点单列表
  Future<List<InventoryCheck>> getInventoryCheckList({
    String? keyword,
    String? checkNo,
    String? checkType,
    int? status,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.inventoryCheckList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (checkNo != null) 'checkNo': checkNo,
        if (checkType != null) 'checkType': checkType,
        if (status != null) 'status': status,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parseList<InventoryCheck>(response, (e) => InventoryCheck.fromJson(e));
  }

  /// 分页获取盘点单
  Future<PageResult<InventoryCheck>> getInventoryCheckPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? checkNo,
    String? checkType,
    int? status,
    String? startTime,
    String? endTime,
  }) async {
    final response = await get(
      ApiConstants.inventoryCheckPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (checkNo != null) 'checkNo': checkNo,
        if (checkType != null) 'checkType': checkType,
        if (status != null) 'status': status,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
    return parsePage<InventoryCheck>(response, (e) => InventoryCheck.fromJson(e));
  }

  /// 获取盘点单详情
  Future<InventoryCheck?> getInventoryCheckDetail(int id) async {
    final response = await get('${ApiConstants.inventoryCheckDetail}/$id');
    return parseData<InventoryCheck>(response, (e) => InventoryCheck.fromJson(e));
  }

  // ==================== 预警API ====================

  /// 获取预警列表
  Future<List<WarningRecord>> getWarningList({
    String? keyword,
    int? warningLevel,
    int? handleStatus,
    String? warningType,
  }) async {
    final response = await get(
      ApiConstants.warningList,
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        if (warningLevel != null) 'warningLevel': warningLevel,
        if (handleStatus != null) 'handleStatus': handleStatus,
        if (warningType != null) 'warningType': warningType,
      },
    );
    return parseList<WarningRecord>(response, (e) => WarningRecord.fromJson(e));
  }

  /// 分页获取预警
  Future<PageResult<WarningRecord>> getWarningPage({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    int? warningLevel,
    int? handleStatus,
    String? warningType,
  }) async {
    final response = await get(
      ApiConstants.warningPage,
      queryParameters: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (warningLevel != null) 'warningLevel': warningLevel,
        if (handleStatus != null) 'handleStatus': handleStatus,
        if (warningType != null) 'warningType': warningType,
      },
    );
    return parsePage<WarningRecord>(response, (e) => WarningRecord.fromJson(e));
  }

  /// 获取预警详情
  Future<WarningRecord?> getWarningDetail(int id) async {
    final response = await get('${ApiConstants.warningDetail}/$id');
    return parseData<WarningRecord>(response, (e) => WarningRecord.fromJson(e));
  }

  /// 处理预警
  Future<bool> handleWarning(
    int id, {
    required String handleRemark,
    List<String>? photoPaths,
  }) async {
    final response = await post(
      ApiConstants.warningHandle,
      data: {
        'id': id,
        'handleRemark': handleRemark,
        if (photoPaths != null) 'photos': photoPaths,
      },
    );
    return response.data['code'] == 200;
  }

  /// 获取预警统计
  Future<Map<String, dynamic>> getWarningStats() async {
    final response = await get(ApiConstants.warningStats);
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  // ==================== 同步API ====================

  /// 拉取危废名录数据
  Future<List<WasteCatalog>> syncPullWasteCatalog({DateTime? lastSyncTime}) async {
    final response = await get(
      ApiConstants.syncPullWasteCatalog,
      queryParameters: {
        if (lastSyncTime != null) 'lastSyncTime': lastSyncTime.toIso8601String(),
      },
    );
    return parseList<WasteCatalog>(response, (e) => WasteCatalog.fromJson(e));
  }

  /// 拉取容器数据
  Future<List<WasteContainer>> syncPullContainer({DateTime? lastSyncTime}) async {
    final response = await get(
      ApiConstants.syncPullContainer,
      queryParameters: {
        if (lastSyncTime != null) 'lastSyncTime': lastSyncTime.toIso8601String(),
      },
    );
    return parseList<WasteContainer>(response, (e) => WasteContainer.fromJson(e));
  }

  /// 拉取库存数据
  Future<List<WasteInventory>> syncPullInventory({DateTime? lastSyncTime}) async {
    final response = await get(
      ApiConstants.syncPullInventory,
      queryParameters: {
        if (lastSyncTime != null) 'lastSyncTime': lastSyncTime.toIso8601String(),
      },
    );
    return parseList<WasteInventory>(response, (e) => WasteInventory.fromJson(e));
  }

  /// 拉取预警数据
  Future<List<WarningRecord>> syncPullWarning({DateTime? lastSyncTime}) async {
    final response = await get(
      ApiConstants.syncPullWarning,
      queryParameters: {
        if (lastSyncTime != null) 'lastSyncTime': lastSyncTime.toIso8601String(),
      },
    );
    return parseList<WarningRecord>(response, (e) => WarningRecord.fromJson(e));
  }

  /// 推送入库记录
  Future<SyncResult> syncPushWasteIn(List<WasteInRecord> records) async {
    final response = await post(
      ApiConstants.syncPushWasteIn,
      data: records.map((e) => e.toJson()).toList(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] ?? {});
    return SyncResult(
      success: data['success'] ?? 0,
      failed: data['failed'] ?? 0,
      total: data['total'] ?? records.length,
      failedIds: (data['failedIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      messages: (data['messages'] as List?)?.cast<String>() ?? [],
    );
  }

  /// 推送出库记录
  Future<SyncResult> syncPushWasteOut(List<WasteOutRecord> records) async {
    final response = await post(
      ApiConstants.syncPushWasteOut,
      data: records.map((e) => e.toJson()).toList(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] ?? {});
    return SyncResult(
      success: data['success'] ?? 0,
      failed: data['failed'] ?? 0,
      total: data['total'] ?? records.length,
      failedIds: (data['failedIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      messages: (data['messages'] as List?)?.cast<String>() ?? [],
    );
  }

  /// 推送盘点记录
  Future<SyncResult> syncPushInventoryCheck(List<InventoryCheck> records) async {
    final response = await post(
      ApiConstants.syncPushInventoryCheck,
      data: records.map((e) => e.toJson()).toList(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] ?? {});
    return SyncResult(
      success: data['success'] ?? 0,
      failed: data['failed'] ?? 0,
      total: data['total'] ?? records.length,
      failedIds: (data['failedIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      messages: (data['messages'] as List?)?.cast<String>() ?? [],
    );
  }

  /// 推送联单
  Future<SyncResult> syncPushTransferOrder(List<TransferOrder> orders) async {
    final response = await post(
      ApiConstants.syncPushTransferOrder,
      data: orders.map((e) => e.toJson()).toList(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] ?? {});
    return SyncResult(
      success: data['success'] ?? 0,
      failed: data['failed'] ?? 0,
      total: data['total'] ?? orders.length,
      failedIds: (data['failedIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      messages: (data['messages'] as List?)?.cast<String>() ?? [],
    );
  }

  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
    _dio.close();
  }
}

/// API异常类
class ApiException implements Exception {
  final int code;
  final String message;

  ApiException({required this.code, required this.message});

  @override
  String toString() {
    return 'ApiException: code=$code, message=$message';
  }
}

/// 同步结果类
class SyncResult {
  final int success;
  final int failed;
  final int total;
  final List<String> failedIds;
  final List<String> messages;

  SyncResult({
    required this.success,
    required this.failed,
    required this.total,
    required this.failedIds,
    required this.messages,
  });

  bool get allSuccess => failed == 0;

  bool get hasFailure => failed > 0;

  double get successRate => total == 0 ? 1.0 : success / total;
}
