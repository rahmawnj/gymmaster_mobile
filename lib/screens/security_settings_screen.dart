import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/app_lock_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _lockEnabled = false;
  bool _isCheckingAvailability = true;
  bool _isDeviceSecuritySupported = false;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadLock();
  }

  Future<void> _loadLock() async {
    final enabled = await AppLockService.instance.isEnabled();
    bool supported = false;
    try {
      supported = await _localAuth.isDeviceSupported();
    } catch (_) {
      supported = false;
    }
    if (!mounted) return;
    setState(() {
      _lockEnabled = enabled;
      _isDeviceSecuritySupported = supported;
      _isCheckingAvailability = false;
    });
  }

  Future<void> _toggleLock(bool value) async {
    if (!_isDeviceSecuritySupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keamanan perangkat belum aktif. Atur sandi, PIN, pola, atau biometrik di HP dulu.',
          ),
        ),
      );
      return;
    }

    if (!value) {
      await AppLockService.instance.setEnabled(false);
      if (!mounted) return;
      setState(() {
        _lockEnabled = false;
      });
      return;
    }

    await AppLockService.instance.clearLegacyPin();
    await AppLockService.instance.setEnabled(true);
    if (!mounted) return;
    setState(() {
      _lockEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final dividerColor = onSurfaceVariant.withValues(alpha: 0.18);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Text(
          'Keamanan',
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Keamanan',
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (_isCheckingAvailability)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else
            _InfoRowTile(
              title: 'Metode buka aplikasi',
              subtitle: _isDeviceSecuritySupported
                  ? 'Mengikuti keamanan bawaan HP seperti sidik jari, wajah, PIN, pola, atau sandi layar.'
                  : 'Belum ada keamanan perangkat yang bisa dipakai. Aktifkan dulu di pengaturan HP.',
            ),
          Divider(color: dividerColor),
          _SwitchRowTile(
            title: 'Kunci aplikasi',
            subtitle:
                'Saat aktif, aplikasi akan minta autentikasi dengan tampilan keamanan sistem HP.',
            value: _isDeviceSecuritySupported && _lockEnabled,
            onChanged: _isCheckingAvailability ? null : (value) => _toggleLock(value),
          ),
        ],
      ),
    );
  }
}

class _SwitchRowTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRowTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: scheme.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoRowTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InfoRowTile({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: onSurfaceVariant,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
