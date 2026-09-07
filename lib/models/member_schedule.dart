class MemberSchedule {
  final int id;
  final String trainerName;
  final String packageName;
  final String sessionDate;
  final String startTime;
  final String endTime;
  final String status;

  const MemberSchedule({
    required this.id,
    required this.trainerName,
    required this.packageName,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory MemberSchedule.fromJson(Map<String, dynamic> json) {
    return MemberSchedule(
      id: _toInt(json['id']),
      trainerName: (json['trainer_name'] ?? '').toString(),
      packageName: (json['package_name'] ?? '').toString(),
      sessionDate: (json['session_date'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
