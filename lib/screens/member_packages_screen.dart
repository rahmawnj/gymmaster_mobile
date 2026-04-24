import 'dart:async';

import 'package:flutter/material.dart';

import '../models/member_branch.dart';
import '../models/member_membership.dart';
import '../models/member_membership_option.dart';
import '../models/user.dart';
import '../services/camera_permission_service.dart';
import '../services/membership_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'qr_scanner_screen.dart';

class MemberPackagesScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback? onBackRequested;

  const MemberPackagesScreen({
    super.key,
    required this.currentUser,
    this.onBackRequested,
  });

  @override
  State<MemberPackagesScreen> createState() => _MemberPackagesScreenState();
}

class _MemberPackagesScreenState extends State<MemberPackagesScreen> {
  final _cameraPermissionService = const CameraPermissionService();
  final _membershipService = const MembershipService();
  final _sessionStorage = const SessionStorage();
  final _searchController = TextEditingController();

  int _tabIndex = 0;
  bool _isMembershipsLoading = true;
  bool _isBranchesLoading = true;
  bool _locationEnabled = false;
  bool _isResolvingScannedQr = false;
  String? _membershipErrorMessage;
  String? _branchErrorMessage;
  String? _locationError;
  List<MemberMembership> _memberships = const [];
  List<MemberBranch> _branches = const [];
  late final PageController _membershipPageController;
  int _currentMembershipIndex = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _membershipPageController = PageController(viewportFraction: 0.92);
    _loadMemberships();
    _loadBranches();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _membershipPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberships() async {
    setState(() {
      _isMembershipsLoading = true;
      _membershipErrorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _membershipService.fetchMemberships(
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _memberships = result;
        _isMembershipsLoading = false;
        _currentMembershipIndex = 0;
      });
      _resetAutoSlide();
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _membershipErrorMessage = error.message;
        _isMembershipsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _membershipErrorMessage = 'Gagal mengambil paket aktif.';
        _isMembershipsLoading = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isBranchesLoading = true;
      _branchErrorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _membershipService.fetchBranches(
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _branches = result;
        _isBranchesLoading = false;
      });
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _branchErrorMessage = error.message;
        _isBranchesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _branchErrorMessage = 'Gagal mengambil daftar cabang.';
        _isBranchesLoading = false;
      });
    }
  }

  void _resetAutoSlide() {
    _autoSlideTimer?.cancel();
    if (_tabIndex != 0 || _memberships.length <= 1) {
      return;
    }

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _memberships.isEmpty) {
        return;
      }

      final nextPage = (_currentMembershipIndex + 1) % _memberships.length;
      _membershipPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<MemberBranch> _buildVisibleBranches() {
    final query = _searchController.text.trim().toLowerCase();
    return _branches.where((branch) {
      if (query.isEmpty) {
        return true;
      }

      return branch.name.toLowerCase().contains(query) ||
          branch.address.toLowerCase().contains(query) ||
          branch.branchCode.toLowerCase().contains(query);
    }).toList();
  }

  MemberMembership? _activeMembershipForBranch(MemberBranch branch) {
    final normalizedBranchName = _normalizeLookup(branch.name);
    for (final membership in _memberships) {
      if (!membership.isActive) continue;
      if (_normalizeLookup(membership.branchName) == normalizedBranchName) {
        return membership;
      }
    }
    return null;
  }

  Future<void> _toggleLocation() async {
    setState(() {
      _locationEnabled = !_locationEnabled;
      _locationError = _locationEnabled
          ? 'Data cabang dari API belum menyertakan koordinat untuk urutan lokasi.'
          : null;
    });
  }

  Future<void> _openScanner() async {
    final permissionResult = await _cameraPermissionService
        .ensureCameraPermission();
    if (!mounted) return;

    switch (permissionResult) {
      case CameraPermissionResult.granted:
      case CameraPermissionResult.unsupported:
        final rawValue = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
        );
        if (!mounted || rawValue == null || rawValue.trim().isEmpty) {
          return;
        }
        await _openBranchFromQr(rawValue);
        break;
      case CameraPermissionResult.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin kamera dibutuhkan untuk mulai scan QR.'),
          ),
        );
        break;
      case CameraPermissionResult.permanentlyDenied:
        await _showCameraSettingsDialog();
        break;
    }
  }

  Future<void> _showCameraSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Izin Kamera Diperlukan'),
          content: const Text(
            'Akses kamera sedang ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkan izin kamera.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _cameraPermissionService.openSettings();
              },
              child: const Text('Buka Setting'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBranchFromQr(String rawValue) async {
    if (mounted) {
      setState(() {
        _isResolvingScannedQr = true;
      });
    }

    try {
      final branchId = _extractBranchIdFromQr(rawValue);
      if (branchId == null || branchId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR ini tidak memiliki branch_id yang bisa dibuka.'),
          ),
        );
        return;
      }

      final branches = _branches.isNotEmpty
          ? _branches
          : await _fetchBranchesForQr();
      if (!mounted) return;

      final matchedBranch = branches.cast<MemberBranch?>().firstWhere(
        (branch) => branch != null && branch.id.trim() == branchId,
        orElse: () => null,
      );

      if (matchedBranch == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Branch dengan ID $branchId tidak ditemukan.'),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _isResolvingScannedQr = false;
        });
      }
      await _showBranchSelected(matchedBranch);
    } on MembershipException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka branch dari hasil scan QR.'),
        ),
      );
    } finally {
      if (mounted && _isResolvingScannedQr) {
        setState(() {
          _isResolvingScannedQr = false;
        });
      }
    }
  }

  Future<List<MemberBranch>> _fetchBranchesForQr() async {
    final session = await _sessionStorage.loadSession();
    if (session == null || session.token.isEmpty) {
      throw const MembershipException(
        'Token tidak tersedia. Silakan login ulang.',
      );
    }

    final branches = await _membershipService.fetchBranches(
      token: session.token,
      tokenType: session.tokenType,
    );

    if (mounted) {
      setState(() {
        _branches = branches;
      });
    }

    return branches;
  }

  String? _extractBranchIdFromQr(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    final branchId = uri?.queryParameters['branch_id']?.trim();
    if (branchId != null && branchId.isNotEmpty) {
      return branchId;
    }

    return null;
  }

  Future<void> _showBranchSelected(MemberBranch branch) async {
    final activeMembership = _activeMembershipForBranch(branch);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BranchMembershipOptionsScreen(
          branch: branch,
          currentUser: widget.currentUser,
          activeMembership: activeMembership,
        ),
      ),
    );
  }

  String _normalizeLookup(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _openActiveMembershipDetail(MemberMembership membership) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final branches = _branches.isNotEmpty
          ? _branches
          : await _membershipService.fetchBranches(
              token: session.token,
              tokenType: session.tokenType,
            );

      final normalizedBranchName = _normalizeLookup(membership.branchName);
      final matchedBranch = branches.cast<MemberBranch?>().firstWhere(
        (branch) =>
            branch != null &&
            _normalizeLookup(branch.name) == normalizedBranchName,
        orElse: () => null,
      );

      if (matchedBranch == null) {
        throw const MembershipException('Cabang paket aktif tidak ditemukan.');
      }

      final options = await _membershipService.fetchMembershipOptions(
        branchId: matchedBranch.id,
        token: session.token,
        tokenType: session.tokenType,
      );

      final normalizedMembershipName = _normalizeLookup(
        membership.membershipName,
      );
      final matchedOption = options.cast<MemberMembershipOption?>().firstWhere((
        option,
      ) {
        if (option == null) return false;
        final optionName = _normalizeLookup(option.name);
        return optionName == normalizedMembershipName ||
            optionName.contains(normalizedMembershipName) ||
            normalizedMembershipName.contains(optionName);
      }, orElse: () => null);

      final detailId = matchedOption?.id.trim().isNotEmpty == true
          ? matchedOption!.id
          : membership.id.trim();

      if (detailId.isEmpty) {
        throw const MembershipException('Detail paket aktif belum tersedia.');
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _MembershipOptionDetailScreen(
            membershipId: detailId,
            title: membership.membershipName,
            subtitle: membership.branchName,
            memberId: widget.currentUser.memberId,
            showPurchaseButton: false,
          ),
        ),
      );
    } on MembershipException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal membuka detail paket aktif.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F1012)
        : const Color(0xFFF6F7FB);
    final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
    final surfaceSoft = isDark
        ? const Color(0xFF22242A)
        : const Color(0xFFF4F6FB);
    final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
    final inkSoft = isDark ? const Color(0xFFB5BCC8) : AppTheme.inkSoft;
    final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;
    final borderColor = isDark
        ? const Color(0xFF2A2D33)
        : const Color(0xFFE8E8E8);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Membership',
          style: TextStyle(
            color: inkColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildSegmentedTabs(
                  surfaceColor: surfaceColor,
                  inkSoft: inkSoft,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _tabIndex == 0
                      ? _buildActiveMembershipsView(
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          surfaceSoft: surfaceSoft,
                          inkColor: inkColor,
                          muted: muted,
                          borderColor: borderColor,
                        )
                      : _buildBuyPackageView(
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          surfaceSoft: surfaceSoft,
                          inkColor: inkColor,
                          muted: muted,
                          borderColor: borderColor,
                        ),
                ),
              ],
            ),
          ),
          if (_isResolvingScannedQr)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.28),
                  alignment: Alignment.center,
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18191C) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Membuka branch...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: inkColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'QR sedang diproses, tunggu sebentar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs({
    required Color surfaceColor,
    required Color inkSoft,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = (constraints.maxWidth - 6) / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _tabIndex == 0 ? 0 : halfWidth + 6,
                  top: 0,
                  bottom: 0,
                  width: halfWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        label: 'Paket Aktif',
                        isActive: _tabIndex == 0,
                        inactiveColor: inkSoft,
                        onTap: () {
                          setState(() => _tabIndex = 0);
                          _resetAutoSlide();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTabButton(
                        label: 'Beli Paket',
                        isActive: _tabIndex == 1,
                        inactiveColor: inkSoft,
                        onTap: () {
                          setState(() => _tabIndex = 1);
                          _autoSlideTimer?.cancel();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: isActive ? Colors.white : inactiveColor,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildActiveMembershipsView({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color muted,
    required Color borderColor,
  }) {
    if (_isMembershipsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_membershipErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(height: 16),
              Text(
                _membershipErrorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: inkColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loadMemberships,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_memberships.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.layers_clear_rounded,
                size: 56,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada paket aktif',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: inkColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paket aktif akan muncul di halaman ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMemberships,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          if (_memberships.length == 1)
            _buildMembershipCard(
              _memberships.first,
              isDark: isDark,
              surfaceColor: surfaceColor,
              surfaceSoft: surfaceSoft,
              inkColor: inkColor,
              borderColor: borderColor,
            )
          else
            SizedBox(
              height: 236,
              child: PageView.builder(
                controller: _membershipPageController,
                itemCount: _memberships.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentMembershipIndex = index;
                  });
                  _resetAutoSlide();
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _buildMembershipCard(
                      _memberships[index],
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      surfaceSoft: surfaceSoft,
                      inkColor: inkColor,
                      borderColor: borderColor,
                    ),
                  );
                },
              ),
            ),
          if (_memberships.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _memberships.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentMembershipIndex == index ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentMembershipIndex == index
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembershipCard(
    MemberMembership membership, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color borderColor,
  }) {
    final isActive = membership.isActive;
    final textColor = isActive || isDark ? Colors.white : AppTheme.ink;
    final mutedText = isActive || isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppTheme.muted;
    final cardGradient = isActive
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B2D31), Color(0xFF111214)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFD)],
          );
    final datePanelColor = isActive
        ? textColor.withValues(alpha: 0.04)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openActiveMembershipDetail(membership),
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.03);
          }
          return null;
        }),
        child: Ink(
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            color: isActive ? AppTheme.primary : mutedText,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              membership.branchName.isEmpty
                                  ? '-'
                                  : membership.branchName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mutedText,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  membership.membershipName.isEmpty
                      ? '-'
                      : membership.membershipName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: datePanelColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MembershipDateItem(
                          label: 'BERLAKU MULAI',
                          value: _formatMembershipDate(membership.startDate),
                          textColor: textColor,
                          mutedText: mutedText,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: textColor.withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MembershipDateItem(
                          label: 'BERAKHIR PADA',
                          value: _formatMembershipDate(membership.expDate),
                          textColor: textColor,
                          mutedText: mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyPackageView({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color muted,
    required Color borderColor,
  }) {
    final visibleBranches = _buildVisibleBranches();

    return RefreshIndicator(
      onRefresh: _loadBranches,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildBuyToolbar(
            surfaceColor: surfaceColor,
            surfaceSoft: surfaceSoft,
            inkColor: inkColor,
            muted: muted,
          ),
          const SizedBox(height: 16),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                _locationError!,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_isBranchesLoading)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_branchErrorMessage != null)
            _buildInfoCard(
              isDark: isDark,
              surfaceColor: surfaceColor,
              message: _branchErrorMessage!,
              buttonLabel: 'Coba Lagi',
              onPressed: _loadBranches,
            )
          else if (visibleBranches.isEmpty)
            _buildInfoCard(
              isDark: isDark,
              surfaceColor: surfaceColor,
              message: 'Tidak ada cabang yang cocok dengan pencarianmu.',
            )
          else
            ...visibleBranches.map(
              (branch) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildBranchCard(
                  branch: branch,
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  surfaceSoft: surfaceSoft,
                  inkColor: inkColor,
                  muted: muted,
                  borderColor: borderColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuyToolbar({
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color muted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: inkColor),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search cabang',
                    hintStyle: TextStyle(color: muted),
                    prefixIcon: Icon(Icons.search_rounded, color: muted),
                    filled: true,
                    fillColor: surfaceSoft,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 50,
                height: 50,
                child: ElevatedButton(
                  onPressed: _openScanner,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _toggleLocation,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: _locationEnabled
                          ? AppTheme.primary.withValues(alpha: 0.16)
                          : surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _locationEnabled
                            ? AppTheme.primary.withValues(alpha: 0.55)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _locationEnabled
                              ? Icons.my_location_rounded
                              : Icons.location_off_rounded,
                          color: _locationEnabled ? AppTheme.primary : muted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _locationEnabled ? 'Lokasi On' : 'Lokasi Off',
                          style: TextStyle(
                            color: _locationEnabled
                                ? AppTheme.primary
                                : inkColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required Color surfaceColor,
    required String message,
    String? buttonLabel,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191C) : surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchCard({
    required MemberBranch branch,
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color muted,
    required Color borderColor,
  }) {
    final activeMembership = _activeMembershipForBranch(branch);
    final hasActiveMembership = activeMembership != null;
    final cardColor = hasActiveMembership
        ? (isDark ? const Color(0xFF1C1A1C) : const Color(0xFFFFF5F6))
        : (isDark ? const Color(0xFF18191C) : surfaceColor);
    final cardBorderColor = hasActiveMembership
        ? AppTheme.primary.withValues(alpha: isDark ? 0.30 : 0.16)
        : Colors.transparent;
    final infoPanelColor = hasActiveMembership
        ? (isDark ? const Color(0xFF262126) : const Color(0xFFFFFBFC))
        : surfaceSoft;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorderColor),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 58,
                width: 58,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const AppLogo(
                  size: 46,
                  variant: AppLogoVariant.iconOnly,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: inkColor,
                        fontSize: 19,
                      ),
                    ),
                    if (hasActiveMembership) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Paket aktif di sini',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AnimatedBranchArrowButton(
                onPressed: () => _showBranchSelected(branch),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            branch.address.trim().isEmpty
                ? 'Alamat cabang belum tersedia.'
                : branch.address,
            style: TextStyle(
              color: muted.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          if (hasActiveMembership) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activeMembership.membershipName.trim().isEmpty
                          ? 'Kamu punya paket aktif di branch ini.'
                          : 'Paket aktif: ${activeMembership.membershipName}',
                      style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: infoPanelColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasActiveMembership
                    ? AppTheme.primary.withValues(alpha: 0.10)
                    : borderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.pin_drop_outlined, color: muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.branchCode.trim().isEmpty
                            ? 'Kode branch belum tersedia'
                            : branch.branchCode,
                        style: TextStyle(
                          color: inkColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMembershipDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }

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

    final day = parsed.day.toString().padLeft(2, '0');
    final month = monthLabels[parsed.month - 1];
    final year = parsed.year.toString();
    return '$day $month $year';
  }
}

class _MembershipDateItem extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedText;

  const _MembershipDateItem({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: mutedText,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BranchMembershipOptionsScreen extends StatefulWidget {
  final MemberBranch branch;
  final User currentUser;
  final MemberMembership? activeMembership;

  const _BranchMembershipOptionsScreen({
    required this.branch,
    required this.currentUser,
    this.activeMembership,
  });

  @override
  State<_BranchMembershipOptionsScreen> createState() =>
      _BranchMembershipOptionsScreenState();
}

class _BranchMembershipOptionsScreenState
    extends State<_BranchMembershipOptionsScreen> {
  final _membershipService = const MembershipService();
  final _sessionStorage = const SessionStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<MemberMembershipOption> _options = const [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _membershipService.fetchMembershipOptions(
        branchId: widget.branch.id,
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _options = result;
        _isLoading = false;
      });
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengambil detail paket.';
        _isLoading = false;
      });
    }
  }

  void _openOptionDetail(MemberMembershipOption option) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MembershipOptionDetailScreen(
          membershipId: option.id,
          title: option.name,
          subtitle: widget.branch.name,
          memberId: widget.currentUser.memberId,
        ),
      ),
    );
  }

  bool _isOwnedOption(MemberMembershipOption option) {
    final activeMembership = widget.activeMembership;
    if (activeMembership == null || !activeMembership.isActive) {
      return false;
    }

    String normalize(String value) {
      return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    }

    final optionName = normalize(option.name);
    final activeName = normalize(activeMembership.membershipName);
    return optionName.isNotEmpty &&
        activeName.isNotEmpty &&
        (optionName == activeName ||
            optionName.contains(activeName) ||
            activeName.contains(optionName));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F1012)
        : const Color(0xFFF6F7FB);
    final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
    final surfaceSoft = isDark
        ? const Color(0xFF22242A)
        : const Color(0xFFF4F6FB);
    final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
    final inkSoft = isDark ? const Color(0xFFB5BCC8) : AppTheme.inkSoft;
    final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;
    final borderColor = isDark
        ? const Color(0xFF2A2D33)
        : const Color(0xFFE8E8E8);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        titleSpacing: 0,
        title: Text(
          widget.branch.name,
          style: TextStyle(color: inkColor, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOptions,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const AppLogo(
                      size: 46,
                      variant: AppLogoVariant.iconOnly,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.branch.name,
                          style: TextStyle(
                            color: inkColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.branch.address,
                          style: TextStyle(
                            color: muted,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.branch.branchCode,
                          style: TextStyle(
                            color: inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail paket belum bisa dimuat',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: muted, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _loadOptions,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_options.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Belum ada paket tersedia di cabang ini.',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                ),
              )
            else
              ..._options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MembershipOptionCard(
                    option: option,
                    isOwned: _isOwnedOption(option),
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    surfaceSoft: surfaceSoft,
                    inkColor: inkColor,
                    inkSoft: inkSoft,
                    muted: muted,
                    borderColor: borderColor,
                    onSelect: () => _openOptionDetail(option),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MembershipOptionCard extends StatelessWidget {
  final MemberMembershipOption option;
  final bool isOwned;
  final bool isDark;
  final Color surfaceColor;
  final Color surfaceSoft;
  final Color inkColor;
  final Color inkSoft;
  final Color muted;
  final Color borderColor;
  final VoidCallback? onSelect;

  const _MembershipOptionCard({
    required this.option,
    this.isOwned = false,
    required this.isDark,
    required this.surfaceColor,
    required this.surfaceSoft,
    required this.inkColor,
    required this.inkSoft,
    required this.muted,
    required this.borderColor,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBackground = isOwned
        ? AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.10)
        : (isDark ? const Color(0xFF262A31) : const Color(0xFFF0F3F8));
    final cardBackground = isOwned
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF2B2428), Color(0xFF1D191C)]
                : const [Color(0xFFFFF7F8), Color(0xFFFFFCFC)],
          )
        : (isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF23252B), Color(0xFF1A1C21)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FB)],
                ));
    final actionBackground = isDark
        ? AppTheme.primary.withValues(alpha: 0.14)
        : const Color(0xFFFFECEC);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOwned
              ? AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                  '${option.durationDays} Hari',
                  style: TextStyle(
                    color: isOwned ? AppTheme.primary : inkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isOwned) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'DIMILIKI',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            option.name,
            style: TextStyle(
              color: inkColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (option.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              option.description,
              style: TextStyle(
                color: muted,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _formatCurrency(option.price),
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _OptionFeatureRow(
            icon: Icons.event_repeat_rounded,
            text: 'Max visit ${option.maxVisit} kali per hari',
            color: inkSoft,
          ),
          _OptionFeatureRow(
            icon: Icons.calendar_month_rounded,
            text: 'Durasi aktif ${option.durationDays} hari',
            color: inkSoft,
          ),
          if (isOwned) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                'Paket ini sedang kamu miliki di branch ini.',
                style: TextStyle(
                  color: inkColor,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (option.isActive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect ?? () => _showSelectConfirmation(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionBackground,
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Text(isOwned ? 'Lihat Paket Aktif' : 'Beli Paket'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSelectConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191B20) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Beli paket ini?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  option.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatCurrency(option.price)} • ${option.durationDays} hari',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Beli'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await _showPurchaseSuccess(context);
    }
  }

  Future<void> _showPurchaseSuccess(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191B20) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppTheme.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Menunggu Konfirmasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Permintaan pembelian untuk ${option.name} sudah dikirim. Mohon tunggu konfirmasi dari admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(option.price),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Oke'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCurrency(int value) {
    final raw = value.toString();
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }
}

class _OptionFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _OptionFeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipOptionDetailScreen extends StatefulWidget {
  final String membershipId;
  final String title;
  final String subtitle;
  final String memberId;
  final bool showPurchaseButton;

  const _MembershipOptionDetailScreen({
    required this.membershipId,
    required this.title,
    required this.subtitle,
    required this.memberId,
    this.showPurchaseButton = true,
  });

  @override
  State<_MembershipOptionDetailScreen> createState() =>
      _MembershipOptionDetailScreenState();
}

class _MembershipOptionDetailScreenState
    extends State<_MembershipOptionDetailScreen> {
  final _membershipService = const MembershipService();
  final _sessionStorage = const SessionStorage();

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _hasPendingPurchase = false;
  String? _pendingPurchaseMessage;
  String? _errorMessage;
  MemberMembershipOption? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final detail = await _membershipService.fetchMembershipOptionDetail(
        membershipId: widget.membershipId,
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengambil detail membership.';
        _isLoading = false;
      });
    }
  }

  String _buildStartDate() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  String _purchaseStatusLabel(String rawStatus) {
    final normalized = rawStatus.trim();
    return normalized.isEmpty ? 'UNPAID' : normalized.toUpperCase();
  }

  String _purchaseFailureTitle(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('already have active membership')) {
      return 'Membership Sudah Aktif';
    }
    if (normalized.contains('already have unpaid membership')) {
      return 'Pembayaran Masih Tertunda';
    }
    return 'Pembelian Gagal';
  }

  Future<void> _showPurchaseFailureDialog(String message) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : const Color(0xFF101114);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF5F6672);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191B20) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _purchaseFailureTitle(message),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPurchaseSuccessDialog(
    MembershipPurchaseResult result,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : const Color(0xFF101114);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF5F6672);
    final surfaceSoft = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF4F5F8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE6E8EE);
    final statusLabel = _purchaseStatusLabel(result.status);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191B20) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.primary,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pembelian Berhasil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  result.message,
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      if (result.transactionId > 0)
                        _PurchaseInfoRow(
                          label: 'ID Transaksi',
                          value: '#${result.transactionId}',
                          inkColor: inkColor,
                          muted: muted,
                        ),
                      if (result.transactionCode.trim().isNotEmpty)
                        _PurchaseInfoRow(
                          label: 'Kode Transaksi',
                          value: result.transactionCode,
                          inkColor: inkColor,
                          muted: muted,
                        ),
                      _PurchaseInfoRow(
                        label: 'Status',
                        value: statusLabel,
                        inkColor: inkColor,
                        muted: muted,
                      ),
                      _PurchaseInfoRow(
                        label: 'Total Bayar',
                        value: _formatCurrency(result.totalPrice),
                        inkColor: inkColor,
                        muted: muted,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _purchaseMembership() async {
    final detail = _detail;
    final memberId = int.tryParse(widget.memberId);
    final membershipId = int.tryParse(widget.membershipId);

    if (detail == null || memberId == null || membershipId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data pembelian membership belum lengkap.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Pembelian'),
          content: Text(
            'Lanjut beli paket ${detail.name} seharga ${_formatCurrency(detail.price)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Beli'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _membershipService.purchaseMembership(
        memberId: memberId,
        membershipId: membershipId,
        startDate: _buildStartDate(),
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _hasPendingPurchase = true;
        _pendingPurchaseMessage = result.transactionCode.trim().isNotEmpty
            ? 'Transaksi ${result.transactionCode} berhasil dibuat dengan status '
                  '${_purchaseStatusLabel(result.status)}. '
                  'Silakan lanjutkan pembayaran.'
            : result.message;
      });
      await _showPurchaseSuccessDialog(result);
    } on MembershipException catch (error) {
      if (!mounted) return;
      final normalizedMessage = error.message.toLowerCase();
      final alreadyPending = normalizedMessage.contains(
        'already have unpaid membership',
      );
      if (alreadyPending) {
        setState(() {
          _hasPendingPurchase = true;
          _pendingPurchaseMessage =
              'Kamu masih punya membership dengan pembayaran tertunda di cabang ini. Selesaikan dulu pembayaran sebelumnya.';
        });
      }
      await _showPurchaseFailureDialog(error.message);
    } catch (_) {
      if (!mounted) return;
      await _showPurchaseFailureDialog(
        'Gagal memproses pembelian membership.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  String _formatCurrency(int value) {
    final raw = value.toString();
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F1012)
        : const Color(0xFFF6F7FB);
    final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
    final surfaceSoft = isDark
        ? const Color(0xFF22242A)
        : const Color(0xFFF4F6FB);
    final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
    final inkSoft = isDark ? const Color(0xFFB5BCC8) : AppTheme.inkSoft;
    final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        titleSpacing: 0,
        title: Text(
          widget.subtitle.trim().isEmpty ? 'Detail Paket' : widget.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: inkColor, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail paket belum bisa dimuat',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: muted, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _loadDetail,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_detail != null)
              _MembershipOwnedDetailSection(
                option: _detail!,
                inkColor: inkColor,
                inkSoft: inkSoft,
                muted: muted,
                surfaceSoft: surfaceSoft,
                showPurchaseButton: widget.showPurchaseButton,
                isPurchasing: _isPurchasing,
                hasPendingPurchase: _hasPendingPurchase,
                pendingPurchaseMessage: _pendingPurchaseMessage,
                onPurchase: _purchaseMembership,
              ),
          ],
        ),
      ),
    );
  }
}

