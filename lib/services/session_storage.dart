import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/user.dart';

class SessionStorage {
  static const String _sessionKey = 'auth_session';

  const SessionStorage();

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toStorageJson()));
  }

  Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(_sessionKey);

    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }

      final session = AuthSession.fromStorage(decoded);
      if (session.token.isEmpty || session.user.id.isEmpty) {
        await clearSession();
        return null;
      }

      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> updateStoredUser(User user) async {
    final session = await loadSession();
    if (session == null) {
      return;
    }

    await saveSession(
      AuthSession(
        status: session.status,
        message: session.message,
        token: session.token,
        tokenType: session.tokenType,
        user: user,
      ),
    );
  }
}
