import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';

import '../models/member_dashboard.dart';
import '../models/user.dart';
import '../services/member_dashboard_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import 'qr_scanner_screen.dart';

class ScanQrHubScreen extends StatefulWidget {
  final User currentUser;

  const ScanQrHubScreen({super.key, required this.currentUser});

  @override
  State<ScanQrHubScreen> createState() => _ScanQrHubScreenState();
}

class _ScanQrHubScreenState extends State<ScanQrHubScreen> {
  String? _lastScanResult;
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

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }

    setState(() {
      _lastScanResult = result;
    });
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

      debugPrint('===== SCAN QR DASHBOARD REQUEST =====');
      debugPrint(
        'URL: https://gym-master-mobile-968815791026.asia-southeast1.run.app/api/v1/mobile/members/dashboard',
      );
      debugPrint('METHOD: GET');
      debugPrint('BEARER: ${session.tokenType} ${session.token}');
      debugPrint('BODY: <empty>');

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
    final memberCode = dashboard?.memberCode.trim() ?? '';
    final memberName = dashboard?.name.trim() ?? '';
    final memberStatus = dashboard?.status.trim().toUpperCase() ?? '';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth - 164).clamp(220.0, 320.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboardData(showSuccessMessage: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded,
                        color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Member ID',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Data member diambil dari endpoint GET /members/dashboard. Scan QR Code ini di gate untuk masuk ke dalam Gym.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (memberStatus.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            memberStatus == 'ACTIVE'
                                ? 'MEMBER AKTIF'
                                : memberStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (_isRefreshing && !_hasLoadedOnce)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        )
                      else if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1C1C1C)
                                : const Color(0xFFF8F3F3),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data member belum bisa dimuat',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () =>
                                    _loadDashboardData(showSuccessMessage: true),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      else if (memberCode.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1C1C1C)
                                : const Color(0xFFF8F3F3),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'Member code dari dashboard belum tersedia.',
                            style: TextStyle(
                              color: onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        _QrMatrix(
                          key: ValueKey(_qrRenderNonce),
                          value: memberCode,
                          size: qrSize,
                        ),
                      const SizedBox(height: 14),
                      Text(
                        memberName.isEmpty ? 'MEMBER' : memberName.toUpperCase(),
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        memberCode.isEmpty ? '-' : memberCode.toUpperCase(),
                        style: TextStyle(
                          color: onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () =>
                              _loadDashboardData(showSuccessMessage: true),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF222429)
                                : const Color(0xFFF4F5F7),
                            foregroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.88)
                                : onSurface.withValues(alpha: 0.78),
                            disabledBackgroundColor: isDark
                                ? const Color(0xFF222429)
                                : const Color(0xFFF4F5F7),
                            disabledForegroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : onSurface.withValues(alpha: 0.42),
                            minimumSize: const Size(44, 44),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: _isRefreshing ? AppTheme.primary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openScanner,
                    child: const Text('Mulai scan QR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrMatrix extends StatelessWidget {
  final String value;
  final double size;

  const _QrMatrix({super.key, required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matrix = Encoder.encode(value, ErrorCorrectionLevel.m).matrix!;
    const quietZone = 4; // modules
    final matrixSize = matrix.width + (quietZone * 2);
    final targetSize = size.floorToDouble();

    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                    children: List.generate(
                      matrixSize,
                      (x) {
                        final mx = x - quietZone;
                        final my = y - quietZone;
                        final isDark = mx >= 0 &&
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
                      },
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
