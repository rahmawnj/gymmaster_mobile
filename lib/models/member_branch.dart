class MemberBranch {
  final String id;
  final String name;
  final String branchCode;
  final String address;
  final bool isActive;

  const MemberBranch({
    required this.id,
    required this.name,
    required this.branchCode,
    required this.address,
    required this.isActive,
  });

  factory MemberBranch.fromJson(Map<String, dynamic> json) {
    return MemberBranch(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      branchCode: (json['branch_code'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      isActive: json['is_active'] == true,
    );
  }
}
