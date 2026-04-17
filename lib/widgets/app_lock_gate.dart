import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/app_lock_screen.dart';
import '../services/app_lock_service.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _isReady = false;
  bool _isEnabled = false;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
      _isReady = true;
    });
  }

  void _handleUnlocked() {
    setState(() {
      _isUnlocked = true;
    });
  }

  Future<void> _handleUnavailable() async {
    if (!mounted) return;
    setState(() {
      _isUnlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.child;
    }
    if (!_isReady) {
      return const SizedBox.shrink();
    }
    if (_isEnabled && !_isUnlocked) {
      return AppLockScreen(
        onUnlocked: _handleUnlocked,
        onUnavailable: _handleUnavailable,
      );
    }
    return widget.child;
  }
}
