enum MembershipStatus { active, pending, rejected }

class Membership {
  final String id;
  final String userId;
  final String gymId;
  final DateTime joinDate;
  final DateTime? expiryDate;
  final MembershipStatus status;
  final DateTime requestDate;

  Membership({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.joinDate,
    this.expiryDate,
    required this.status,
    required this.requestDate,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      gymId: json['gymId'] ?? '',
      joinDate: DateTime.parse(
        json['joinDate'] ?? DateTime.now().toIso8601String(),
      ),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
      status: MembershipStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => MembershipStatus.pending,
      ),
      requestDate: DateTime.parse(
        json['requestDate'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'gymId': gymId,
      'joinDate': joinDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'status': status.toString().split('.').last,
      'requestDate': requestDate.toIso8601String(),
    };
  }

  bool get isActive => status == MembershipStatus.active;
  bool get isPending => status == MembershipStatus.pending;
}
