import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
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
  late User _currentUser;
  late List<Widget> _pages;
  int _selectedIndex = 0;
  bool _isNavVisible = true;
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
        oldWidget.currentUser.phone != widget.currentUser.phone) {
      _currentUser = widget.currentUser;
      _pages = _buildPages();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
      _isNavVisible = true;
    });
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
    final navColor = isDark ? const Color(0xFF181818) : const Color(0xFFFBFBFC);

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
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      spreadRadius: -3,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  decoration: BoxDecoration(
                    color: navColor,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF7C8798);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
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
    );
  }
}
