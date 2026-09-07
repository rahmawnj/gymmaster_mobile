import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../models/user.dart';
import '../services/app_tour_service.dart';
import '../services/screen_security_service.dart';
import '../widgets/app_tour_overlay.dart';
import '../widgets/top_notification.dart';
import 'member_packages_screen.dart';
import 'member_home_dashboard_screen.dart';
import 'profile_settings_screen.dart';
import 'scan_qr_hub_screen.dart';

class MainShellScreen extends StatefulWidget {
  final User currentUser;

  const MainShellScreen({super.key, required this.currentUser});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _qrTabIndex = 2;

  final _screenSecurityService = const ScreenSecurityService();
  final _screenBrightness = ScreenBrightness();
  final _appTourService = AppTourService.instance;
  final GlobalKey _homeOverviewTourKey = GlobalKey(
    debugLabel: 'home-overview-tour',
  );
  final GlobalKey _navHomeTourKey = GlobalKey(debugLabel: 'nav-home-tour');
  final GlobalKey _navPackagesTourKey = GlobalKey(
    debugLabel: 'nav-packages-tour',
  );
  final GlobalKey _navScanQrTourKey = GlobalKey(debugLabel: 'nav-scan-qr-tour');
  final GlobalKey _packagesOverviewTourKey = GlobalKey(
    debugLabel: 'packages-overview-tour',
  );
  final GlobalKey _qrOverviewTourKey = GlobalKey(
    debugLabel: 'qr-overview-tour',
  );

