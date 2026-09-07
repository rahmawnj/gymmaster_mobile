class MemberVisitHistoryResult {
  final List<MemberVisitHistoryItem> visits;
  final MemberVisitHistoryMeta meta;

  const MemberVisitHistoryResult({required this.visits, required this.meta});
}

class MemberVisitHistoryMeta {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int limit;

  const MemberVisitHistoryMeta({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.limit,
  });

  factory MemberVisitHistoryMeta.fromJson(Map<String, dynamic> json) {
    return MemberVisitHistoryMeta(
      currentPage: _toInt(json['current_page']),
      totalPages: _toInt(json['total_pages']),
      totalItems: _toInt(json['total_items']),
      limit: _toInt(json['limit']),
    );
  }
}

class MemberVisitHistoryItem {
  final String id;
  final String branchName;
  final String deviceId;
  final String status;
  final String scannedAt;

  const MemberVisitHistoryItem({
    required this.id,
    required this.branchName,
    required this.deviceId,
    required this.status,
    required this.scannedAt,
  });

  factory MemberVisitHistoryItem.fromJson(Map<String, dynamic> json) {
    return MemberVisitHistoryItem(
      id: (json['id'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      deviceId: (json['device_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      scannedAt: (json['scanned_at'] ?? '').toString(),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '').toString()) ?? 0;
}
