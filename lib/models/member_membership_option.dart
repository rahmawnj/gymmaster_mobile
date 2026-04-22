class MemberMembershipOption {
  final String id;
  final String branchId;
  final String name;
  final String description;
  final int durationDays;
  final int price;
  final int maxVisit;
  final bool isActive;

  const MemberMembershipOption({
    required this.id,
    required this.branchId,
    required this.name,
    required this.description,
    required this.durationDays,
    required this.price,
    required this.maxVisit,
    required this.isActive,
  });

  factory MemberMembershipOption.fromJson(Map<String, dynamic> json) {
    return MemberMembershipOption(
      id: (json['id'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      durationDays: _toInt(json['duration_days']),
      price: _toInt(json['price']),
      maxVisit: _toInt(json['max_visit']),
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
