import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';

import '../models/member_dashboard.dart';
import '../models/user.dart';
import '../services/member_dashboard_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';

class ScanQrHubScreen extends StatefulWidget {
  final User currentUser;

  const ScanQrHubScreen({super.key, required this.currentUser});

  @override
  State<ScanQrHubScreen> createState() => _ScanQrHubScreenState();
}

class _ScanQrHubScreenState extends State<ScanQrHubScreen> {
  int _qrRenderNonce = 0;
  MemberDashboard? _dashboard;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  final _dashboardService = const MemberDashboardService();
  final _sessionStorage = const SessionStorage();

  @override
  void initState() {
    super.initState();
    final cachedDashboard = _dashboardService.cachedDashboard;
    if (cachedDashboard != null) {
      _dashboard = cachedDashboard;
      _hasLoadedOnce = true;
      _qrRenderNonce = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDashboardData();
    });
  }

  @override
  void didUpdateWidget(covariant ScanQrHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.memberId != widget.currentUser.memberId ||
        oldWidget.currentUser.name != widget.currentUser.name ||
        oldWidget.currentUser.memberCode != widget.currentUser.memberCode ||
        oldWidget.currentUser.status != widget.currentUser.status) {
      final cachedDashboard = _dashboardService.cachedDashboard;
      setState(() {
        _dashboard = cachedDashboard;
        _hasLoadedOnce = cachedDashboard != null;
        if (cachedDashboard != null) {
          _qrRenderNonce++;
        }
      });
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData({bool showSuccessMessage = false}) async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null) {
        throw const MemberDashboardException('Sesi login tidak ditemukan.');
      }

      final dashboard = await _dashboardService.fetchDashboard(
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _qrRenderNonce++;
        _hasLoadedOnce = true;
        _errorMessage = null;
      });
      if (showSuccessMessage && mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          const SnackBar(content: Text('Data member berhasil di-refresh.')),
        );
      }
    } on MemberDashboardException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _hasLoadedOnce = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengambil data member. Coba lagi.';
        _hasLoadedOnce = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final memberCode = _resolveMemberCode(dashboard);
    final memberName = _resolveMemberName(dashboard);
    final memberStatus = _resolveMemberStatus(dashboard);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F1012)
        : const Color(0xFFE9EDF3);
    final surfaceColor = isDark
        ? const Color(0xFF18191C)
        : const Color(0xFFF0F3F6);
    final borderColor = isDark
        ? const Color(0xFF2A2D33)
        : const Color(0xFFDDE2E9);
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth - 112).clamp(210.0, 320.0).toDouble();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboardData(showSuccessMessage: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              _buildHeader(
                onSurface: onSurface,
                muted: onSurfaceVariant,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 22),
              _buildQrAccessCard(
                memberCode: memberCode,
                memberName: memberName,
                memberStatus: memberStatus,
                qrSize: qrSize,
                onSurface: onSurface,
                muted: onSurfaceVariant,
                stateBackgroundColor: surfaceColor,
                cardBorderColor: borderColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveMemberCode(MemberDashboard? dashboard) {
    final fromDashboard = dashboard?.memberCode.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard;
    }

    return widget.currentUser.memberCode.trim();
  }

  String _resolveMemberName(MemberDashboard? dashboard) {
    final fromDashboard = dashboard?.name.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard;
    }

    final fromUser = widget.currentUser.name.trim();
    return fromUser.isEmpty ? 'Member Gymmaster' : fromUser;
  }

  String _resolveMemberStatus(MemberDashboard? dashboard) {
    final fromDashboard = dashboard?.status.trim() ?? '';
    if (fromDashboard.isNotEmpty) {
      return fromDashboard.toUpperCase();
    }

    return widget.currentUser.status.trim().toUpperCase();
  }

  Widget _buildHeader({
    required Color onSurface,
    required Color muted,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QR Member',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _RefreshButton(
          isRefreshing: _isRefreshing,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          iconColor: onSurface,
          onTap: _isRefreshing
              ? null
              : () => _loadDashboardData(showSuccessMessage: true),
        ),
      ],
    );
  }

  Widget _buildQrAccessCard({
    required String memberCode,
    required String memberName,
    required String memberStatus,
    required double qrSize,
    required Color onSurface,
    required Color muted,
    required Color stateBackgroundColor,
    required Color cardBorderColor,
  }) {
    final hasBlockingError = _errorMessage != null && memberCode.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: stateBackgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cardBorderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: _StatusPill(
              status: memberStatus,
              isLoading: _isRefreshing && !_hasLoadedOnce,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 42),
            child: Column(
              children: [
                Text(
                  'Tunjukkan kode ini di gate untuk akses masuk gym.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted.withValues(alpha: 0.92),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                _buildQrContent(
                  memberCode: memberCode,
                  qrSize: qrSize,
                  muted: muted,
                  stateBackgroundColor: stateBackgroundColor,
                  hasBlockingError: hasBlockingError,
                ),
                if (_errorMessage != null && memberCode.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SyncWarning(
                    message: _errorMessage!,
                    surfaceColor: stateBackgroundColor,
                    textColor: muted,
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  memberName.isEmpty ? 'Member Gymmaster' : memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  memberCode.isEmpty ? '-' : memberCode.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrContent({
    required String memberCode,
    required double qrSize,
    required Color muted,
    required Color stateBackgroundColor,
    required bool hasBlockingError,
  }) {
    if (_isRefreshing && !_hasLoadedOnce) {
      return _QrLoadingPlaceholder(size: qrSize, color: muted);
    }

    if (hasBlockingError) {
      return _QrInlineState(
        size: qrSize,
        icon: Icons.cloud_off_outlined,
        title: 'Data member belum bisa dimuat',
        message: _errorMessage!,
        actionLabel: 'Coba Lagi',
        onAction: () => _loadDashboardData(showSuccessMessage: true),
        backgroundColor: stateBackgroundColor,
        textColor: muted,
      );
    }

    if (memberCode.isEmpty) {
      return _QrInlineState(
        size: qrSize,
        icon: Icons.qr_code_2_rounded,
        title: 'QR belum tersedia',
        message: 'Member code dari dashboard belum tersedia.',
        actionLabel: 'Refresh Data',
        onAction: () => _loadDashboardData(showSuccessMessage: true),
        backgroundColor: stateBackgroundColor,
        textColor: muted,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(begin: 0.985, end: 1).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: _QrMatrix(
        key: ValueKey(_qrRenderNonce),
        value: memberCode,
        size: qrSize,
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool isRefreshing;
  final Color surfaceColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _RefreshButton({
    required this.isRefreshing,
    required this.surfaceColor,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isRefreshing
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    key: const ValueKey('refresh'),
                    color: iconColor,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool isLoading;

  const _StatusPill({required this.status, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final isActive = normalized == 'ACTIVE';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isActive ? AppTheme.success : AppTheme.primary;
    final label = isLoading
        ? 'SYNC'
        : normalized.isEmpty
        ? 'BELUM ADA'
        : isActive
        ? 'AKTIF'
        : normalized;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _QrLoadingPlaceholder extends StatelessWidget {
  final double size;
  final Color color;

  const _QrLoadingPlaceholder({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 52,
      height: size + 52,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Menyiapkan QR...',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrInlineState extends StatelessWidget {
  final double size;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Color backgroundColor;
  final Color textColor;

  const _QrInlineState({
    required this.size,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 52,
      constraints: BoxConstraints(minHeight: size + 52),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primary, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _SyncWarning extends StatelessWidget {
  final String message;
  final Color surfaceColor;
  final Color textColor;

  const _SyncWarning({
    required this.message,
    required this.surfaceColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrMatrix extends StatefulWidget {
  final String value;
  final double size;

  const _QrMatrix({super.key, required this.value, required this.size});

  @override
  State<_QrMatrix> createState() => _QrMatrixState();
}

class _QrMatrixState extends State<_QrMatrix>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matrix = Encoder.encode(widget.value, ErrorCorrectionLevel.m).matrix!;
    const quietZone = 4; // modules
    final matrixSize = matrix.width + (quietZone * 2);
    final targetSize = widget.size.floorToDouble();

    return Center(
      child: AnimatedBuilder(
        animation: _borderController,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: SizedBox.square(
            dimension: targetSize,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.square(
                dimension: matrixSize.toDouble(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    matrixSize,
                    (y) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(matrixSize, (x) {
                        final mx = x - quietZone;
                        final my = y - quietZone;
                        final isDark =
                            mx >= 0 &&
                            my >= 0 &&
                            mx < matrix.width &&
                            my < matrix.height &&
                            matrix.get(mx, my) == 1;
                        return SizedBox(
                          width: 1,
                          height: 1,
                          child: ColoredBox(
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        builder: (context, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: SweepGradient(
                transform: GradientRotation(
                  _borderController.value * math.pi * 2,
                ),
                colors: const [
                  Color(0xFFFF4F93),
                  Color(0xFF9B5CFF),
                  Color(0xFF2E7DFF),
                  Color(0xFFFF4F93),
                ],
                stops: const [0.0, 0.34, 0.72, 1.0],
              ),
              borderRadius: BorderRadius.circular(29),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CFF).withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(padding: const EdgeInsets.all(3), child: child),
          );
        },
      ),
    );
  }
}
