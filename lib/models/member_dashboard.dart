class MemberDashboard {
  final String name;
  final String memberCode;
  final String status;
  final String registeredAt;
  final List<MemberDashboardCheckin> lastCheckins;

  const MemberDashboard({
    required this.name,
    required this.memberCode,
    required this.status,
    required this.registeredAt,
    required this.lastCheckins,
  });

  factory MemberDashboard.fromJson(Map<String, dynamic> json) {
    final rawCheckins = json['last_checkins'];
    return MemberDashboard(
      name: (json['name'] ?? '').toString(),
      memberCode: (json['member_code'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      registeredAt: (json['registered_at'] ?? '').toString(),
      lastCheckins: rawCheckins is List
          ? rawCheckins
              .whereType<Map>()
              .map(
                (item) => MemberDashboardCheckin.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class MemberDashboardCheckin {
  final String branchName;
  final String checkinAt;
  final String status;

  const MemberDashboardCheckin({
    required this.branchName,
    required this.checkinAt,
    required this.status,
  });

  factory MemberDashboardCheckin.fromJson(Map<String, dynamic> json) {
    return MemberDashboardCheckin(
      branchName: (json['branch_name'] ?? '').toString(),
      checkinAt: (json['checkin_at'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}
