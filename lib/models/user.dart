class User {
  final String id;
  final String userId;
  final String memberCode;
  final String name;
  final String email;
  final String phone;
  final String provinceId;
  final String cityId;
  final String districtId;
  final String subDistrictId;
  final String postCode;
  final String address;
  final String createdAt;
  final String status;
  final bool isActive;
  final String imageUrl;

  User({
    required this.id,
    required this.userId,
    required this.memberCode,
    required this.name,
    required this.email,
    required this.phone,
    required this.provinceId,
    required this.cityId,
    required this.districtId,
    required this.subDistrictId,
    required this.postCode,
    required this.address,
    required this.createdAt,
    required this.status,
    required this.isActive,
    required this.imageUrl,
  });

  String get memberId => id;
  String get accountUserId => userId;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? '').toString();
    final userId = (json['user_id'] ?? '').toString();
    final memberId = (json['member_id'] ?? '').toString();
    final memberCode = (json['member_code'] ?? '').toString();
    final qrCode = (json['qr_code'] ?? '').toString();
    final status = (json['status'] ?? '').toString();
    final isActive = status.toUpperCase() == 'ACTIVE';

    return User(
      id: memberId.isNotEmpty ? memberId : rawId,
      userId: userId.isNotEmpty ? userId : rawId,
      memberCode: memberCode.isNotEmpty ? memberCode : qrCode,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      provinceId: (json['province_id'] ?? '').toString(),
      cityId: (json['city_id'] ?? '').toString(),
      districtId: (json['district_id'] ?? '').toString(),
      subDistrictId: (json['sub_district_id'] ?? '').toString(),
      postCode: (json['post_code'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      status: status,
      isActive: isActive,
      imageUrl: (json['image_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'member_code': memberCode,
      'name': name,
      'email': email,
      'phone': phone,
      'province_id': provinceId,
      'city_id': cityId,
      'district_id': districtId,
      'sub_district_id': subDistrictId,
      'post_code': postCode,
      'address': address,
      'created_at': createdAt,
      'status': status,
      'is_active': isActive,
      'image_url': imageUrl,
    };
  }

  User copyWith({
    String? id,
    String? userId,
    String? memberCode,
    String? name,
    String? email,
    String? phone,
    String? provinceId,
    String? cityId,
    String? districtId,
    String? subDistrictId,
    String? postCode,
    String? address,
    String? createdAt,
    String? status,
    bool? isActive,
    String? imageUrl,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      memberCode: memberCode ?? this.memberCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      provinceId: provinceId ?? this.provinceId,
      cityId: cityId ?? this.cityId,
      districtId: districtId ?? this.districtId,
      subDistrictId: subDistrictId ?? this.subDistrictId,
      postCode: postCode ?? this.postCode,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
