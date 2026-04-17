class User {
  final String id;
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

  User({
    required this.id,
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
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final memberCode = (json['member_code'] ?? '').toString();
    final qrCode = (json['qr_code'] ?? '').toString();
    final status = (json['status'] ?? '').toString();
    final isActive = status.toUpperCase() == 'ACTIVE';

    return User(
      id: (json['id'] ?? '').toString(),
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
    };
  }

  User copyWith({
    String? id,
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
  }) {
    return User(
      id: id ?? this.id,
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
    );
  }
}
