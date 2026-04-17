import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/camera_permission_service.dart';
import 'services/theme_mode_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const CameraPermissionService().ensureCameraPermission();
  await ThemeModeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeModeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'GYMMASTER',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeModeController.instance.mode,
          home: const AppLockGate(child: SplashScreen()),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
