import 'package:flutter/material.dart';

import '../models/member_dashboard.dart';
import '../models/user.dart';
import '../services/member_dashboard_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/recent_visit_card.dart';
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

class _MemberHomeDashboardScreenState extends State<MemberHomeDashboardScreen> {
  final _dashboardService = const MemberDashboardService();
  final _sessionStorage = const SessionStorage();

  MemberDashboard? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didUpdateWidget(covariant MemberHomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                        _buildTopBar(context),
                        const SizedBox(height: 20),
                        _buildGreetingCard(context),
                        const SizedBox(height: 20),
                        _buildMembershipCard(),
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
                      _buildErrorCard(context),
                      const SizedBox(height: 24),
                    ],
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    _buildPromoCard(context),
                    const SizedBox(height: 28),
                    _buildRecentVisitCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final accentBackground =
        isDark ? scheme.primary.withValues(alpha: 0.14) : const Color(0xFFFFE8EE);
    final accentBorder =
        isDark ? scheme.primary.withValues(alpha: 0.32) : const Color(0xFFF7C4D0);

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentBackground,
            border: Border.all(color: accentBorder),
          ),
          child: Text(
            _initials,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
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

  Widget _buildMembershipCard() {
    final status = _status;
    final isActive = status.toUpperCase() == 'ACTIVE';
    final statusLabel = status.isEmpty ? 'NONAKTIF' : status.toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF165C), Color(0xFFE52E71), Color(0xFFFF5F7E)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: 8,
            child: Icon(
              Icons.fitness_center_rounded,
              size: 108,
              color: Colors.white.withValues(alpha: 0.10),
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
    final scheme = theme.colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1B1B1B) : const Color(0xFFFFEEF2);
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFB8C7);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ajak Teman, Dapat Diskon!',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dapatkan potongan 20% untuk bulan depan.',
                      style: TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.primary.withValues(alpha: 0.9),
                  size: 34,
                ),
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
    final visits = _dashboard?.lastCheckins ?? const <MemberDashboardCheckin>[];

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
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VisitHistoryScreen()),
                );
              },
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
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
          ...visits.take(5).map(
            (visit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RecentVisitCard(
                gym: visit.branchName.trim().isEmpty ? '-' : visit.branchName,
                time: _formatDateTimeLabel(visit.checkinAt),
                status: _visitStatusLabel(visit.status),
                statusBadge: _visitStatusBadge(visit.status),
                isDark: isDark,
              ),
            ),
          ),
      ],
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title masih disiapkan.')),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Text(
            'Keluar akun',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Yakin mau keluar dari akun ini sekarang?',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
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
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  const _HomeActionTile({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedLabelColor = labelColor ?? scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: resolvedLabelColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
