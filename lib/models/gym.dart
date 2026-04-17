class Gym {
  final String id;
  final String gymCode;
  final String name;
  final String city;
  final String address;
  final String description;
  final bool isJoined;
  final bool canRequestJoin;
  final String status;
  final String? requestedAt;
  final String? approvedAt;
  final String? joinedAt;

  const Gym({
    required this.id,
    required this.gymCode,
    required this.name,
    required this.city,
    required this.address,
    required this.description,
    required this.isJoined,
    required this.canRequestJoin,
    required this.status,
    this.requestedAt,
    this.approvedAt,
    this.joinedAt,
  });

  String get location => city;
  String get normalizedStatus => status.trim().toLowerCase();
  bool get isPending => normalizedStatus == 'pending';
  bool get isRequest => normalizedStatus == 'request';
  bool get canOpenDetail => isJoined;
  bool get canJoinAction => !isJoined;

  String get actionLabel {
    if (isJoined) return 'View Details';
    if (isPending) return 'Join Pending';
    return 'Join Request';
  }

  String get statusLabel {
    if (isJoined) return 'Joined';
    if (isPending) return 'Pending';
    if (isRequest) return 'Request';
    return status;
  }

  factory Gym.fromApiJson(Map<String, dynamic> json) {
    return Gym(
      id: (json['id'] ?? '').toString(),
      gymCode: (json['gym_code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isJoined: json['is_joined'] == true,
      canRequestJoin: json['can_request_join'] == true,
      status: (json['status'] ?? '').toString(),
      requestedAt: json['requested_at']?.toString(),
      approvedAt: json['approved_at']?.toString(),
      joinedAt: json['joined_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_code': gymCode,
      'name': name,
      'city': city,
      'address': address,
      'description': description,
      'is_joined': isJoined,
      'can_request_join': canRequestJoin,
      'status': status,
      'requested_at': requestedAt,
      'approved_at': approvedAt,
      'joined_at': joinedAt,
    };
  }

  Gym copyWith({
    String? id,
    String? gymCode,
    String? name,
    String? city,
    String? address,
    String? description,
    bool? isJoined,
    bool? canRequestJoin,
    String? status,
    String? requestedAt,
    String? approvedAt,
    String? joinedAt,
  }) {
    return Gym(
      id: id ?? this.id,
      gymCode: gymCode ?? this.gymCode,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      description: description ?? this.description,
      isJoined: isJoined ?? this.isJoined,
      canRequestJoin: canRequestJoin ?? this.canRequestJoin,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
