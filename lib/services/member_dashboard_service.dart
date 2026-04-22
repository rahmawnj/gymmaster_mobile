import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/member_dashboard.dart';

class MemberDashboardException implements Exception {
  final String message;

  const MemberDashboardException(this.message);

  @override
  String toString() => message;
}

class MemberDashboardService {
  static const String _dashboardUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/dashboard';
  static MemberDashboard? _cachedDashboard;

  const MemberDashboardService();

  MemberDashboard? get cachedDashboard => _cachedDashboard;

  static void clearCachedDashboard() {
    _cachedDashboard = null;
  }

  Future<MemberDashboard> fetchDashboard({
    required String token,
    String tokenType = 'Bearer',
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    debugPrint('===== DASHBOARD REQUEST START =====');
    debugPrint('GET ${_dashboardUri()}');
    debugPrint('Request headers: $headers');

    final response = await http.get(
      _dashboardUri(),
      headers: headers,
    ).timeout(const Duration(seconds: 20));

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== DASHBOARD REQUEST END =====');

    final body = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      if (data.isEmpty) {
        throw const MemberDashboardException(
          'Data dashboard member tidak ditemukan.',
        );
      }
      final dashboard = MemberDashboard.fromJson(data);
      _cachedDashboard = dashboard;
      return dashboard;
    }

    throw MemberDashboardException(_extractMessage(body, response.statusCode));
  }
  Uri _dashboardUri() {
    return Uri.parse(_dashboardUrl);
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
