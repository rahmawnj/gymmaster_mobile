import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../models/member_branch.dart';
import '../models/member_membership.dart';
import '../models/member_membership_option.dart';
import '../models/member_training_package.dart';
import '../models/member_trainer_package_option.dart';
import '../models/user.dart';
import '../services/camera_permission_service.dart';
import '../services/membership_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/modern_modal_dialog.dart';
import '../widgets/top_notification.dart';
import 'qr_scanner_screen.dart';

class MemberPackagesScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback? onBackRequested;
  final GlobalKey? membershipCardKey;

  const MemberPackagesScreen({
    super.key,
    required this.currentUser,
    this.onBackRequested,
    this.membershipCardKey,
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
  bool _isTrainingPackagesLoading = true;
  bool _isBranchesLoading = true;
  bool _locationEnabled = false;
  bool _isResolvingScannedQr = false;
  String? _membershipErrorMessage;
  String? _trainingPackageErrorMessage;
  String? _branchErrorMessage;
  String? _locationError;
  List<MemberMembership> _memberships = const [];
  List<MemberTrainingPackage> _trainingPackages = const [];
  List<MemberBranch> _branches = const [];
  late final PageController _membershipPageController;
  int _currentMembershipIndex = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _membershipPageController = PageController(viewportFraction: 0.92);
    _loadMemberships();
    _loadTrainingPackages();
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

  Future<void> _loadTrainingPackages() async {
    setState(() {
      _isTrainingPackagesLoading = true;
      _trainingPackageErrorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _membershipService.fetchActiveTrainingPackages(
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _trainingPackages = result;
        _isTrainingPackagesLoading = false;
      });
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _trainingPackageErrorMessage = error.message;
        _isTrainingPackagesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trainingPackageErrorMessage =
            'Gagal mengambil package training aktif.';
        _isTrainingPackagesLoading = false;
      });
    }
  }

  Future<void> _refreshActivePackages() async {
    await Future.wait([_loadMemberships(), _loadTrainingPackages()]);
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
        TopNotification.show(
          context,
          message: 'Izin kamera dibutuhkan untuk mulai scan QR.',
          type: TopNotificationType.error,
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
        TopNotification.show(
          context,
          message: 'QR ini tidak memiliki branch_id yang bisa dibuka.',
          type: TopNotificationType.error,
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
        TopNotification.show(
          context,
          message: 'Branch dengan ID $branchId tidak ditemukan.',
          type: TopNotificationType.error,
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
      TopNotification.show(
        context,
        message: error.message,
        type: TopNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;
      TopNotification.show(
        context,
        message: 'Gagal membuka branch dari hasil scan QR.',
        type: TopNotificationType.error,
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
      TopNotification.show(
        context,
        message: error.message,
        type: TopNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;
      TopNotification.show(
        context,
        message: 'Gagal membuka detail paket aktif.',
        type: TopNotificationType.error,
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
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -300 && _tabIndex == 0) {
                  setState(() => _tabIndex = 1);
                  _autoSlideTimer?.cancel();
                } else if (velocity > 300 && _tabIndex == 1) {
                  setState(() => _tabIndex = 0);
                  _resetAutoSlide();
                }
              },
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
    if (_isMembershipsLoading || _isTrainingPackagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_membershipErrorMessage != null &&
        _trainingPackageErrorMessage != null) {
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
                'Gagal mengambil paket aktif.\n'
                '$_membershipErrorMessage\n'
                '$_trainingPackageErrorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: inkColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _refreshActivePackages,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_memberships.isEmpty &&
        _trainingPackages.isEmpty &&
        _membershipErrorMessage == null &&
        _trainingPackageErrorMessage == null) {
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
      onRefresh: _refreshActivePackages,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          if (_membershipErrorMessage != null)
            _ActivePackageInlineError(
              message: _membershipErrorMessage!,
              onRetry: _loadMemberships,
              textColor: inkColor,
              mutedColor: muted,
            )
          else if (_memberships.length == 1)
            _buildMembershipCard(
              _memberships.first,
              isDark: isDark,
              surfaceColor: surfaceColor,
              surfaceSoft: surfaceSoft,
              inkColor: inkColor,
              borderColor: borderColor,
            )
          else if (_memberships.length > 1)
            SizedBox(
              height: 304,
              child: PageView.builder(
                key: widget.membershipCardKey,
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
          if (_memberships.isNotEmpty && _trainingPackages.isNotEmpty)
            const SizedBox(height: 24),
          if (_trainingPackageErrorMessage != null)
            _ActivePackageInlineError(
              message: _trainingPackageErrorMessage!,
              onRetry: _loadTrainingPackages,
              textColor: inkColor,
              mutedColor: muted,
            )
          else if (_trainingPackages.isNotEmpty) ...[
            _ActivePackageSectionHeader(
              title: 'Package Training Active',
              subtitle: '${_trainingPackages.length} paket training aktif',
              textColor: inkColor,
              mutedColor: muted,
            ),
            const SizedBox(height: 12),
            for (final package in _trainingPackages) ...[
              _buildTrainingPackageCard(
                package,
                isDark: isDark,
                inkColor: inkColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 14),
            ],
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
    final activeBadgeColor = const Color(0xFF24D978);
    final dayProgress = _buildMembershipDayProgress(membership);

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
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.38),
                              blurRadius: 14,
                              spreadRadius: -2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
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
                if (dayProgress != null) ...[
                  _MembershipDayProgressBar(
                    progress: dayProgress.progress,
                    statusLabel: dayProgress.statusLabel,
                    remainingLabel: dayProgress.remainingLabel,
                    textColor: textColor,
                    mutedText: mutedText,
                    progressColor: AppTheme.primary,
                    trackColor: textColor.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 18),
                ],
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

  _MembershipDayProgress? _buildMembershipDayProgress(
    MemberMembership membership,
  ) {
    final start = _parseMembershipDate(membership.startDate);
    final end = _parseMembershipDate(membership.expDate);
    if (start == null || end == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) {
      return const _MembershipDayProgress(
        progress: 1,
        statusLabel: 'Selesai',
        remainingLabel: 'Expired',
      );
    }

    if (today.isBefore(startDate)) {
      final daysUntilStart = startDate.difference(today).inDays;
      return _MembershipDayProgress(
        progress: 0,
        statusLabel: 'Menunggu',
        remainingLabel: 'Mulai dalam $daysUntilStart Hari',
      );
    }

    if (today.isAfter(endDate)) {
      return const _MembershipDayProgress(
        progress: 1,
        statusLabel: 'Selesai',
        remainingLabel: 'Expired',
      );
    }

    final elapsedDays = today.difference(startDate).inDays + 1;
    final remainingDays = endDate.difference(today).inDays + 1;
    final progress = (elapsedDays / totalDays).clamp(0.0, 1.0).toDouble();

    return _MembershipDayProgress(
      progress: progress,
      statusLabel: 'Berjalan: hari ke $elapsedDays dari $totalDays',
      remainingLabel: 'Sisa $remainingDays Hari',
    );
  }

  Widget _buildTrainingPackageCard(
    MemberTrainingPackage package, {
    required bool isDark,
    required Color inkColor,
    required Color borderColor,
  }) {
    final isActive = package.isActive;
    final textColor = isActive || isDark ? Colors.white : inkColor;
    final mutedText = isActive || isDark
        ? Colors.white.withValues(alpha: 0.62)
        : AppTheme.muted;
    final activeBadgeColor = const Color(0xFF24D978);
    final progress = package.totalSession <= 0
        ? 0.0
        : (package.remainingSessions / package.totalSession)
              .clamp(0.0, 1.0)
              .toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF26292F), Color(0xFF121418)],
              )
            : null,
        color: isActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? Colors.white.withValues(alpha: 0.06) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: isActive ? AppTheme.primary : AppTheme.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.packageName.trim().isEmpty
                          ? '-'
                          : package.packageName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      package.trainerName.trim().isEmpty
                          ? 'Trainer belum tersedia'
                          : package.trainerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.38),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TrainingSessionTile(
                  label: 'SISA SESI',
                  value: package.remainingSessions.toString(),
                  textColor: textColor,
                  mutedText: mutedText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrainingSessionTile(
                  label: 'TOTAL SESI',
                  value: package.totalSession.toString(),
                  textColor: textColor,
                  mutedText: mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: textColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
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
    final parsed = _parseMembershipDate(raw);
    if (parsed == null) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return '-';
      }
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

  DateTime? _parseMembershipDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(trimmed);
  }
}

class _MembershipDayProgress {
  final double progress;
  final String statusLabel;
  final String remainingLabel;

  const _MembershipDayProgress({
    required this.progress,
    required this.statusLabel,
    required this.remainingLabel,
  });
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

class _MembershipDayProgressBar extends StatelessWidget {
  final double progress;
  final String statusLabel;
  final String remainingLabel;
  final Color textColor;
  final Color mutedText;
  final Color progressColor;
  final Color trackColor;

  const _MembershipDayProgressBar({
    required this.progress,
    required this.statusLabel,
    required this.remainingLabel,
    required this.textColor,
    required this.mutedText,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              remainingLabel,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.88),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

class _ActivePackageSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color textColor;
  final Color mutedColor;

  const _ActivePackageSectionHeader({
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivePackageInlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color textColor;
  final Color mutedColor;

  const _ActivePackageInlineError({
    required this.message,
    required this.onRetry,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: mutedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: mutedColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class _TrainingSessionTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedText;

  const _TrainingSessionTile({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
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
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
  static const double _branchHeaderExpandedHeight = 248;

  final _membershipService = const MembershipService();
  final _sessionStorage = const SessionStorage();

  int _optionTabIndex = 0;
  bool _isLoading = true;
  bool _isTrainerPackagesLoading = true;
  String? _errorMessage;
  String? _trainerPackageErrorMessage;
  List<MemberMembershipOption> _options = const [];
  List<MemberTrainerPackageOption> _trainerPackages = const [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _loadTrainerPackages();
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

  Future<void> _loadTrainerPackages() async {
    setState(() {
      _isTrainerPackagesLoading = true;
      _trainerPackageErrorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _membershipService.fetchTrainerPackageOptions(
        branchId: widget.branch.id,
        token: session.token,
        tokenType: session.tokenType,
      );

      if (!mounted) return;
      setState(() {
        _trainerPackages = result;
        _isTrainerPackagesLoading = false;
      });
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _trainerPackageErrorMessage = error.message;
        _isTrainerPackagesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trainerPackageErrorMessage = 'Gagal mengambil daftar paket trainer.';
        _isTrainerPackagesLoading = false;
      });
    }
  }

  Future<void> _refreshBranchPackages() async {
    await Future.wait([_loadOptions(), _loadTrainerPackages()]);
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

  Widget _buildPackageTypeTabs({
    required Color surfaceColor,
    required Color inkSoft,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 5) / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _optionTabIndex == 0 ? 0 : tabWidth + 5,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPackageTypeTabButton(
                      label: 'Paket',
                      isActive: _optionTabIndex == 0,
                      inactiveColor: inkSoft,
                      onTap: () => setState(() => _optionTabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _buildPackageTypeTabButton(
                      label: 'Trainer',
                      isActive: _optionTabIndex == 1,
                      inactiveColor: inkSoft,
                      onTap: () => setState(() => _optionTabIndex = 1),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPackageTypeTabButton({
    required String label,
    required bool isActive,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: isActive ? Colors.white : inactiveColor,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  List<Widget> _buildSelectedPackageChildren({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    if (_optionTabIndex == 1) {
      return _buildTrainerPackageChildren(
        isDark: isDark,
        surfaceColor: surfaceColor,
        inkColor: inkColor,
        inkSoft: inkSoft,
        muted: muted,
      );
    }

    return _buildMembershipOptionChildren(
      isDark: isDark,
      surfaceColor: surfaceColor,
      surfaceSoft: surfaceSoft,
      inkColor: inkColor,
      inkSoft: inkSoft,
      muted: muted,
      borderColor: borderColor,
    );
  }

  List<Widget> _buildMembershipOptionChildren({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        _BranchPackageErrorCard(
          title: 'Detail paket belum bisa dimuat',
          message: _errorMessage!,
          surfaceColor: surfaceColor,
          muted: muted,
          onRetry: _loadOptions,
        ),
      ];
    }

    if (_options.isEmpty) {
      return [
        _BranchPackageEmptyCard(
          message: 'Belum ada paket tersedia di cabang ini.',
          surfaceColor: surfaceColor,
          muted: muted,
        ),
      ];
    }

    return _options
        .map(
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
        )
        .toList();
  }

  List<Widget> _buildTrainerPackageChildren({
    required bool isDark,
    required Color surfaceColor,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
  }) {
    if (_isTrainerPackagesLoading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_trainerPackageErrorMessage != null) {
      return [
        _BranchPackageErrorCard(
          title: 'Paket trainer belum bisa dimuat',
          message: _trainerPackageErrorMessage!,
          surfaceColor: surfaceColor,
          muted: muted,
          onRetry: _loadTrainerPackages,
        ),
      ];
    }

    if (_trainerPackages.isEmpty) {
      return [
        _BranchPackageEmptyCard(
          message: 'Belum ada paket trainer tersedia di cabang ini.',
          surfaceColor: surfaceColor,
          muted: muted,
        ),
      ];
    }

    return _trainerPackages
        .map(
          (package) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TrainerPackageOptionCard(
              package: package,
              isDark: isDark,
              surfaceColor: surfaceColor,
              inkColor: inkColor,
              inkSoft: inkSoft,
              muted: muted,
            ),
          ),
        )
        .toList();
  }

  Widget _buildBranchHeader({
    required BuildContext context,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    final branchAddress = widget.branch.address.trim().isEmpty
        ? 'Alamat cabang belum tersedia.'
        : widget.branch.address;
    final branchCode = widget.branch.branchCode.trim().isEmpty
        ? 'Kode branch belum tersedia'
        : widget.branch.branchCode;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      iconTheme: IconThemeData(color: inkColor),
      expandedHeight: _branchHeaderExpandedHeight,
      toolbarHeight: kToolbarHeight,
      titleSpacing: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final currentHeight = constraints.biggest.height;
          final expandedProgress =
              ((currentHeight - topInset - kToolbarHeight) /
                      (_branchHeaderExpandedHeight - kToolbarHeight))
                  .clamp(0.0, 1.0);
          final collapseProgress = 1 - expandedProgress;
          final headerColor = Color.lerp(
            backgroundColor,
            surfaceColor,
            Curves.easeOut.transform(collapseProgress),
          )!;

          final cardHorizontalInset = lerpDouble(20, 0, collapseProgress)!;
          final cardTop = lerpDouble(topInset + 60, 0, collapseProgress)!;
          final cardBottom = lerpDouble(18, 0, collapseProgress)!;
          final cardRadius = lerpDouble(24, 0, collapseProgress)!;
          final cardShadowOpacity = (1 - (collapseProgress * 1.2)).clamp(
            0.0,
            1.0,
          );

          final logoSize = lerpDouble(58, 34, collapseProgress)!;
          final logoLeft = lerpDouble(38, 62, collapseProgress)!;
          final logoTop = lerpDouble(
            cardTop + 18,
            topInset + 11,
            collapseProgress,
          )!;
          final logoRadius = lerpDouble(18, 12, collapseProgress)!;
          final titleLeft =
              logoLeft + logoSize + lerpDouble(14, 12, collapseProgress)!;
          final titleTop = lerpDouble(
            cardTop + 20,
            topInset + 15,
            collapseProgress,
          )!;
          final titleFontSize = lerpDouble(19.5, 17.5, collapseProgress)!;
          final addressOpacity = (1 - (collapseProgress * 1.7)).clamp(0.0, 1.0);
          final codeOpacity = (1 - (collapseProgress * 2.1)).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: headerColor),
              Positioned(
                left: cardHorizontalInset,
                right: cardHorizontalInset,
                top: cardTop,
                bottom: cardBottom,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(cardRadius),
                    boxShadow:
                        cardShadowOpacity == 0 ||
                            Theme.of(context).brightness == Brightness.dark
                        ? const []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.06 * cardShadowOpacity,
                              ),
                              blurRadius: 20,
                              spreadRadius: -3,
                              offset: const Offset(0, 12),
                            ),
                          ],
                  ),
                ),
              ),
              Positioned(
                left: logoLeft,
                top: logoTop,
                child: Container(
                  height: logoSize,
                  width: logoSize,
                  padding: EdgeInsets.all(lerpDouble(6, 4, collapseProgress)!),
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    borderRadius: BorderRadius.circular(logoRadius),
                  ),
                  child: AppLogo(
                    size: lerpDouble(46, 28, collapseProgress)!,
                    variant: AppLogoVariant.iconOnly,
                  ),
                ),
              ),
              Positioned(
                left: titleLeft,
                right: 22,
                top: titleTop,
                child: Text(
                  widget.branch.name,
                  maxLines: collapseProgress > 0.55 ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              Positioned(
                left: titleLeft,
                right: 24,
                top: titleTop + lerpDouble(34, 26, collapseProgress)!,
                child: Opacity(
                  opacity: addressOpacity,
                  child: Transform.translate(
                    offset: Offset(0, 8 * collapseProgress),
                    child: Text(
                      branchAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: titleLeft,
                right: 24,
                top: titleTop + lerpDouble(84, 42, collapseProgress)!,
                child: Opacity(
                  opacity: codeOpacity,
                  child: Text(
                    branchCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: inkSoft,
                      fontWeight: FontWeight.w700,
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
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -300 && _optionTabIndex == 0) {
            setState(() => _optionTabIndex = 1);
          } else if (velocity > 300 && _optionTabIndex == 1) {
            setState(() => _optionTabIndex = 0);
          }
        },
        child: RefreshIndicator(
          onRefresh: _refreshBranchPackages,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildBranchHeader(
                context: context,
                backgroundColor: backgroundColor,
                surfaceColor: surfaceColor,
                surfaceSoft: surfaceSoft,
                inkColor: inkColor,
                inkSoft: inkSoft,
                muted: muted,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildPackageTypeTabs(
                      surfaceColor: surfaceColor,
                      inkSoft: inkSoft,
                    ),
                    const SizedBox(height: 16),
                    ..._buildSelectedPackageChildren(
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      surfaceSoft: surfaceSoft,
                      inkColor: inkColor,
                      inkSoft: inkSoft,
                      muted: muted,
                      borderColor: borderColor,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchPackageErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final Color surfaceColor;
  final Color muted;
  final VoidCallback onRetry;

  const _BranchPackageErrorCard({
    required this.title,
    required this.message,
    required this.surfaceColor,
    required this.muted,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: muted, height: 1.45)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class _BranchPackageEmptyCard extends StatelessWidget {
  final String message;
  final Color surfaceColor;
  final Color muted;

  const _BranchPackageEmptyCard({
    required this.message,
    required this.surfaceColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TrainerPackageOptionCard extends StatelessWidget {
  final MemberTrainerPackageOption package;
  final bool isDark;
  final Color surfaceColor;
  final Color inkColor;
  final Color inkSoft;
  final Color muted;

  const _TrainerPackageOptionCard({
    required this.package,
    required this.isDark,
    required this.surfaceColor,
    required this.inkColor,
    required this.inkSoft,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBackground = isDark
        ? const Color(0xFF262A31)
        : const Color(0xFFF0F3F8);
    final actionBackground = isDark
        ? AppTheme.primary.withValues(alpha: 0.14)
        : const Color(0xFFFFECEC);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF23252B), Color(0xFF1A1C21)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FB)],
              ),
        borderRadius: BorderRadius.circular(20),
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
                  package.durationDays > 0
                      ? '${package.durationDays} Hari'
                      : 'Trainer',
                  style: TextStyle(
                    color: inkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (package.isActive) ...[
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
                    'AKTIF',
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
            package.name.trim().isEmpty ? '-' : package.name,
            style: TextStyle(
              color: inkColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (package.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              package.description,
              style: TextStyle(
                color: muted,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _formatCurrency(package.price),
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _OptionFeatureRow(
            icon: Icons.fitness_center_rounded,
            text: 'Total sesi ${package.totalSession} kali',
            color: inkSoft,
          ),
          _OptionFeatureRow(
            icon: Icons.calendar_month_rounded,
            text: 'Durasi aktif ${package.durationDays} hari',
            color: inkSoft,
          ),
          if (package.isActive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  TopNotification.show(
                    context,
                    message: 'Pembelian paket trainer belum tersedia.',
                    type: TopNotificationType.info,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionBackground,
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Text('Beli Trainer'),
              ),
            ),
          ],
        ],
      ),
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
    final confirmed = await showModernModalDialog(
      context: context,
      title: 'Beli paket ini?',
      content:
          '${option.name}\n${_formatCurrency(option.price)} • ${option.durationDays} hari',
      primaryButtonText: 'Beli',
      icon: Icons.shopping_bag_rounded,
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
      TopNotification.show(
        context,
        message: 'Data pembelian membership belum lengkap.',
        type: TopNotificationType.error,
      );
      return;
    }

    final confirmed = await showModernModalDialog(
      context: context,
      title: 'Konfirmasi Pembelian',
      content:
          'Lanjut beli paket ${detail.name} seharga ${_formatCurrency(detail.price)}?',
      primaryButtonText: 'Beli',
      icon: Icons.shopping_bag_rounded,
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
      await _showPurchaseFailureDialog('Gagal memproses pembelian membership.');
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
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
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
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: isActive ? 1.05 : 1,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                turns: isActive ? -0.08 : 0,
                child: const SizedBox.square(
                  dimension: 20,
                  child: Center(
                    child: Icon(Icons.arrow_forward_rounded, size: 20),
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
