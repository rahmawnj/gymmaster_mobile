import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../models/user.dart';
import '../services/screen_security_service.dart';
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
    with TickerProviderStateMixin {
  static const int _qrTabIndex = 2;

  final _screenSecurityService = const ScreenSecurityService();
  final _screenBrightness = ScreenBrightness();

  late User _currentUser;
  late List<Widget> _pages;
  int _selectedIndex = 0;
  bool _isNavVisible = true;
  bool _isQrScreenProtected = false;
  bool _isQrBrightnessBoosted = false;
  double? _brightnessBeforeQr;
  bool? _hadApplicationBrightnessBeforeQr;
  int _brightnessRequestId = 0;
  DateTime? _lastNavToggleAt;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _pageController = PageController(initialPage: _selectedIndex);
    _pages = _buildPages();
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
    _setQrScreenProtection(false);
    _setQrBrightnessBoost(false);
    _pageController.dispose();
    super.dispose();
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

  List<Widget> _buildPages() {
    return <Widget>[
      MemberHomeDashboardScreen(
        user: _currentUser,
        onNavigate: _handleTabChange,
      ),
      MemberPackagesScreen(
        currentUser: _currentUser,
        onBackRequested: () => _handleTabChange(0),
      ),
      ScanQrHubScreen(currentUser: _currentUser),
      ProfileSettingsScreen(
        initialUser: _currentUser,
        isActive: _selectedIndex == 3,
        popOnUpdate: false,
        onUserUpdated: _handleUserUpdated,
        onBackRequested: () => _handleTabChange(0),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
        ],
      ),
    );
  }

  Widget _buildFloatingNavigationBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final navColor = isDark ? const Color(0xCC0B0B0D) : const Color(0xBAFFFFFF);
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.20);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.35),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: _isNavVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_isNavVisible,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  if (isDark) ...[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 26,
                      spreadRadius: -4,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ] else
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      spreadRadius: -3,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: navColor,
                      border: Border.all(color: navBorderColor),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          navColor.withValues(alpha: isDark ? 0.9 : 0.72),
                          navColor.withValues(alpha: isDark ? 0.82 : 0.60),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.home_outlined,
                              label: 'Beranda',
                              isActive: _selectedIndex == 0,
                              activeColor: scheme.primary,
                              onTap: () => _handleTabChange(0),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.layers_outlined,
                              label: 'Paket',
                              isActive: _selectedIndex == 1,
                              activeColor: scheme.primary,
                              onTap: () => _handleTabChange(1),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Scan QR',
                              isActive: _selectedIndex == 2,
                              activeColor: scheme.primary,
                              onTap: () => _handleTabChange(2),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.person_outline_rounded,
                              label: 'Profil',
                              isActive: _selectedIndex == 3,
                              activeColor: scheme.primary,
                              onTap: () => _handleTabChange(3),
                            ),
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
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF7C8798);
    final activeBackground = activeColor.withValues(
      alpha: isDark ? 0.18 : 0.08,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: isActive ? Curves.easeOutCubic : Curves.easeInCubic,
                  opacity: isActive ? 1 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 280),
                    curve: isActive
                        ? Curves.easeOutBack
                        : Curves.easeInOutCubic,
                    scale: isActive ? 1 : 0.72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: activeBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isActive ? activeColor : inactiveColor,
                    size: 22,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? activeColor : inactiveColor,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
