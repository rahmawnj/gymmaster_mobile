import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/auth_session.dart';
import '../models/face_enrollment_result.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_modal_dialog.dart';
import '../widgets/top_notification.dart';
import 'auth_screen.dart';
import 'display_settings_screen.dart';
import 'face_enrollment_screen.dart';

Widget _buildProfileImage({
  required String imageUrl,
  required Widget fallback,
  BoxFit fit = BoxFit.cover,
  String? cacheBuster,
  Key? widgetKey,
}) {
  final normalizedUrl = _resolveProfileImageUrl(
    imageUrl: imageUrl,
    cacheBuster: cacheBuster,
  );
  if (normalizedUrl.isEmpty) {
    return fallback;
  }

  return Image.network(
    key: widgetKey,
    normalizedUrl,
    fit: fit,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    webHtmlElementStrategy: kIsWeb
        ? WebHtmlElementStrategy.prefer
        : WebHtmlElementStrategy.never,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}

String _resolveProfileImageUrl({
  required String imageUrl,
  String? cacheBuster,
}) {
  final normalizedUrl = imageUrl.trim();
  final normalizedCacheBuster = cacheBuster?.trim() ?? '';
  if (normalizedUrl.isEmpty || normalizedCacheBuster.isEmpty) {
    return normalizedUrl;
  }

  final uri = Uri.tryParse(normalizedUrl);
  if (uri == null) {
    return normalizedUrl;
  }

  final queryParameters = Map<String, String>.from(uri.queryParameters);
  queryParameters['v'] = normalizedCacheBuster;
  return uri.replace(queryParameters: queryParameters).toString();
}

String _nextProfileImageRevision() =>
    DateTime.now().microsecondsSinceEpoch.toString();

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }

  return '';
}

User _mergeProfileUserData({
  required User baseUser,
  User? mobileProfile,
  User? updatedProfile,
  User? enrichedProfile,
}) {
  final status = _firstNonEmpty([
    mobileProfile?.status,
    updatedProfile?.status,
    enrichedProfile?.status,
    baseUser.status,
  ]);
  final statusOwnerIsActive = mobileProfile?.status.trim().isNotEmpty == true
      ? mobileProfile!.isActive
      : updatedProfile?.status.trim().isNotEmpty == true
      ? updatedProfile!.isActive
      : enrichedProfile?.status.trim().isNotEmpty == true
      ? enrichedProfile!.isActive
      : baseUser.isActive;

  return baseUser.copyWith(
    id: _firstNonEmpty([
      mobileProfile?.id,
      updatedProfile?.id,
      enrichedProfile?.id,
      baseUser.id,
    ]),
    userId: _firstNonEmpty([
      mobileProfile?.userId,
      updatedProfile?.userId,
      enrichedProfile?.userId,
      baseUser.userId,
    ]),
    name: _firstNonEmpty([
      mobileProfile?.name,
      updatedProfile?.name,
      enrichedProfile?.name,
      baseUser.name,
    ]),
    memberCode: _firstNonEmpty([
      mobileProfile?.memberCode,
      updatedProfile?.memberCode,
      enrichedProfile?.memberCode,
      baseUser.memberCode,
    ]),
    email: _firstNonEmpty([
      enrichedProfile?.email,
      mobileProfile?.email,
      updatedProfile?.email,
      baseUser.email,
    ]),
    phone: _firstNonEmpty([
      mobileProfile?.phone,
      updatedProfile?.phone,
      enrichedProfile?.phone,
      baseUser.phone,
    ]),
    address: _firstNonEmpty([
      mobileProfile?.address,
      updatedProfile?.address,
      enrichedProfile?.address,
      baseUser.address,
    ]),
    provinceId: _firstNonEmpty([
      enrichedProfile?.provinceId,
      mobileProfile?.provinceId,
      updatedProfile?.provinceId,
      baseUser.provinceId,
    ]),
    cityId: _firstNonEmpty([
      enrichedProfile?.cityId,
      mobileProfile?.cityId,
      updatedProfile?.cityId,
      baseUser.cityId,
    ]),
    districtId: _firstNonEmpty([
      enrichedProfile?.districtId,
      mobileProfile?.districtId,
      updatedProfile?.districtId,
      baseUser.districtId,
    ]),
    subDistrictId: _firstNonEmpty([
      enrichedProfile?.subDistrictId,
      mobileProfile?.subDistrictId,
      updatedProfile?.subDistrictId,
      baseUser.subDistrictId,
    ]),
    postCode: _firstNonEmpty([
      enrichedProfile?.postCode,
      mobileProfile?.postCode,
      updatedProfile?.postCode,
      baseUser.postCode,
    ]),
    status: status,
    isActive: status.trim().isNotEmpty
        ? statusOwnerIsActive
        : baseUser.isActive,
    imageUrl: _firstNonEmpty([
      mobileProfile?.imageUrl,
      updatedProfile?.imageUrl,
      enrichedProfile?.imageUrl,
      baseUser.imageUrl,
    ]),
    createdAt: _firstNonEmpty([
      mobileProfile?.createdAt,
      updatedProfile?.createdAt,
      enrichedProfile?.createdAt,
      baseUser.createdAt,
    ]),
  );
}

