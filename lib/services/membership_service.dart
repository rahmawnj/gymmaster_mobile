import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/member_branch.dart';
import '../models/member_membership.dart';
import '../models/member_membership_option.dart';
import '../models/member_schedule.dart';
import '../models/member_training_package.dart';
import '../models/member_trainer_package_option.dart';
import 'auth_manager.dart';

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
  static const String _activeTrainingPackagesUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/packages/active';
  static const String _branchesUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/branches';
  static const String _membershipOptionsUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/memberships';
  static const String _trainerPackageOptionsUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/packages';
  static const String _purchaseMembershipUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/purchase/membership';
  static const String _schedulesUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/schedules';

  const MembershipService();

  // Lightweight request/response logger. In debug builds it prints a small
  // breadcrumb (method + url) for every call. Response bodies are only
  // logged when something is off (non-2xx or thrown), so we do not flood
  // the iOS console (and stall the platform channel) on the happy path.
  void _logRequestStart(String tag, String method, Uri uri) {
    if (!kDebugMode) return;
    debugPrint('[$tag] $method $uri');
  }

  void _logRequestBody(String tag, Object body) {
    if (!kDebugMode) return;
    debugPrint('[$tag] body=$body');
  }

  void _logResponseOk(String tag, int statusCode) {
    if (!kDebugMode) return;
    debugPrint('[$tag] <- $statusCode');
  }

  void _logResponseError(String tag, int statusCode, String body) {
    if (!kDebugMode) return;
    final preview = body.length > 600 ? '${body.substring(0, 600)}…' : body;
    debugPrint('[$tag] <- $statusCode body=$preview');
  }

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

    _logRequestStart('membership', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('membership', response.statusCode);

    return _parseMembershipList(response);
  }

  Future<List<MemberTrainingPackage>> fetchActiveTrainingPackages({
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_activeTrainingPackagesUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    _logRequestStart('training-pkg', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('training-pkg', response.statusCode);

    return _parseActiveTrainingPackageList(response);
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

    _logRequestStart('branches', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('branches', response.statusCode);

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
    final uri = Uri.parse(
      _membershipOptionsUrl,
    ).replace(queryParameters: <String, String>{'branch_id': branchId});
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    _logRequestStart('membership-option', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('membership-option', response.statusCode);

    return _parseMembershipOptionList(response);
  }

  Future<List<MemberTrainerPackageOption>> fetchTrainerPackageOptions({
    required String branchId,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(
      _trainerPackageOptionsUrl,
    ).replace(queryParameters: <String, String>{'branch_id': branchId});
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    _logRequestStart('trainer-option', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('trainer-option', response.statusCode);

    return _parseTrainerPackageOptionList(response);
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

    _logRequestStart('membership-detail', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('membership-detail', response.statusCode);

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

    _logRequestStart('membership-purchase', 'POST', uri);
    _logRequestBody('membership-purchase', jsonEncode(payload));

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    _logResponseOk('membership-purchase', response.statusCode);

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

    _logResponseError('membership-purchase', effectiveStatus, response.body);
    throw MembershipException(_extractMessage(body, effectiveStatus));
  }

  Future<List<MemberSchedule>> fetchSchedules({
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_schedulesUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    _logRequestStart('schedules', 'GET', uri);

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _logResponseOk('schedules', response.statusCode);

    return _parseScheduleList(response);
  }

  Future<void> createSchedule({
    required int memberId,
    required String historyPackageId,
    required String sessionDate,
    required String startTime,
    required String endTime,
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_schedulesUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };
    final payload = <String, dynamic>{
      'member_id': memberId,
      'history_package_id': _toInt(historyPackageId),
      'session_date': sessionDate,
      'start_time': startTime,
      'end_time': endTime,
    };

    _logRequestStart('schedule-create', 'POST', uri);
    _logRequestBody('schedule-create', jsonEncode(payload));

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    _logResponseOk('schedule-create', response.statusCode);

    final body = _decodeBody(response.body);
    final apiStatus = _toInt(body['status']);
    final effectiveStatus = apiStatus == 0 ? response.statusCode : apiStatus;

    if (effectiveStatus >= 200 && effectiveStatus < 300) {
      return;
    }

    _logResponseError('schedule-create', effectiveStatus, response.body);
    throw MembershipException(_extractMessage(body, effectiveStatus));
  }

  List<MemberMembership> _parseMembershipList(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) => MemberMembership.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
      return const [];
    }

    _logResponseError('membership', response.statusCode, response.body);
    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  List<MemberTrainingPackage> _parseActiveTrainingPackageList(
    http.Response response,
  ) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) =>
                  MemberTrainingPackage.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
      return const [];
    }

    _logResponseError('training-pkg', response.statusCode, response.body);
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

    _logResponseError('branches', response.statusCode, response.body);
    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  List<MemberMembershipOption> _parseMembershipOptionList(
    http.Response response,
  ) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) =>
                  MemberMembershipOption.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
      return const [];
    }

    _logResponseError('membership-option', response.statusCode, response.body);
    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  List<MemberTrainerPackageOption> _parseTrainerPackageOptionList(
    http.Response response,
  ) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) => MemberTrainerPackageOption.fromJson(
                item.cast<String, dynamic>(),
              ),
            )
            .toList();
      }
      return const [];
    }

    _logResponseError('trainer-option', response.statusCode, response.body);
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

    _logResponseError('membership-detail', response.statusCode, response.body);
    throw MembershipException(_extractMessage(body, response.statusCode));
  }

  List<MemberSchedule> _parseScheduleList(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => MemberSchedule.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    _logResponseError('schedules', response.statusCode, response.body);
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
    if (statusCode == 401) {
      AuthManager.logout();
    }
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



