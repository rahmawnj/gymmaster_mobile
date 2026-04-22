class MemberMembership {
  final String id;
  final String branchName;
  final String membershipName;
  final String startDate;
  final String expDate;
  final String status;

  const MemberMembership({
    required this.id,
    required this.branchName,
    required this.membershipName,
    required this.startDate,
    required this.expDate,
    required this.status,
  });

  factory MemberMembership.fromJson(Map<String, dynamic> json) {
    return MemberMembership(
      id: (json['id'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      membershipName: (json['membership_name'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      expDate: (json['exp_date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}
