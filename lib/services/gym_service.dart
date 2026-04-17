import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gym_access_history_item.dart';
import '../models/gym_access_request.dart';
import '../models/gym.dart';
import 'api_config.dart';
import 'auth_service.dart';

class JoinGymResult {
  final String message;
  final Gym gym;

  const JoinGymResult({required this.message, required this.gym});
}

class GymListsResult {
  final List<Gym> joinedGyms;
  final List<Gym> availableGyms;
  final List<Gym> allGyms;

  const GymListsResult({
    required this.joinedGyms,
    required this.availableGyms,
    required this.allGyms,
  });
}

class GymAccessHistoryResult {
  final List<GymAccessHistoryItem> history;
  final Gym? gym;

  const GymAccessHistoryResult({required this.history, this.gym});
}

class GymService {
  const GymService();

  Future<GymListsResult> fetchAllLists(String memberCode) async {
    final results = await Future.wait([
      _fetchGyms('joined', memberCode),
      _fetchGyms('not-joined', memberCode),
      _fetchGyms('all', memberCode),
    ]);

    return GymListsResult(
      joinedGyms: results[0],
      availableGyms: results[1],
      allGyms: results[2],
    );
  }

  Future<List<Gym>> fetchAllGyms(String memberCode) async {
    return _fetchGyms('all', memberCode);
  }

  Future<List<Gym>> _fetchGyms(String type, String memberCode) async {
    final uri = _buildGymListUri(type, memberCode);
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractMessage(body, response.statusCode));
    }

    final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final gyms = data['gyms'] as List<dynamic>? ?? const [];

    return gyms.whereType<Map<String, dynamic>>().map(Gym.fromApiJson).toList();
  }

  Future<Gym> fetchGymDetail({
    required String gymCode,
    Gym? fallbackGym,
  }) async {
    final candidates = <Uri>[
      Uri.parse('${ApiConfig.apiBase}gym/brand/detail/$gymCode'),
    ];

    for (final candidate in candidates) {
      final response = await http
          .get(candidate, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      final body = _decodeBody(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final detailGym = Gym.fromApiJson(_extractGymPayload(body));
        return _mergeGym(detailGym, fallbackGym);
      }

      if (response.statusCode == 404) {
        continue;
      }

      throw AuthException(_extractMessage(body, response.statusCode));
    }

    if (fallbackGym != null) {
      return fallbackGym;
    }

    throw const AuthException('Detail brand gym belum tersedia di server.');
  }

  Future<JoinGymResult> joinGym({
    required String memberCode,
    required String gymCode,
  }) async {
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.apiBase}gym/member/join/$memberCode/$gymCode',
          ),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractMessage(body, response.statusCode));
    }

    return JoinGymResult(
      message:
          body['message']?.toString() ?? 'Request join brand gym berhasil.',
      gym: Gym.fromApiJson(_extractGymPayload(body)),
    );
  }

  Future<GymAccessHistoryResult> fetchMemberAccessHistory({
    required String memberCode,
    required String gymCode,
    int limit = 20,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.apiBase}gym/member/history/$memberCode/$gymCode',
          ).replace(
            queryParameters: <String, String>{'limit': limit.toString()},
          ),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractMessage(body, response.statusCode));
    }

    final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final history = data['history'] as List<dynamic>? ?? const [];
    final gymPayload = _extractGymPayload(body);

    return GymAccessHistoryResult(
      history: history
          .whereType<Map<String, dynamic>>()
          .map(GymAccessHistoryItem.fromJson)
          .toList(),
      gym: gymPayload.isEmpty ? null : Gym.fromApiJson(gymPayload),
    );
  }

  Future<GymAccessRequest> requestGymAccess({
    required String memberCode,
    required String gymCode,
  }) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.apiBase}gym/member/access/$memberCode/$gymCode'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractMessage(body, response.statusCode));
    }

    final data = body['data'] as Map<String, dynamic>?;
    final requestPayload = data?['access_request'] as Map<String, dynamic>?;
    if (requestPayload == null) {
      throw const AuthException('Response request access tidak memiliki payload access_request.');
    }

    return GymAccessRequest.fromApiJson(requestPayload);
  }

  Future<GymAccessRequest> fetchGymAccessStatus({
    required String requestToken,
  }) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.apiBase}gym/member/access/status/$requestToken'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractMessage(body, response.statusCode));
    }

    final data = body['data'] as Map<String, dynamic>?;
    final requestPayload = data?['access_request'] as Map<String, dynamic>?;
    if (requestPayload == null) {
      throw const AuthException('Response status access tidak memiliki payload access_request.');
    }

    return GymAccessRequest.fromApiJson(requestPayload);
  }

  Uri buildMemberAccessUri({
    required String memberCode,
    required String gymCode,
  }) {
    return Uri.parse(
      '${ApiConfig.apiBase}gym/member/access/$memberCode/$gymCode',
    );
  }

  Uri _buildGymListUri(String type, String memberCode) {
    if (type == 'all') {
      return Uri.parse('${ApiConfig.apiBase}gym/member/list/all').replace(
        queryParameters: memberCode.isEmpty
            ? null
            : <String, String>{'member_code': memberCode},
      );
    }

    return Uri.parse('${ApiConfig.apiBase}gym/member/list/$type/$memberCode');
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
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'Request gagal dengan status $statusCode.';
  }

  Map<String, dynamic> _extractGymPayload(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final gym = data['gym'];
      if (gym is Map<String, dynamic>) {
        return gym;
      }

      final brand = data['brand'];
      if (brand is Map<String, dynamic>) {
        return brand;
      }

      if (data.containsKey('gym_code') || data.containsKey('name')) {
        return data;
      }
    }

    return <String, dynamic>{};
  }

  Gym _mergeGym(Gym detailGym, Gym? fallbackGym) {
    if (fallbackGym == null) {
      return detailGym;
    }

    return fallbackGym.copyWith(
      id: detailGym.id.isNotEmpty ? detailGym.id : fallbackGym.id,
      gymCode: detailGym.gymCode.isNotEmpty
          ? detailGym.gymCode
          : fallbackGym.gymCode,
      name: detailGym.name.isNotEmpty ? detailGym.name : fallbackGym.name,
      city: detailGym.city.isNotEmpty ? detailGym.city : fallbackGym.city,
      address: detailGym.address.isNotEmpty
          ? detailGym.address
          : fallbackGym.address,
      description: detailGym.description.isNotEmpty
          ? detailGym.description
          : fallbackGym.description,
      isJoined: detailGym.isJoined || fallbackGym.isJoined,
      canRequestJoin: detailGym.canRequestJoin || fallbackGym.canRequestJoin,
      status: detailGym.status.isNotEmpty ? detailGym.status : fallbackGym.status,
      requestedAt: detailGym.requestedAt ?? fallbackGym.requestedAt,
      approvedAt: detailGym.approvedAt ?? fallbackGym.approvedAt,
      joinedAt: detailGym.joinedAt ?? fallbackGym.joinedAt,
    );
  }
}
