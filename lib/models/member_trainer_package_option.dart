class MemberTrainerPackageOption {
  final String id;
  final String name;
  final String description;
  final int totalSession;
  final int durationDays;
  final int price;
  final bool isActive;

  const MemberTrainerPackageOption({
    required this.id,
    required this.name,
    required this.description,
    required this.totalSession,
    required this.durationDays,
    required this.price,
    required this.isActive,
  });

  factory MemberTrainerPackageOption.fromJson(Map<String, dynamic> json) {
    return MemberTrainerPackageOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      totalSession: _toInt(json['total_session']),
      durationDays: _toInt(json['duration_days']),
      price: _toInt(json['price']),
      isActive: json['is_active'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
