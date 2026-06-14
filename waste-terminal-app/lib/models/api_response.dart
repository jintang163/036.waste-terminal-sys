class ApiResponse<T> {
  final int? code;
  final String? message;
  final T? data;
  final int? timestamp;

  ApiResponse({
    this.code,
    this.message,
    this.data,
    this.timestamp,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int?,
      message: json['message'] as String?,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      timestamp: json['timestamp'] as int?,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T data)? toJsonT) {
    return {
      'code': code,
      'message': message,
      'data': data != null && toJsonT != null ? toJsonT(data!) : data,
      'timestamp': timestamp,
    };
  }

  bool get isSuccess => code == 200;

  bool get isFailure => code != 200;
}