class ProfileSettingsScreen extends StatefulWidget {
  final User initialUser;
  final bool isActive;
  final bool popOnUpdate;
  final ValueChanged<User>? onUserUpdated;
  final VoidCallback? onBackRequested;

  const ProfileSettingsScreen({
    super.key,
    required this.initialUser,
    this.isActive = false,
    this.popOnUpdate = true,
    this.onUserUpdated,
    this.onBackRequested,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _sessionStorage = const SessionStorage();
  final _authService = const AuthService();
  late User _user;
  late String _profileImageRevision;
  FaceEnrollmentResult? _faceEnrollmentResult;
  bool _isRefreshingProfile = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _profileImageRevision = _nextProfileImageRevision();
    _refreshProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshProfile();
      });
    }
    if (oldWidget.initialUser.id != widget.initialUser.id ||
        oldWidget.initialUser.userId != widget.initialUser.userId ||
        oldWidget.initialUser.memberCode != widget.initialUser.memberCode ||
        oldWidget.initialUser.name != widget.initialUser.name ||
        oldWidget.initialUser.phone != widget.initialUser.phone ||
        oldWidget.initialUser.address != widget.initialUser.address ||
        oldWidget.initialUser.status != widget.initialUser.status ||
        oldWidget.initialUser.imageUrl != widget.initialUser.imageUrl) {
      setState(() {
        _user = widget.initialUser;
        _profileImageRevision = _nextProfileImageRevision();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshProfile();
      });
    }
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshingProfile) {
      return;
    }

    setState(() {
      _isRefreshingProfile = true;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        return;
      }

      var activeMemberId = session.user.memberId.trim().isNotEmpty
          ? session.user.memberId.trim()
          : _user.memberId.trim();
      User? enrichedProfile;

      final shouldResolveMemberId =
          session.user.accountUserId.trim().isNotEmpty &&
          session.user.accountUserId.trim() == activeMemberId;

      if (shouldResolveMemberId) {
        try {
          enrichedProfile = await _authService.fetchMemberProfile(
            userId: session.user.accountUserId,
            token: session.token,
            tokenType: session.tokenType,
          );
          if (enrichedProfile.id.trim().isNotEmpty) {
            activeMemberId = enrichedProfile.id.trim();
          }
        } catch (_) {
          // Keep the stored id if resolving member id fails.
        }
      }

      if (activeMemberId.isEmpty) {
        return;
      }

      User refreshedUser;
      try {
        refreshedUser = await _authService.fetchMemberMobileProfile(
          memberId: activeMemberId,
          token: session.token,
          tokenType: session.tokenType,
        );
      } on AuthException catch (error) {
        if (error.message.toLowerCase().contains('record not found') &&
            session.user.accountUserId.trim().isNotEmpty) {
          final resolvedMember = await _authService.fetchMemberProfile(
            userId: session.user.accountUserId,
            token: session.token,
            tokenType: session.tokenType,
          );
          enrichedProfile = resolvedMember;

          refreshedUser = await _authService.fetchMemberMobileProfile(
            memberId: resolvedMember.id,
            token: session.token,
            tokenType: session.tokenType,
          );
        } else {
          rethrow;
        }
      }

      final shouldFetchEnrichedProfile =
          session.user.accountUserId.trim().isNotEmpty &&
          (refreshedUser.email.trim().isEmpty ||
              refreshedUser.provinceId.trim().isEmpty ||
              refreshedUser.cityId.trim().isEmpty ||
              refreshedUser.districtId.trim().isEmpty ||
              refreshedUser.subDistrictId.trim().isEmpty ||
              refreshedUser.postCode.trim().isEmpty);

      if (shouldFetchEnrichedProfile && enrichedProfile == null) {
        try {
          enrichedProfile = await _authService.fetchMemberProfile(
            userId: session.user.accountUserId,
            token: session.token,
            tokenType: session.tokenType,
          );
        } catch (_) {
          // Keep using mobile profile response if the web profile cannot be loaded.
        }
      }

      final baseUser = session.user;
      final mergedUser = _mergeProfileUser(
        baseUser: baseUser,
        mobileProfile: refreshedUser,
        enrichedProfile: enrichedProfile,
      );

      await _sessionStorage.updateStoredUser(mergedUser);
      if (!mounted) {
        return;
      }

      setState(() {
        _user = mergedUser;
        _profileImageRevision = _nextProfileImageRevision();
      });
      widget.onUserUpdated?.call(mergedUser);
    } catch (_) {
      // Keep the last local profile data if refresh fails.
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingProfile = false;
        });
      }
    }
  }

  User _mergeProfileUser({
    required User baseUser,
    required User mobileProfile,
    User? enrichedProfile,
  }) {
    return _mergeProfileUserData(
      baseUser: baseUser,
      mobileProfile: mobileProfile,
      enrichedProfile: enrichedProfile,
    );
  }

  Future<void> _openEditProfileSheet() async {
    final updatedUser = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.52,
        maxChildSize: 0.94,
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => _EditProfileSheet(
          initialUser: _user,
          scrollController: scrollController,
        ),
      ),
    );

    if (!mounted || updatedUser == null) {
      return;
    }

    setState(() {
      _user = updatedUser;
      _profileImageRevision = _nextProfileImageRevision();
    });
    widget.onUserUpdated?.call(updatedUser);
    if (widget.popOnUpdate) {
      Navigator.of(context).pop(updatedUser);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showModernModalDialog(
      context: context,
      title: 'Keluar akun',
      content: 'Yakin mau keluar dari akun ini sekarang?',
      primaryButtonText: 'Keluar',
      icon: Icons.logout_rounded,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _sessionStorage.clearSession();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
      (route) => false,
    );
  }

  Future<void> _openDeleteAccountSheet() async {
    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _DeleteAccountSheet(),
    );

    if (!mounted || selectedReason == null) {
      return;
    }

    TopNotification.show(
      context,
      message:
          'Alasan hapus akun sudah dipilih. Fitur hapus akun akan segera tersedia.',
      type: TopNotificationType.info,
    );
  }

  Future<void> _openFaceEnrollment() async {
    final result = await Navigator.of(context).push<FaceEnrollmentResult>(
      MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _faceEnrollmentResult = result;
    });

    TopNotification.show(
      context,
      message: 'Foto verifikasi final sudah tersimpan lokal.',
      type: TopNotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 120),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildHeroCard(),
              ),
              const SizedBox(height: 12),
              _buildProfileMenuList(),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Keluar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    const heroTextColor = Color(0xFF111111);
    const heroSubTextColor = Color(0xFF333333);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openEditProfileSheet,
        onLongPress: () {
          HapticFeedback.heavyImpact();
          Clipboard.setData(ClipboardData(text: _user.memberCode));
          TopNotification.show(
            context,
            message: 'Kode Member ${_user.memberCode} disalin!',
            type: TopNotificationType.success,
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFAFEDE8), Color(0xFFBFEFE6), Color(0xFF8BE6D7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -18,
                right: -8,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Positioned(
                bottom: -28,
                right: 24,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 10,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(
                        imageUrl: _user.imageUrl,
                        cacheBuster: _profileImageRevision,
                        widgetKey: ValueKey(
                          '${_user.imageUrl}|$_profileImageRevision',
                        ),
                        fallback: Image.asset(
                          'assets/images/logo/logo-icon-black-red.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user.name.trim().isEmpty
                              ? 'Member Gymmaster'
                              : _user.name,
                          style: TextStyle(
                            color: heroTextColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user.memberCode,
                          style: TextStyle(
                            color: heroSubTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: heroTextColor,
                    size: 30,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuList() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final dividerColor = onSurfaceVariant.withValues(alpha: 0.18);

    return Column(
      children: [
        _MenuRowTile(
          icon: Icons.face_retouching_natural_rounded,
          title: 'Selfie verifikasi',
          subtitle:
              'Liveness on-device dengan step tengah, sisi, sisi balik, lalu senyum.',
          onTap: _openFaceEnrollment,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: dividerColor, height: 1),
        ),
        _MenuRowTile(
          icon: Icons.tune_rounded,
          title: 'Tampilan',
          subtitle: 'Atur mode gelap dan tema aplikasi.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DisplaySettingsScreen()),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: dividerColor, height: 1),
        ),
        _MenuRowTile(
          icon: Icons.delete_forever_rounded,
          title: 'Hapus akun',
          subtitle: 'Pilih alasan sebelum mengajukan penghapusan akun.',
          foregroundColor: Colors.red.shade600,
          onTap: _openDeleteAccountSheet,
        ),
        if (_faceEnrollmentResult != null) ...[
          const SizedBox(height: 24),
          _buildFacePreviewCard(_faceEnrollmentResult!),
        ],
      ],
    );
  }

  Widget _buildFacePreviewCard(FaceEnrollmentResult result) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foto final terakhir',
            style: TextStyle(
              color: onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.memory(result.imageBytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Blur ${result.blurScore.toStringAsFixed(0)} - Brightness ${result.brightnessScore.toStringAsFixed(0)}',
            style: TextStyle(
              color: onSurfaceVariant.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  static const _otherReason = 'Lainnya';
  static const _reasons = [
    'Sudah tidak menggunakan aplikasi',
    'Pindah ke gym lain',
    'Punya akun lain',
    'Khawatir soal privasi data',
    _otherReason,
  ];

  final _otherReasonController = TextEditingController();
  String? _selectedReason;
  bool _showOtherReasonError = false;

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final selectedReason = _selectedReason;
    if (selectedReason == null) {
      return;
    }

    final reason = selectedReason == _otherReason
        ? _otherReasonController.text.trim()
        : selectedReason;

    if (selectedReason == _otherReason && reason.isEmpty) {
      setState(() {
        _showOtherReasonError = true;
      });
      return;
    }

    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSubmit =
        _selectedReason != null &&
        (_selectedReason != _otherReason ||
            _otherReasonController.text.trim().isNotEmpty);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red.shade600,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hapus akun',
                            style: TextStyle(
                              color: onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pilih alasan kenapa kamu ingin menghapus akun.',
                            style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: onSurface.withValues(alpha: 0.06),
                        foregroundColor: onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ..._reasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedReason = reason;
                          _showOtherReasonError = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.withValues(alpha: 0.08)
                              : scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.45,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.red.shade500
                                : onSurfaceVariant.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? Colors.red.shade600
                                  : onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  color: onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _selectedReason == _otherReason
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 18),
                          child: TextField(
                            controller: _otherReasonController,
                            minLines: 3,
                            maxLines: 4,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_showOtherReasonError) {
                                setState(() {
                                  _showOtherReasonError = false;
                                });
                              } else {
                                setState(() {});
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Tulis alasan lainnya',
                              alignLabelWithHint: true,
                              errorText: _showOtherReasonError
                                  ? 'Alasan lainnya wajib diisi'
                                  : null,
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 48),
                                child: Icon(Icons.edit_note_rounded),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(height: 8),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: onSurfaceVariant.withValues(
                        alpha: 0.18,
                      ),
                      disabledForegroundColor: onSurfaceVariant.withValues(
                        alpha: 0.52,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Hapus akun',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
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

class _EditProfileSheet extends StatefulWidget {
  final User initialUser;
  final ScrollController scrollController;

  const _EditProfileSheet({
    required this.initialUser,
    required this.scrollController,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _authService = const AuthService();
  final _sessionStorage = const SessionStorage();
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  bool _isSaving = false;
  Uint8List? _selectedProfileBytes;
  String? _selectedProfileName;
  int _selectedProfilePreviewVersion = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUser.name);
    _phoneController = TextEditingController(text: widget.initialUser.phone);
    _addressController = TextEditingController(
      text: widget.initialUser.address,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<User> _refreshProfileAfterUpdate({
    required AuthSession session,
    required User updateResponseUser,
  }) async {
    final baseUser = _mergeProfileUserData(
      baseUser: session.user,
      updatedProfile: widget.initialUser,
    );
    final patchedUser = _mergeProfileUserData(
      baseUser: baseUser,
      updatedProfile: updateResponseUser,
    );

    var accountUserId = _firstNonEmpty([
      patchedUser.accountUserId,
      widget.initialUser.accountUserId,
      session.user.accountUserId,
    ]);
    var activeMemberId = _firstNonEmpty([
      patchedUser.memberId,
      widget.initialUser.memberId,
      session.user.memberId,
    ]);

    User? enrichedProfile;
    User? refreshedUser;

    if (accountUserId.isNotEmpty && activeMemberId == accountUserId) {
      try {
        enrichedProfile = await _authService.fetchMemberProfile(
          userId: accountUserId,
          token: session.token,
          tokenType: session.tokenType,
        );
        if (enrichedProfile.id.trim().isNotEmpty) {
          activeMemberId = enrichedProfile.id.trim();
        }
      } catch (_) {
        // Keep using the best local member id if resolving fails.
      }
    }

    if (activeMemberId.isNotEmpty) {
      try {
        refreshedUser = await _authService.fetchMemberMobileProfile(
          memberId: activeMemberId,
          token: session.token,
          tokenType: session.tokenType,
        );
      } on AuthException catch (error) {
        final canResolveFromUserId =
            error.message.toLowerCase().contains('record not found') &&
            accountUserId.isNotEmpty;
        if (canResolveFromUserId) {
          try {
            final resolvedProfile =
                enrichedProfile ??
                await _authService.fetchMemberProfile(
                  userId: accountUserId,
                  token: session.token,
                  tokenType: session.tokenType,
                );
            enrichedProfile = resolvedProfile;
            if (resolvedProfile.id.trim().isNotEmpty) {
              refreshedUser = await _authService.fetchMemberMobileProfile(
                memberId: resolvedProfile.id,
                token: session.token,
                tokenType: session.tokenType,
              );
            }
          } catch (_) {
            // Fall back to the merged update response if refresh is unavailable.
          }
        }
      } catch (_) {
        // Fall back to the merged update response if refresh is unavailable.
      }
    }

    final shouldFetchEnrichedProfile =
        accountUserId.isNotEmpty &&
        enrichedProfile == null &&
        (refreshedUser == null ||
            refreshedUser.email.trim().isEmpty ||
            refreshedUser.provinceId.trim().isEmpty ||
            refreshedUser.cityId.trim().isEmpty ||
            refreshedUser.districtId.trim().isEmpty ||
            refreshedUser.subDistrictId.trim().isEmpty ||
            refreshedUser.postCode.trim().isEmpty);

    if (shouldFetchEnrichedProfile) {
      try {
        enrichedProfile = await _authService.fetchMemberProfile(
          userId: accountUserId,
          token: session.token,
          tokenType: session.tokenType,
        );
      } catch (_) {
        // Mobile profile plus local data is enough to prevent empty fields.
      }
    }

    return _mergeProfileUserData(
      baseUser: patchedUser,
      mobileProfile: refreshedUser,
      enrichedProfile: enrichedProfile,
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const AuthException(
          'Sesi login tidak ditemukan. Silakan login ulang.',
        );
      }

      final updateResponseUser = await _authService.updateMemberProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        token: session.token,
        tokenType: session.tokenType,
        imageBytes: _selectedProfileBytes,
        imageFileName: _selectedProfileName,
      );
      final updatedUser = await _refreshProfileAfterUpdate(
        session: session,
        updateResponseUser: updateResponseUser,
      );

      await _sessionStorage.updateStoredUser(updatedUser);
      if (!mounted) {
        return;
      }

      TopNotification.show(
        context,
        message: 'Profil berhasil diperbarui.',
        type: TopNotificationType.success,
      );
      Navigator.of(context).pop(updatedUser);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      TopNotification.show(
        context,
        message: error.message,
        type: TopNotificationType.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      TopNotification.show(
        context,
        message: 'Gagal menyimpan perubahan profil ke server.',
        type: TopNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: kIsWeb ? null : 90,
      );
      if (!mounted || file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProfileBytes = bytes;
        _selectedProfileName = file.name;
        _selectedProfilePreviewVersion++;
      });
    } catch (error, stackTrace) {
      debugPrint('===== PROFILE PICK IMAGE ERROR START =====');
      debugPrint('Error: $error');
      debugPrint('$stackTrace');
      debugPrint('===== PROFILE PICK IMAGE ERROR END =====');
      if (!mounted) {
        return;
      }
      TopNotification.show(
        context,
        message: 'Gagal mengambil file. Coba lagi.',
        type: TopNotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 22),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit akun',
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: onSurface.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: onSurface,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildProfilePhotoPicker(),
                        const SizedBox(height: 18),
                        _buildReadOnlyCard(),
                        const SizedBox(height: 18),
                        _buildField(
                          controller: _nameController,
                          label: 'Nama lengkap',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _phoneController,
                          label: 'Nomor telepon',
                          icon: Icons.phone_outlined,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _addressController,
                          label: 'Alamat',
                          icon: Icons.home_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleSave,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Simpan perubahan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data akun',
            style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            widget.initialUser.email,
            style: TextStyle(
              color: onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.initialUser.memberCode,
            style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhotoPicker() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final initials = _nameController.text.trim().isEmpty
        ? 'GM'
        : _nameController.text
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part.substring(0, 1).toUpperCase())
              .join();
    final profileImageUrl = widget.initialUser.imageUrl.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: onSurfaceVariant.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.14),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.24),
              ),
            ),
            child: ClipOval(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: _selectedProfileBytes != null
                    ? Image.memory(
                        _selectedProfileBytes!,
                        key: ValueKey('picked-$_selectedProfilePreviewVersion'),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : profileImageUrl.isNotEmpty
                    ? _buildProfileImage(
                        imageUrl: profileImageUrl,
                        widgetKey: ValueKey('initial-$profileImageUrl'),
                        fallback: Center(
                          child: Text(
                            initials.isEmpty ? 'GM' : initials,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        key: const ValueKey('fallback-initials'),
                        child: Text(
                          initials.isEmpty ? 'GM' : initials,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto profil',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedProfileName ??
                      'Pilih foto dari galeri untuk preview profil.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickProfileImage,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text(
                      'Pilih file',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label wajib diisi';
        }
        return null;
      },
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _MenuRowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? foregroundColor;

  const _MenuRowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final tileRadius = BorderRadius.zero;
    final accentColor = foregroundColor ?? scheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: tileRadius,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: isDark ? 0.10 : 0.06);
          }
          return null;
        }),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: tileRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  color: onSurfaceVariant.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
