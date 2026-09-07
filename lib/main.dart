import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/main_shell_screen.dart';
import 'services/app_lock_service.dart';
import 'services/session_storage.dart';
import 'services/theme_mode_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load theme and session in parallel
  final results = await Future.wait([
    ThemeModeController.instance.load(),
    const SessionStorage().loadSession(),
    AppLockService.instance.isEnabled(),
  ]);

  final session = results[1] as dynamic; // AuthSession?
  final isAppLockEnabled = results[2] as bool? ?? false;

  runApp(MyApp(
    initialSession: session,
    isAppLockEnabled: isAppLockEnabled,
  ));
}

class MyApp extends StatelessWidget {
  final dynamic initialSession;
  final bool isAppLockEnabled;

  const MyApp({
    super.key,
    this.initialSession,
    this.isAppLockEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final nextPage = initialSession == null
        ? const AuthScreen(isLogin: true)
        : MainShellScreen(currentUser: initialSession.user);

    final home = isAppLockEnabled
        ? AppLockGate(isEnabled: true, child: nextPage)
        : nextPage;

    return AnimatedBuilder(
      animation: ThemeModeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'GYMMASTER',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeModeController.instance.mode,
          home: home,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