  late User _currentUser;
  late List<Widget> _pages;
  int _selectedIndex = 0;
  bool _isNavVisible = true;
  bool _isTourVisible = false;
  bool _isQrScreenProtected = false;
  bool _isQrBrightnessBoosted = false;
  double? _brightnessBeforeQr;
  bool? _hadApplicationBrightnessBeforeQr;
  int _brightnessRequestId = 0;
  DateTime? _lastNavToggleAt;
  DateTime? _lastBackPressedAt;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = widget.currentUser;
    _pageController = PageController(initialPage: _selectedIndex);
    _pages = _buildPages();
    unawaited(_scheduleHomeTour());
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.memberCode != widget.currentUser.memberCode ||
        oldWidget.currentUser.name != widget.currentUser.name ||
        oldWidget.currentUser.phone != widget.currentUser.phone ||
        oldWidget.currentUser.imageUrl != widget.currentUser.imageUrl) {
      _currentUser = widget.currentUser;
      _pages = _buildPages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setQrScreenProtection(false);
    _setQrBrightnessBoost(false);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lastBackPressedAt = null;
    }
  }

  void _setQrScreenProtection(bool enabled) {
    if (_isQrScreenProtected == enabled) {
      return;
    }

    _isQrScreenProtected = enabled;
    unawaited(_screenSecurityService.setScreenProtection(enabled));
  }

  void _syncScreenProtectionForTab(int index) {
    _setQrScreenProtection(index == _qrTabIndex);
    _setQrBrightnessBoost(index == _qrTabIndex);
  }

  void _setQrBrightnessBoost(bool enabled) {
    if (_isQrBrightnessBoosted == enabled) {
      return;
    }

    _isQrBrightnessBoosted = enabled;
    final requestId = ++_brightnessRequestId;
    unawaited(_applyQrBrightnessBoost(enabled, requestId));
  }

  Future<void> _applyQrBrightnessBoost(bool enabled, int requestId) async {
    try {
      if (enabled) {
        _brightnessBeforeQr ??= await _screenBrightness.application;
        _hadApplicationBrightnessBeforeQr ??=
            await _screenBrightness.hasApplicationScreenBrightnessChanged;
        if (requestId != _brightnessRequestId || !_isQrBrightnessBoosted) {
          return;
        }

        await _screenBrightness.setApplicationScreenBrightness(1.0);
        return;
      }

      final previousBrightness = _brightnessBeforeQr;
      final hadApplicationBrightness = _hadApplicationBrightnessBeforeQr;
      _brightnessBeforeQr = null;
      _hadApplicationBrightnessBeforeQr = null;
      if (requestId != _brightnessRequestId || _isQrBrightnessBoosted) {
        return;
      }

      if (hadApplicationBrightness == true && previousBrightness != null) {
        await _screenBrightness.setApplicationScreenBrightness(
          previousBrightness.clamp(0.0, 1.0).toDouble(),
        );
      } else {
        await _screenBrightness.resetApplicationScreenBrightness();
      }
    } catch (_) {
      // Brightness control can be unavailable on some platforms/devices.
    }
  }

  void _handleTabChange(int index) {
    if (_selectedIndex == index) {
      return;
    }

    _lastBackPressedAt = null;
    setState(() {
      _selectedIndex = index;
      _isNavVisible = true;
    });
    _syncScreenProtectionForTab(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleUserUpdated(User updatedUser) {
    setState(() {
      _currentUser = updatedUser;
      _pages = _buildPages();
    });
  }

  void _handleBackPressed() {
    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <
            const Duration(milliseconds: 1200);

    if (shouldExit) {
      _lastBackPressedAt = null;
      TopNotification.clear();
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    TopNotification.show(
      context,
      message: 'Tekan 2 kali untuk keluar.',
      type: TopNotificationType.info,
    );
  }

  List<Widget> _buildPages() {
    return <Widget>[
      MemberHomeDashboardScreen(
        user: _currentUser,
        onNavigate: _handleTabChange,
        tourHighlightKey: _homeOverviewTourKey,
      ),
      MemberPackagesScreen(
        currentUser: _currentUser,
        onBackRequested: () => _handleTabChange(0),
        membershipCardKey: _packagesOverviewTourKey,
      ),
      ScanQrHubScreen(
        currentUser: _currentUser,
        qrMatrixKey: _qrOverviewTourKey,
      ),
      ProfileSettingsScreen(
        initialUser: _currentUser,
        isActive: _selectedIndex == 3,
        popOnUpdate: false,
        onUserUpdated: _handleUserUpdated,
        onBackRequested: () => _handleTabChange(0),
      ),
    ];
  }

  List<AppTourStep> get _homeTourSteps => <AppTourStep>[
    AppTourStep(
      targetKey: _homeOverviewTourKey,
      title: 'Halaman Home',
      description:
          'Di area ini kamu bisa cek status member, ID member, dan ringkasan akun utama dengan cepat.',
      highlightPadding: const EdgeInsets.all(12),
      borderRadius: 26,
    ),
    AppTourStep(
      targetKey: _navHomeTourKey,
      title: 'Menu Beranda',
      description:
          'Tap menu ini kalau kamu ingin balik lagi ke halaman home kapan pun.',
      highlightPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 22,
    ),
    AppTourStep(
      targetKey: _navPackagesTourKey,
      title: 'Menu Paket',
      description:
          'Di sini user bisa lihat paket aktif, detail membership, atau lanjut beli paket baru.',
      highlightPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 22,
    ),
    AppTourStep(
      targetKey: _navScanQrTourKey,
      title: 'Scan QR',
      description:
          'Menu ini dipakai untuk membuka QR akses gym dan kebutuhan scan terkait kunjungan.',
      highlightPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 22,
    ),
    AppTourStep(
      targetKey: _packagesOverviewTourKey,
      title: 'Manajemen Paket',
      description:
          'Di sini kamu bisa memantau semua membership dan paket training yang aktif.',
      highlightPadding: const EdgeInsets.all(12),
      borderRadius: 20,
    ),
    AppTourStep(
      targetKey: _qrOverviewTourKey,
      title: 'Akses Scan QR',
      description:
          'Tunjukkan kode QR ini ke scanner di gate untuk masuk ke area gym.',
      highlightPadding: const EdgeInsets.all(12),
      borderRadius: 24,
    ),
  ];

  Future<void> _scheduleHomeTour() async {
    final isCompleted = await _appTourService.isMemberHomeTourCompleted();
    if (!mounted || isCompleted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        _showHomeTourWhenReady();
      });
    });
  }

  void _onTourStepChanged(int index) {
    if (index == 4) {
      _handleTabChange(1); // Switch to Packages
    } else if (index == 5) {
      _handleTabChange(2); // Switch to QR Hub
    }
  }

  void _showHomeTourWhenReady({int attempt = 0}) {
    if (!mounted) {
      return;
    }

    final hasTargets = <GlobalKey>[
      _homeOverviewTourKey,
      _navHomeTourKey,
      _navPackagesTourKey,
      _navScanQrTourKey,
    ].every(_hasRenderableTarget);

    if (hasTargets) {
      if (_selectedIndex != 0) {
        _pageController.jumpToPage(0);
      }
      setState(() {
        _selectedIndex = 0;
        _isNavVisible = true;
        _isTourVisible = true;
      });
      return;
    }

    if (attempt >= 12) {
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 180), () {
      _showHomeTourWhenReady(attempt: attempt + 1);
    });
  }

  bool _hasRenderableTarget(GlobalKey key) {
    final targetContext = key.currentContext;
    final renderObject = targetContext?.findRenderObject();
    return renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.attached;
  }

  Future<void> _completeHomeTour() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isTourVisible = false;
    });
    await _appTourService.markMemberHomeTourCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (_selectedIndex != 0 && _selectedIndex != 1) {
                  return false;
                }
                if (notification.metrics.axis != Axis.vertical) {
                  return false;
                }
                if (notification.metrics.pixels <=
                    notification.metrics.minScrollExtent + 2) {
                  if (!_isNavVisible) {
                    setState(() {
                      _isNavVisible = true;
                    });
                  }
                  return false;
                }
                if (notification is ScrollUpdateNotification) {
                  final delta = notification.scrollDelta ?? 0;
                  if (delta.abs() < 2) {
                    return false;
                  }
                  final now = DateTime.now();
                  if (_lastNavToggleAt != null &&
                      now.difference(_lastNavToggleAt!) <
                          const Duration(milliseconds: 160)) {
                    return false;
                  }
                  if (delta > 0 && _isNavVisible) {
                    setState(() {
                      _isNavVisible = false;
                      _lastNavToggleAt = now;
                    });
                  } else if (delta < 0 && !_isNavVisible) {
                    setState(() {
                      _isNavVisible = true;
                      _lastNavToggleAt = now;
                    });
                  }
                }
                return false;
              },
              child: PageView(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                allowImplicitScrolling: true,
                onPageChanged: (index) {
                  _lastBackPressedAt = null;
                  setState(() {
                    _selectedIndex = index;
                    _isNavVisible = true;
                  });
                  _syncScreenProtectionForTab(index);
                },
                children: _pages,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFloatingNavigationBar(theme),
            ),
            if (_isTourVisible)
              Positioned.fill(
                child: AppTourOverlay(
                  steps: _homeTourSteps,
                  onStepChanged: _onTourStepChanged,
                  onCompleted: _completeHomeTour,
                  onDismissed: _completeHomeTour,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavigationBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: _isNavVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_isNavVisible,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.7),
                          isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          key: _navHomeTourKey,
                          child: _NavItem(
                            icon: Icons.home_rounded,
                            isActive: _selectedIndex == 0,
                            activeColor: scheme.primary,
                            onTap: () => _handleTabChange(0),
                          ),
                        ),
                        SizedBox(
                          key: _navPackagesTourKey,
                          child: _NavItem(
                            icon: Icons.layers_rounded,
                            isActive: _selectedIndex == 1,
                            activeColor: scheme.primary,
                            onTap: () => _handleTabChange(1),
                          ),
                        ),
                        SizedBox(
                          key: _navScanQrTourKey,
                          child: _NavItem(
                            icon: Icons.qr_code_scanner_rounded,
                            isActive: _selectedIndex == 2,
                            activeColor: scheme.primary,
                            onTap: () => _handleTabChange(2),
                          ),
                        ),
                        _NavItem(
                          icon: Icons.person_rounded,
                          isActive: _selectedIndex == 3,
                          activeColor: scheme.primary,
                          onTap: () => _handleTabChange(3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() {
      _isHovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark
        ? const Color(0xFF7A828A)
        : const Color(0xFF8B95A5);
    final foregroundColor = widget.isActive ? Colors.white : inactiveColor;
    final backgroundColor = widget.isActive
        ? widget.activeColor
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isActive ? 20 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(widget.icon, color: foregroundColor, size: 26),
          ),
        ),
      ),
    );
  }
}
