class PageResult<T> {
  final int? total;
  final int? pageNum;
  final int? pageSize;
  final int? pages;
  final List<T>? records;

  PageResult({
    this.total,
    this.pageNum,
    this.pageSize,
    this.pages,
    this.records,
  });

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    final recordsJson = json['records'] as List<dynamic>?;
    return PageResult<T>(
      total: json['total'] as int?,
      pageNum: json['pageNum'] as int?,
      pageSize: json['pageSize'] as int?,
      pages: json['pages'] as int?,
      records: recordsJson?.map((e) => fromJsonT(e)).toList(),
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T data) toJsonT) {
    return {
      'total': total,
      'pageNum': pageNum,
      'pageSize': pageSize,
      'pages': pages,
      'records': records?.map((e) => toJsonT(e)).toList(),
    };
  }

  bool get isEmpty => records == null || records!.isEmpty;

  bool get isNotEmpty => records != null && records!.isNotEmpty;

  int get itemCount => records?.length ?? 0;

  bool get hasMore =>
      pageNum != null && pages != null && pageNum! < pages!;

  bool get isLastPage => !hasMore;
}