class _MembershipOwnedDetailSection extends StatelessWidget {
  final MemberMembershipOption option;
  final Color inkColor;
  final Color inkSoft;
  final Color muted;
  final Color surfaceSoft;
  final bool showPurchaseButton;
  final bool isPurchasing;
  final bool hasPendingPurchase;
  final String? pendingPurchaseMessage;
  final Future<void> Function() onPurchase;

  const _MembershipOwnedDetailSection({
    required this.option,
    required this.inkColor,
    required this.inkSoft,
    required this.muted,
    required this.surfaceSoft,
    required this.showPurchaseButton,
    required this.isPurchasing,
    required this.hasPendingPurchase,
    required this.pendingPurchaseMessage,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final accentSoft = AppTheme.primary.withValues(alpha: 0.10);
    final accentBorder = AppTheme.primary.withValues(alpha: 0.22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.name,
          style: TextStyle(
            color: inkColor,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        if (option.description.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            option.description,
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accentSoft, AppTheme.primary.withValues(alpha: 0.04)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Harga Membership',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(option.price),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _OwnedInfoChip(
                    icon: Icons.calendar_month_rounded,
                    label: '${option.durationDays} hari aktif',
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    textColor: inkColor,
                  ),
                  _OwnedInfoChip(
                    icon: Icons.event_repeat_rounded,
                    label: '${option.maxVisit} visit per hari',
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    textColor: inkColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Ringkasan Paket',
          style: TextStyle(
            color: inkColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        _OwnedDetailRow(
          title: 'Durasi aktif',
          value: '${option.durationDays} hari',
          icon: Icons.timelapse_rounded,
          color: inkColor,
          muted: muted,
        ),
        _OwnedDetailRow(
          title: 'Max visit',
          value: '${option.maxVisit} kali per hari',
          icon: Icons.fitness_center_rounded,
          color: inkColor,
          muted: muted,
        ),
        if (hasPendingPurchase && pendingPurchaseMessage != null) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              pendingPurchaseMessage!,
              style: TextStyle(
                color: inkColor,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
        if (showPurchaseButton && option.isActive) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPurchasing || hasPendingPurchase ? null : onPurchase,
              child: Text(
                isPurchasing
                    ? 'Memproses...'
                    : hasPendingPurchase
                    ? 'Menunggu Konfirmasi'
                    : 'Beli Paket',
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatCurrency(int value) {
    final raw = value.toString();
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }
}

class _OwnedDetailRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color muted;

  const _OwnedDetailRow({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Divider(color: muted.withValues(alpha: 0.18), height: 1),
      ],
    );
  }
}

class _OwnedInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _OwnedInfoChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color inkColor;
  final Color muted;
  final bool isLast;

  const _PurchaseInfoRow({
    required this.label,
    required this.value,
    required this.inkColor,
    required this.muted,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: inkColor,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBranchArrowButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedBranchArrowButton({required this.onPressed});

  @override
  State<_AnimatedBranchArrowButton> createState() =>
      _AnimatedBranchArrowButtonState();
}

class _AnimatedBranchArrowButtonState
    extends State<_AnimatedBranchArrowButton> {
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
    final isActive = _isHovered || _isPressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            offset: isActive ? const Offset(0.08, -0.08) : Offset.zero,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              turns: isActive ? -0.08 : 0,
              child: const Icon(Icons.arrow_forward_rounded, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
