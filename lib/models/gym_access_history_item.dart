class GymAccessHistoryItem {
  final String id;
  final String accessMethod;
  final String accessedAt;

  const GymAccessHistoryItem({
    required this.id,
    required this.accessMethod,
    required this.accessedAt,
  });

  factory GymAccessHistoryItem.fromJson(Map<String, dynamic> json) {
    return GymAccessHistoryItem(
      id: (json['id'] ?? '').toString(),
      accessMethod: (json['access_method'] ?? '').toString(),
      accessedAt: (json['accessed_at'] ?? '').toString(),
    );
  }
}
