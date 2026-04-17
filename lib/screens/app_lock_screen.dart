import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../theme/app_theme.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback? onUnavailable;

  const AppLockScreen({
    super.key,
    required this.onUnlocked,
    this.onUnavailable,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _didAttemptAuth = false;
  bool _canUseDeviceAuth = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceAuthSupport();
  }

  Future<void> _loadDeviceAuthSupport() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _error = 'Kunci aplikasi bawaan perangkat tidak tersedia di web.';
      });
      return;
    }
    try {
      final supported = await _auth.isDeviceSupported();
      if (!mounted) return;
      setState(() {
        _canUseDeviceAuth = supported;
      });
      if (supported) {
        _tryDeviceAuthentication();
      } else {
        widget.onUnavailable?.call();
        setState(() {
          _error =
              'Perangkat ini belum mendukung autentikasi sistem untuk buka aplikasi.';
        });
      }
    } catch (_) {
      widget.onUnavailable?.call();
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memeriksa keamanan perangkat.';
      });
    }
  }

  Future<void> _tryDeviceAuthentication() async {
    if (_isAuthenticating || !_canUseDeviceAuth) return;
    setState(() {
      _isAuthenticating = true;
      _didAttemptAuth = true;
      _error = null;
    });
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Gunakan keamanan HP untuk membuka aplikasi.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() {
          _error = 'Autentikasi dibatalkan atau gagal. Coba lagi.';
        });
      }
    } catch (_) {
      widget.onUnavailable?.call();
      if (!mounted) return;
      setState(() {
        _error = 'Autentikasi sistem tidak tersedia di perangkat ini.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 54,
                  color: scheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Kunci aplikasi aktif',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buka dengan keamanan bawaan HP seperti sidik jari, wajah, atau sandi layar.',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: onSurfaceVariant.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isAuthenticating
                              ? 'Membuka dialog keamanan sistem...'
                              : 'Autentikasi akan memakai tampilan bawaan perangkat.',
                          style: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAuthenticating ? null : _tryDeviceAuthentication,
                    child: Text(
                      _didAttemptAuth
                          ? 'Coba lagi dengan keamanan HP'
                          : 'Buka dengan keamanan HP',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
