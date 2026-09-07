import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/member_transaction.dart';
import 'auth_manager.dart';

class MemberTransactionException implements Exception {
  final String message;

  const MemberTransactionException(this.message);

  @override
  String toString() => message;
}

class MemberTransactionService {
  static const String _transactionsUrl =
      'https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/transactions';

  const MemberTransactionService();

  Future<List<MemberTransaction>> fetchTransactions({
    required String token,
    String tokenType = 'Bearer',
    int page = 1,
    int limit = 25,
    String? type,
    String? packageId,
    String? status,
    String? tanggal,
  }) async {
    final normalizedToken = token.trim();
    final normalizedTokenType = tokenType.trim().isEmpty
        ? 'Bearer'
        : tokenType.trim();
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (packageId != null && packageId.trim().isNotEmpty)
        'package': packageId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (tanggal != null && tanggal.trim().isNotEmpty)
        'tanggal': tanggal.trim(),
    };
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$normalizedTokenType $normalizedToken',
    };

    final uri = Uri.parse(
      _transactionsUrl,
    ).replace(queryParameters: queryParameters);

    debugPrint('===== TRANSACTION HISTORY REQUEST START =====');
    debugPrint('GET $uri');
    debugPrint('Request headers: $headers');

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers}');
    debugPrint('Response body: ${response.body}');
    debugPrint('===== TRANSACTION HISTORY REQUEST END =====');

    final body = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _parseTransactions(body);
    }

    throw MemberTransactionException(
      _extractMessage(body, response.statusCode),
    );
  }

  List<MemberTransaction> _parseTransactions(Map<String, dynamic> body) {
    final sources = <Object?>[
      body['data'],
      body['transactions'],
      body['items'],
      body['history'],
    ];

    for (final source in sources) {
      final items = _extractItemList(source);
      if (items.isNotEmpty) {
        return items
            .map((item) => MemberTransaction.fromJson(item))
            .toList(growable: false);
      }
    }

    return const <MemberTransaction>[];
  }

  List<Map<String, dynamic>> _extractItemList(Object? source) {
    if (source is List) {
      return source
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }

    if (source is Map) {
      final map = source.cast<String, dynamic>();
      final nestedSources = <Object?>[
        map['data'],
        map['items'],
        map['rows'],
        map['transactions'],
        map['history'],
      ];
      for (final nestedSource in nestedSources) {
        final nestedItems = _extractItemList(nestedSource);
        if (nestedItems.isNotEmpty) {
          return nestedItems;
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _decodeBody(String rawBody) {
    if (rawBody.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
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
