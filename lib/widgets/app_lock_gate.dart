import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/app_lock_screen.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;
  final bool isEnabled;

  const AppLockGate({
    super.key,
    required this.child,
    required this.isEnabled,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _isUnlocked = false;

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
    if (widget.isEnabled && !_isUnlocked) {
      return AppLockScreen(
        onUnlocked: _handleUnlocked,
        onUnavailable: _handleUnavailable,
      );
    }
    return widget.child;
  }
}
