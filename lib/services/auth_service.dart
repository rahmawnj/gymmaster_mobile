import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const String _mobileBaseUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/';

  const AuthService();

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_mobileApiBase}auth/login'),
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
    final uri = Uri.parse('${ApiConfig.apiBase}members/user/$userId');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$tokenType $token',
    };

    debugPrint('===== MEMBER PROFILE REQUEST START =====');
    debugPrint('GET $uri');
    debugPrint('Request headers: $headers');

    final response = await http
        .get(
          uri,
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== MEMBER PROFILE REQUEST END =====');

    return _parseMemberResponse(response, userId: userId);
  }

  Future<User> fetchMemberMobileProfile({
    required String memberId,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final uri = Uri.parse('${_mobileApiBase}members/profile/$memberId');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$tokenType $token',
    };

    debugPrint('===== MOBILE PROFILE REQUEST START =====');
    debugPrint('GET $uri');
    debugPrint('Request headers: $headers');

    final response = await http
        .get(
          uri,
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== MOBILE PROFILE REQUEST END =====');

    return _parseMobileMemberProfileResponse(response);
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
          Uri.parse('${_mobileApiBase}auth/register'),
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
    required String name,
    required String phone,
    required String address,
    required String token,
    String tokenType = 'Bearer',
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_mobileApiBase}members/profile/update'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] =
        '$normalizedTokenType $normalizedToken';
    request.fields['name'] = name;
    request.fields['phone'] = phone;
    request.fields['address'] = address;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFileName?.trim().isNotEmpty == true
              ? imageFileName!.trim()
              : 'profile.jpg',
        ),
      );
    }

    debugPrint('===== PROFILE UPDATE REQUEST START =====');
    debugPrint('POST ${request.url}');
    debugPrint('Request headers: ${request.headers}');
    debugPrint('Request fields: ${request.fields}');
    debugPrint(
      'Request file: ${imageFileName?.trim().isNotEmpty == true ? imageFileName : '<none>'}',
    );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== PROFILE UPDATE REQUEST END =====');

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
        id: (data['id'] ?? '').toString().isNotEmpty
            ? (data['id'] ?? '').toString()
            : userId,
        userId: userId,
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
        imageUrl: (data['image_url'] ?? '').toString(),
      );
    }

    throw AuthException(_extractMessage(body, response.statusCode));
  }

  User _parseMobileMemberProfileResponse(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      if (data.isEmpty) {
        throw const AuthException('Data profile member tidak ditemukan.');
      }

      final status = (data['status'] ?? '').toString();

      return User(
        id: (data['id'] ?? '').toString(),
        userId: (data['user_id'] ?? '').toString(),
        memberCode: ((data['member_code'] ?? '').toString()).isNotEmpty
            ? (data['member_code'] ?? '').toString()
            : (data['qr_code'] ?? '').toString(),
        name: (data['name'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        phone: (data['phone'] ?? '').toString(),
        provinceId: (data['province_id'] ?? '').toString(),
        cityId: (data['city_id'] ?? '').toString(),
        districtId: (data['district_id'] ?? '').toString(),
        subDistrictId:
            (data['sub_district_id'] ?? data['sub_district'] ?? '').toString(),
        postCode: (data['post_code'] ?? '').toString(),
        address: (data['address'] ?? '').toString(),
        createdAt: (data['created_at'] ?? '').toString(),
        status: status,
        isActive: status.toUpperCase() == 'ACTIVE',
        imageUrl: (data['image_url'] ?? '').toString(),
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

  static String get _mobileApiBase =>
      _mobileBaseUrl.endsWith('/') ? _mobileBaseUrl : '$_mobileBaseUrl/';
}
