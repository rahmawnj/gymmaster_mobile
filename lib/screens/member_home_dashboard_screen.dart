import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/member_dashboard.dart';
import '../models/user.dart';
import '../services/member_dashboard_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'visit_history_screen.dart';

class MemberHomeDashboardScreen extends StatefulWidget {
  final User user;
  final ValueChanged<int> onNavigate;

  const MemberHomeDashboardScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  @override
  State<MemberHomeDashboardScreen> createState() =>
      _MemberHomeDashboardScreenState();
}

class _MemberHomeDashboardScreenState extends State<MemberHomeDashboardScreen>
    with TickerProviderStateMixin {
  final _dashboardService = const MemberDashboardService();
  final _sessionStorage = const SessionStorage();

  late final AnimationController _entranceController;
  late String _profileImageRevision;

  MemberDashboard? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _profileImageRevision = _nextProfileImageRevision();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
    _loadDashboard();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MemberHomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user ||
        oldWidget.user.imageUrl != widget.user.imageUrl) {
      _profileImageRevision = _nextProfileImageRevision();
    }
    if (oldWidget.user.memberCode != widget.user.memberCode ||
        oldWidget.user.name != widget.user.name ||
        oldWidget.user.status != widget.user.status) {
      _loadDashboard();
    }
  }

  String get _displayName {
    final fromDashboard = _dashboard?.name.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard;
    }

    final fromUser = widget.user.name.trim();
    return fromUser.isEmpty ? 'Member Gymmaster' : fromUser;
  }

  String get _memberCode {
    final fromDashboard = _dashboard?.memberCode.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard.toUpperCase();
    }

    final fromUser = widget.user.memberCode.trim();
    return fromUser.isEmpty ? '-' : fromUser.toUpperCase();
  }

  String get _status {
    final fromDashboard = _dashboard?.status.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard;
    }

    return widget.user.status.trim();
  }

  String get _registeredAt {
    final fromDashboard = _dashboard?.registeredAt.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard;
    }

    return widget.user.createdAt.trim();
  }

  String get _registeredPhone {
    return widget.user.phone.trim();
  }

  String get _profileImageUrl {
    return widget.user.imageUrl.trim();
  }

  String get _profileImageRequestUrl {
    final rawUrl = _profileImageUrl;
    if (rawUrl.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl;
    }

    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['v'] = _profileImageRevision;
    return uri.replace(queryParameters: queryParameters).toString();
  }

  String get _initials {
    final parts = _displayName
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'GM';
    }
    if (parts.length == 1) {
      final value = parts.first;
      final end = value.length >= 2 ? 2 : 1;
      return value.substring(0, end).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _nextProfileImageRevision() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _loadDashboard({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MemberDashboardException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final dashboard = await _dashboardService.fetchDashboard(
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
        _errorMessage = null;
      });
    } on MemberDashboardException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengambil dashboard member. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboard(showLoader: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: ColoredBox(color: theme.scaffoldBackgroundColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      children: [
                        _buildEntranceItem(
                          order: 0,
                          child: _buildTopBar(context),
                        ),
                        const SizedBox(height: 10),
                        _buildEntranceItem(
                          order: 1,
                          child: _buildGreetingCard(context),
                        ),
                        const SizedBox(height: 20),
                        _buildEntranceItem(
                          order: 2,
                          child: _buildMembershipCard(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  children: [
                    if (_isLoading) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ] else if (_errorMessage != null) ...[
                      _buildEntranceItem(
                        order: 3,
                        child: _buildErrorCard(context),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildEntranceItem(
                      order: 3,
                      child: _buildQuickActions(context),
                    ),
                    const SizedBox(height: 24),
                    _buildEntranceItem(
                      order: 4,
                      child: _buildPromoCard(context),
                    ),
                    const SizedBox(height: 14),
                    _buildEntranceItem(
                      order: 5,
                      child: _buildRecentVisitCard(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntranceItem({required int order, required Widget child}) {
    final start = (order * 0.08).clamp(0.0, 0.58).toDouble();
    final end = (start + 0.48).clamp(0.0, 1.0).toDouble();

    return AnimatedBuilder(
      animation: _entranceController,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          Interval(start, end).transform(_entranceController.value),
        );

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final iconColor = isDark ? Colors.white : AppTheme.ink;
    return Row(
      children: [
        Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const AppLogo(
            size: 80,
            variant: AppLogoVariant.lockupHorizontal,
            iconSize: 42,
            textSize: 54,
            spacing: 10,
          ),
        ),
        const Spacer(),
        _TopBarIconButton(
          icon: Icons.notifications_none_rounded,
          backgroundColor: iconBg,
          iconColor: iconColor,
          onTap: () => _showComingSoon(context, 'Notifikasi'),
          showDot: true,
        ),
        const SizedBox(width: 6),
        _TopBarIconButton(
          icon: Icons.logout_rounded,
          backgroundColor: iconBg,
          iconColor: iconColor,
          onTap: () => _handleLogout(context),
        ),
      ],
    );
  }

  Widget _buildGreetingCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final accentBackground = isDark
        ? scheme.primary.withValues(alpha: 0.14)
        : const Color(0xFFFFE8EE);
    final accentBorder = isDark
        ? scheme.primary.withValues(alpha: 0.32)
        : const Color(0xFFF7C4D0);

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentBackground,
            border: Border.all(color: accentBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: ClipOval(
              child: _profileImageUrl.isNotEmpty
                  ? Image.network(
                      _profileImageRequestUrl,
                      key: ValueKey(
                        'dashboard-avatar-$_profileImageUrl|$_profileImageRevision',
                      ),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      webHtmlElementStrategy: kIsWeb
                          ? WebHtmlElementStrategy.prefer
                          : WebHtmlElementStrategy.never,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildGreetingAvatarFallback(),
                    )
                  : _buildGreetingAvatarFallback(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang kembali,',
                style: TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _displayName,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingAvatarFallback() {
    return ColoredBox(
      color: Colors.transparent,
      child: Center(
        child: Text(
          _initials,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _status;
    final isActive = status.toUpperCase() == 'ACTIVE';
    final statusLabel = status.isEmpty ? 'NONAKTIF' : status.toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1B1B1F), Color(0xFF241118), Color(0xFF121214)]
              : const [Color(0xFF1A1A1D), Color(0xFF27131A), Color(0xFF16161A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.16),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 22,
            child: Icon(
              Icons.fitness_center_rounded,
              size: 68,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _MembershipLabel(
                      title: 'STATUS ANGGOTA',
                      value: statusLabel,
                      isActive: isActive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _MembershipLabel(
                      title: 'ID MEMBER',
                      value: _memberCode,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _registeredPhone.isNotEmpty
                          ? 'Nomor terdaftar $_registeredPhone'
                          : 'Terdaftar sejak ${_formatDateLabel(_registeredAt)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFFFEEF2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFB8C7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard belum bisa dimuat',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Terjadi kendala saat mengambil data dashboard.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => _loadDashboard(),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final darkTile = const Color(0xFF1E1E1E);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _HomeActionTile(
            icon: Icons.calendar_month_outlined,
            iconColor: const Color(0xFF2962FF),
            backgroundColor: isDark ? darkTile : const Color(0xFFEAF1FF),
            label: 'Jadwal',
            onTap: () => _showComingSoon(context, 'Jadwal'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HomeActionTile(
            icon: Icons.badge_outlined,
            iconColor: const Color(0xFFFF6D00),
            backgroundColor: isDark ? darkTile : const Color(0xFFFFF2E8),
            label: 'Trainer',
            onTap: () => _showComingSoon(context, 'Trainer'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HomeActionTile(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFF7B1FFF),
            backgroundColor: isDark ? darkTile : const Color(0xFFF3EAFF),
            label: 'Riwayat',
            onTap: () => widget.onNavigate(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HomeActionTile(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFF009966),
            backgroundColor: isDark ? darkTile : const Color(0xFFE6FAF1),
            label: 'Tagihan',
            onTap: () => _showComingSoon(context, 'Tagihan'),
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF17242B)
        : const Color(0xFFEAF4FF);
    final borderColor = isDark
        ? const Color(0xFF27424E)
        : const Color(0xFFC8DCF7);
    final accentColor = isDark
        ? const Color(0xFF7CC7FF)
        : const Color(0xFF2563EB);
    final bodyColor = isDark
        ? const Color(0xFFB6C4CD)
        : const Color(0xFF4B647C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onNavigate(1),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 122),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajak Teman, Dapat Diskon!',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dapatkan potongan 20% untuk bulan depan.',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: accentColor.withValues(alpha: 0.92),
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentVisitCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final visits =
        (_dashboard?.lastCheckins ?? const <MemberDashboardCheckin>[])
            .take(5)
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Kunjungan Terakhir',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return AppTheme.primary.withValues(alpha: 0.72);
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return AppTheme.primary.withValues(alpha: 0.82);
                  }
                  return AppTheme.primary;
                }),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VisitHistoryScreen()),
                );
              },
              child: const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading && visits.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_off_outlined,
                      color: onSurfaceVariant,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Belum ada kunjungan. Mulai check-in untuk melihat riwayat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: onSurfaceVariant.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...visits.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == visits.length - 1 ? 0 : 14,
              ),
              child: _buildVisitTimelineItem(
                context,
                visit: entry.value,
                index: entry.key,
                isFirst: entry.key == 0,
                isLast: entry.key == visits.length - 1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisitTimelineItem(
    BuildContext context, {
    required MemberDashboardCheckin visit,
    required int index,
    required bool isFirst,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final branchName = visit.branchName.trim().isEmpty ? '-' : visit.branchName;
    final statusLabel = _visitStatusLabel(visit.status);
    final statusBadge = _visitStatusBadge(visit.status);
    final normalizedStatus = visit.status.trim().toUpperCase();
    final isCheckin = normalizedStatus == 'OPEN';
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final checkpointColor = isCheckin ? AppTheme.primary : AppTheme.success;
    final badgeBackground = isCheckin
        ? (isDark ? const Color(0xFF3D1E1E) : const Color(0xFFFFEBEB))
        : (isDark ? const Color(0xFF183226) : const Color(0xFFEAF8F1));
    final badgeForeground = isCheckin
        ? (isDark ? const Color(0xFFFFB7B7) : AppTheme.primaryDark)
        : (isDark ? const Color(0xFF91E1B7) : const Color(0xFF167C4F));
    final checkpointGlow = isDark
        ? checkpointColor.withValues(alpha: 0.22)
        : checkpointColor.withValues(alpha: 0.12);
    final start = (0.54 + (index * 0.05)).clamp(0.0, 0.9).toDouble();
    final end = (start + 0.22).clamp(0.0, 1.0).toDouble();

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          Interval(start, end).transform(_entranceController.value),
        );

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: isFirst ? 26 : 0,
                    bottom: isLast ? 26 : 0,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 22,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: checkpointColor,
                        border: Border.all(
                          color: isDark
                              ? theme.scaffoldBackgroundColor
                              : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: checkpointGlow,
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171717) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isDark
                      ? const []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTimeLabel(visit.checkinAt),
                            style: TextStyle(
                              color: onSurfaceVariant.withValues(alpha: 0.95),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: onSurfaceVariant.withValues(alpha: 0.88),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusBadge,
                        style: TextStyle(
                          color: badgeForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _visitStatusLabel(String status) {
    final normalized = status.trim().toUpperCase();
    switch (normalized) {
      case 'OPEN':
        return 'Check-in berhasil';
      case 'CLOSE':
        return 'Sesi selesai';
      default:
        return normalized.isEmpty ? '-' : normalized;
    }
  }

  String _visitStatusBadge(String status) {
    final normalized = status.trim().toUpperCase();
    return normalized.isEmpty ? '-' : normalized;
  }

  String _formatDateLabel(String raw) {
    final parsed = _tryParseDate(raw);
    if (parsed == null) {
      return raw.trim().isEmpty ? '-' : raw.trim();
    }

    return '${parsed.day.toString().padLeft(2, '0')} '
        '${_monthLabel(parsed.month)} ${parsed.year}';
  }

  String _formatDateTimeLabel(String raw) {
    final parsed = _tryParseDate(raw);
    if (parsed == null) {
      return raw.trim().isEmpty ? '-' : raw.trim();
    }

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.day.toString().padLeft(2, '0')} '
        '${_monthLabel(parsed.month)} ${parsed.year} - $hour:$minute';
  }

  DateTime? _tryParseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return DateTime.tryParse(trimmed) ??
        DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
  }

  String _monthLabel(int month) {
    const monthLabels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    if (month < 1 || month > 12) {
      return '-';
    }
    return monthLabels[month - 1];
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title masih disiapkan.')));
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final dialogBackground = isDark
            ? const Color(0xFF141414)
            : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF111111);
        final contentColor = isDark
            ? Colors.white.withValues(alpha: 0.78)
            : const Color(0xFF4B5563);
        final cancelColor = isDark ? Colors.white : const Color(0xFF111111);
        final confirmBackground = isDark
            ? Colors.white
            : const Color(0xFF111111);
        final confirmForeground = isDark
            ? const Color(0xFF111111)
            : Colors.white;

        return AlertDialog(
          backgroundColor: dialogBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Keluar akun',
            style: TextStyle(color: titleColor, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Yakin mau keluar dari akun ini sekarang?',
            style: TextStyle(
              color: contentColor,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: cancelColor,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmBackground,
                foregroundColor: confirmForeground,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await const SessionStorage().clearSession();
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
      (route) => false,
    );
  }
}

class _MembershipLabel extends StatelessWidget {
  final String title;
  final String value;
  final bool alignEnd;
  final bool isActive;

  const _MembershipLabel({
    required this.title,
    required this.value,
    this.alignEnd = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          )
        else
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _HomeActionTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;

  const _HomeActionTile({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.onTap,
  });

  @override
  State<_HomeActionTile> createState() => _HomeActionTileState();
}

class _HomeActionTileState extends State<_HomeActionTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(_isPressed ? 18 : 20),
                boxShadow: [
                  if (_isPressed)
                    BoxShadow(
                      color: widget.iconColor.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 30),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;
  final bool showDot;

  const _TopBarIconButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              if (showDot)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
