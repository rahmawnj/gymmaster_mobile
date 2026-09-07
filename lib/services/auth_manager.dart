import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/auth_screen.dart';
import 'session_storage.dart';
import '../widgets/top_notification.dart';

class AuthManager {
  AuthManager._();

  static bool _isLoggingOut = false;

  /// Membersihkan session dan kembali ke layar login
  static Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // 1. Hapus data di storage
      const SessionStorage().clearSession();

      // 2. Redirect ke login (menghapus semua tumpukan halaman sebelumnya)
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
        (route) => false,
      );

      // 3. Tampilkan pesan (opsional)
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        TopNotification.show(
          context,
          message: 'Sesi telah berakhir. Silakan login kembali.',
          type: TopNotificationType.error,
        );
      }
    } finally {
      _isLoggingOut = false;
    }
  }
}
