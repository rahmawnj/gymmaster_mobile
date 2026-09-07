import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/member_visit_history.dart';
import 'auth_manager.dart';

class MemberVisitHistoryException implements Exception {
  final String message;

  const MemberVisitHistoryException(this.message);

  @override
  String toString() => message;
}

class MemberVisitHistoryService {
  static const String _visitHistoryUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/histories/visit';

  const MemberVisitHistoryService();

  Future<MemberVisitHistoryResult> fetchVisitHistory({
    required String token,
    String tokenType = 'Bearer',
    int page = 1,
    int limit = 25,
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final uri = Uri.parse(_visitHistoryUrl).replace(
      queryParameters: <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    debugPrint('===== VISIT HISTORY REQUEST START =====');
    debugPrint('GET $uri');
    debugPrint('Request headers: $headers');

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== VISIT HISTORY REQUEST END =====');

    return _parseVisitHistory(response);
  }

  MemberVisitHistoryResult _parseVisitHistory(http.Response response) {
    final body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      final meta = body['meta'];
      final visits = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => MemberVisitHistoryItem.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const <MemberVisitHistoryItem>[];

      return MemberVisitHistoryResult(
        visits: visits,
        meta: meta is Map
            ? MemberVisitHistoryMeta.fromJson(meta.cast<String, dynamic>())
            : const MemberVisitHistoryMeta(
                currentPage: 1,
                totalPages: 1,
                totalItems: 0,
                limit: 25,
              ),
      );
    }

    throw MemberVisitHistoryException(
      _extractMessage(body, response.statusCode),
    );
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
}
