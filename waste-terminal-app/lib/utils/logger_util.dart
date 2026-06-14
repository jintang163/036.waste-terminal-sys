import 'package:logger/logger.dart';

class LoggerUtil {
  LoggerUtil._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void verbose(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error: error, stackTrace: stackTrace);
  }

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static void log(
    Level level,
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.log(level, message, error: error, stackTrace: stackTrace);
  }

  static void json(String tag, Map<String, dynamic> json) {
    _logger.i('$tag: $json');
  }

  static void apiRequest(String url, Map<String, dynamic> params) {
    debug('API Request: $url');
    debug('Params: $params');
  }

  static void apiResponse(String url, dynamic data) {
    debug('API Response: $url');
    debug('Data: $data');
  }

  static void apiError(String url, dynamic error) {
    error('API Error: $url');
    error('Error: $error');
  }

  static void lifecycle(String className, String state) {
    debug('Lifecycle: $className - $state');
  }

  static void blocEvent(String bloc, String event) {
    info('Bloc Event: $bloc - $event');
  }

  static void blocState(String bloc, String state) {
    info('Bloc State: $bloc - $state');
  }

  static void route(String from, String to, [String? action]) {
    info('Route: $from -> $to${action != null ? ' ($action)' : ''}');
  }

  static void dbOperation(String operation, String table, [dynamic data]) {
    debug('DB: $operation on $table');
    if (data != null) {
      debug('Data: $data');
    }
  }

  static void permission(String permission, String status) {
    info('Permission: $permission - $status');
  }

  static void sync(String type, String status, [String? message]) {
    info('Sync: $type - $status${message != null ? ' - $message' : ''}');
  }

  static void close() {
    _logger.close();
  }
}
