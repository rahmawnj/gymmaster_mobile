import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/app_lock_service.dart';
import '../services/session_storage.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'main_shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});


  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _heroBackgroundImage = 'assets/images/auth-gym-bg.jpg';
  late final AnimationController _introController;
  final _sessionStorage = const SessionStorage();
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoLift;
  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _bootstrap();
    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.12, 0.70, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );
    _logoLift = Tween<double>(
      begin: 20,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait<Object?>([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      _sessionStorage.loadSession(),
      AppLockService.instance.isEnabled(),
    ]);

    if (!mounted) return;

    final session = results[1] as AuthSession?;
    final isAppLockEnabled = results[2] as bool? ?? false;
    final nextPage = session == null
        ? const AuthScreen(isLogin: true)
        : MainShellScreen(currentUser: session.user);
    final nextRoot = isAppLockEnabled
        ? AppLockGate(isEnabled: true, child: nextPage)
        : nextPage;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => nextRoot,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _introController,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _heroBackgroundImage,
                fit: BoxFit.cover,
                alignment: const Alignment(0.24, 0),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      const Color(0xB8140B0C),
                      const Color(0xF2090909),
                    ],
                    stops: const [0, 0.46, 1],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.06, -0.2),
                    radius: 0.88,
                    colors: [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Transform.translate(
                      offset: Offset(0, _logoLift.value),
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: const AppLogo(
                            size: 130,
                            variant: AppLogoVariant.iconOnly,
                            tone: AppLogoTone.light,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
