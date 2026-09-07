class MemberTrainingPackage {
  final String id;
  final String trainerName;
  final String packageName;
  final String startDate;
  final String expDate;
  final String status;
  final int totalSession;
  final int remainingSessions;

  const MemberTrainingPackage({
    required this.id,
    required this.trainerName,
    required this.packageName,
    required this.startDate,
    required this.expDate,
    required this.status,
    required this.totalSession,
    required this.remainingSessions,
  });

  factory MemberTrainingPackage.fromJson(Map<String, dynamic> json) {
    return MemberTrainingPackage(
      id: (json['id'] ?? '').toString(),
      trainerName: (json['trainer_name'] ?? '').toString(),
      packageName: (json['package_name'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      expDate: (json['exp_date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      totalSession: _toInt(json['total_session']),
      remainingSessions: _toInt(json['remaining_sessions']),
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
