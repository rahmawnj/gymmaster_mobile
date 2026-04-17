import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/user.dart';
import 'api_config.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  const AuthService();

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.apiBase}auth/login'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));

    return _parseAuthResponse(response);
  }

  Future<User> fetchMemberProfile({
    required String userId,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.apiBase}members/user/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': '$tokenType $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    return _parseMemberResponse(response, userId: userId);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required int provinceId,
    required int cityId,
    required int districtId,
    required int subDistrictId,
    required String postCode,
    required String address,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.apiBase}auth/register'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'phone': phone,
            'province_id': provinceId,
            'city_id': cityId,
            'district_id': districtId,
            'sub_district_id': subDistrictId,
            'post_code': postCode,
            'address': address,
          }),
        )
        .timeout(const Duration(seconds: 20));

    return _parseAuthResponse(response);
  }

  Future<User> updateMemberProfile({
    required String memberCode,
    required String name,
    required String phone,
    required String address,
    required String provinceId,
    required String cityId,
    required String districtId,
    required String subDistrictId,
    required String postCode,
  }) async {
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.apiBase}auth/profile/member/update/$memberCode',
          ),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': name,
            'phone': phone,
            'address': address,
            'province_id': provinceId,
            'city_id': cityId,
            'district_id': districtId,
            'sub_district_id': subDistrictId,
            'post_code': postCode,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final user = data['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return User.fromJson(user);
    }

    throw AuthException(_extractMessage(body, response.statusCode));
  }

  AuthSession _parseAuthResponse(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AuthSession.fromJson(body);
    }

    throw AuthException(_extractMessage(body, response.statusCode));
  }

  User _parseMemberResponse(http.Response response, {required String userId}) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      if (data.isEmpty) {
        throw const AuthException('Data member tidak ditemukan.');
      }

      final memberCode = (data['member_code'] ?? '').toString();
      final qrCode = (data['qr_code'] ?? '').toString();

      final status = (data['status'] ?? '').toString();
      final isActive = status.toUpperCase() == 'ACTIVE';

      return User(
        id: userId,
        memberCode: memberCode.isNotEmpty ? memberCode : qrCode,
        name: (data['name'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        phone: (data['phone'] ?? '').toString(),
        provinceId: (data['province_id'] ?? '').toString(),
        cityId: (data['city_id'] ?? '').toString(),
        districtId: (data['district_id'] ?? '').toString(),
        subDistrictId: (data['sub_district_id'] ?? data['sub_district'] ?? '').toString(),
        postCode: (data['post_code'] ?? '').toString(),
        address: (data['address'] ?? '').toString(),
        createdAt: (data['created_at'] ?? '').toString(),
        status: status,
        isActive: isActive,
      );
    }

    throw AuthException(_extractMessage(body, response.statusCode));
  }

  Map<String, dynamic> _decodeBody(String rawBody) {
    if (rawBody.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  String _extractMessage(Map<String, dynamic> body, int statusCode) {
    final message = body['message']?.toString();
    final errors = body['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value != null) {
          return value.toString();
        }
      }
    }

    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Request gagal dengan status $statusCode.';
  }
}
