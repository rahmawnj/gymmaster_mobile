import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/member_branch.dart';
import '../models/member_membership.dart';
import '../models/member_membership_option.dart';

class MembershipException implements Exception {
  final String message;

  const MembershipException(this.message);

  @override
  String toString() => message;
}

class MembershipPurchaseResult {
  final int transactionId;
  final String message;
  final String transactionCode;
  final String status;
  final int totalPrice;

  const MembershipPurchaseResult({
    required this.transactionId,
    required this.message,
    required this.transactionCode,
    required this.status,
    required this.totalPrice,
  });
}

class MembershipService {
  static const String _activeMembershipsUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/memberships/active';
  static const String _branchesUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/branches';
  static const String _membershipOptionsUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/memberships';
  static const String _purchaseMembershipUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/purchase/membership';

  const MembershipService();

  Future<List<MemberMembership>> fetchMemberships({
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_activeMembershipsUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    debugPrint('===== MEMBERSHIP REQUEST START =====');
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
    debugPrint('===== MEMBERSHIP REQUEST END =====');

    return _parseMembershipList(response);
  }

  Future<List<MemberBranch>> fetchBranches({
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_branchesUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    debugPrint('===== BRANCH REQUEST START =====');
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
    debugPrint('===== BRANCH REQUEST END =====');

    return _parseBranchList(response);
  }

  Future<List<MemberMembershipOption>> fetchMembershipOptions({
    required String branchId,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_membershipOptionsUrl).replace(
      queryParameters: <String, String>{'branch_id': branchId},
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    debugPrint('===== MEMBERSHIP OPTION REQUEST START =====');
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
    debugPrint('===== MEMBERSHIP OPTION REQUEST END =====');

    return _parseMembershipOptionList(response);
  }

  Future<MemberMembershipOption> fetchMembershipOptionDetail({
    required String membershipId,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse('$_membershipOptionsUrl/$membershipId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    debugPrint('===== MEMBERSHIP DETAIL REQUEST START =====');
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
    debugPrint('===== MEMBERSHIP DETAIL REQUEST END =====');

    return _parseMembershipOptionDetail(response);
  }

  Future<MembershipPurchaseResult> purchaseMembership({
    required int memberId,
    required int membershipId,
    required String startDate,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_purchaseMembershipUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };
    final payload = <String, dynamic>{
      'member_id': memberId,
      'membership_id': membershipId,
      'start_date': startDate,
    };

    debugPrint('===== MEMBERSHIP PURCHASE REQUEST START =====');
    debugPrint('POST $uri');
    debugPrint('Request headers: $headers');
    debugPrint('Request body: ${jsonEncode(payload)}');

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== MEMBERSHIP PURCHASE REQUEST END =====');

    final body = _decodeBody(response.body);
    final apiStatus = _toInt(body['status']);
    final effectiveStatus = apiStatus == 0 ? response.statusCode : apiStatus;
    if (effectiveStatus >= 200 && effectiveStatus < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final message = body['message']?.toString().trim().isNotEmpty == true
          ? body['message'].toString()
          : 'Pembelian membership sedang menunggu konfirmasi.';
      return MembershipPurchaseResult(
        transactionId: _toInt(data['id']),
        message: message,
        transactionCode: (data['transaction_code'] ?? '').toString(),
        status: (data['status'] ?? '').toString(),
        totalPrice: _toInt(data['total_price']),
      );
    }

    throw MembershipException(_extractMessage(body, effectiveStatus));
  }

  List<MemberMembership> _parseMembershipList(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => MemberMembership.fromJson(
                item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  List<MemberBranch> _parseBranchList(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => MemberBranch.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  List<MemberMembershipOption> _parseMembershipOptionList(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) => MemberMembershipOption.fromJson(
                item.cast<String, dynamic>(),
              ),
            )
            .toList();
      }
      return const [];
    }

    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  MemberMembershipOption _parseMembershipOptionDetail(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      if (data.isEmpty) {
        throw const MembershipException('Detail membership tidak ditemukan.');
      }
      return MemberMembershipOption.fromJson(data);
    }

    throw MembershipException(_extractMessage(body, response.statusCode));
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

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
