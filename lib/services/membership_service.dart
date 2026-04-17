import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/member_membership.dart';
import 'api_config.dart';

class MembershipException implements Exception {
  final String message;

  const MembershipException(this.message);

  @override
  String toString() => message;
}

class MembershipService {
  const MembershipService();

  Future<List<MemberMembership>> fetchMemberships({
    required String userId,
    required String token,
    String tokenType = 'Bearer',
    String status = 'ACTIVE',
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.apiBase}members/$userId/memberships',
    ).replace(queryParameters: <String, String>{'status': status});

    final response = await http
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': '$tokenType $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    return _parseMembershipList(response);
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
