/// Shared pagination envelope parser (blueprint §5 list contract).
///
/// All `/mobile/*` list endpoints return the same shape:
/// `{items: [...], total, page, page_size, total_pages}`. This helper parses
/// that envelope into a typed [PaginatedResponse] using the same raw-map
/// style as the rest of the app (no codegen).
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  /// Parses [json] (the raw envelope map) into a [PaginatedResponse].
  ///
  /// [fromItem] converts a raw item map into [T]. Malformed/absent `items`
  /// degrades to an empty list rather than throwing.
  static PaginatedResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(fromItem).toList()
        : <T>[];
    return PaginatedResponse<T>(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );
  }
}
