import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/face_enrollment_result.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'display_settings_screen.dart';
import 'face_enrollment_screen.dart';
import 'security_settings_screen.dart';

Widget _buildProfileImage({
  required String imageUrl,
  required Widget fallback,
  BoxFit fit = BoxFit.cover,
}) {
  final normalizedUrl = imageUrl.trim();
  if (normalizedUrl.isEmpty) {
    return fallback;
  }

  return Image.network(
    normalizedUrl,
    fit: fit,
    filterQuality: FilterQuality.medium,
    webHtmlElementStrategy: kIsWeb
        ? WebHtmlElementStrategy.prefer
        : WebHtmlElementStrategy.never,
    errorBuilder: (_, __, ___) => fallback,
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
  FaceEnrollmentResult? _faceEnrollmentResult;
  bool _isRefreshingProfile = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
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
        oldWidget.initialUser.status != widget.initialUser.status) {
      setState(() {
        _user = widget.initialUser;
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
    return baseUser.copyWith(
      id: mobileProfile.id.isNotEmpty
          ? mobileProfile.id
          : (enrichedProfile?.id.isNotEmpty == true
              ? enrichedProfile!.id
              : baseUser.id),
      userId: mobileProfile.userId.isNotEmpty
          ? mobileProfile.userId
          : (enrichedProfile?.userId.isNotEmpty == true
              ? enrichedProfile!.userId
              : baseUser.userId),
      // Profile screen should follow GET /members/profile/{memberId}.
      name: mobileProfile.name.isNotEmpty
          ? mobileProfile.name
          : (enrichedProfile?.name.isNotEmpty == true
              ? enrichedProfile!.name
              : baseUser.name),
      memberCode: mobileProfile.memberCode.isNotEmpty
          ? mobileProfile.memberCode
          : (enrichedProfile?.memberCode.isNotEmpty == true
              ? enrichedProfile!.memberCode
              : baseUser.memberCode),
      email: enrichedProfile?.email.isNotEmpty == true
          ? enrichedProfile!.email
          : (mobileProfile.email.isNotEmpty
              ? mobileProfile.email
              : baseUser.email),
      phone: mobileProfile.phone.isNotEmpty
          ? mobileProfile.phone
          : (enrichedProfile?.phone.isNotEmpty == true
              ? enrichedProfile!.phone
              : baseUser.phone),
      address: mobileProfile.address.isNotEmpty
          ? mobileProfile.address
          : (enrichedProfile?.address.isNotEmpty == true
              ? enrichedProfile!.address
              : baseUser.address),
      provinceId: enrichedProfile?.provinceId.isNotEmpty == true
          ? enrichedProfile!.provinceId
          : (mobileProfile.provinceId.isNotEmpty
              ? mobileProfile.provinceId
              : baseUser.provinceId),
      cityId: enrichedProfile?.cityId.isNotEmpty == true
          ? enrichedProfile!.cityId
          : (mobileProfile.cityId.isNotEmpty
              ? mobileProfile.cityId
              : baseUser.cityId),
      districtId: enrichedProfile?.districtId.isNotEmpty == true
          ? enrichedProfile!.districtId
          : (mobileProfile.districtId.isNotEmpty
              ? mobileProfile.districtId
              : baseUser.districtId),
      subDistrictId: enrichedProfile?.subDistrictId.isNotEmpty == true
          ? enrichedProfile!.subDistrictId
          : (mobileProfile.subDistrictId.isNotEmpty
              ? mobileProfile.subDistrictId
              : baseUser.subDistrictId),
      postCode: enrichedProfile?.postCode.isNotEmpty == true
          ? enrichedProfile!.postCode
          : (mobileProfile.postCode.isNotEmpty
              ? mobileProfile.postCode
              : baseUser.postCode),
      status: mobileProfile.status.isNotEmpty
          ? mobileProfile.status
          : (enrichedProfile?.status.isNotEmpty == true
              ? enrichedProfile!.status
              : baseUser.status),
      isActive: mobileProfile.status.isNotEmpty
          ? mobileProfile.isActive
          : (enrichedProfile?.status.isNotEmpty == true
              ? enrichedProfile!.isActive
              : baseUser.isActive),
      imageUrl: mobileProfile.imageUrl.isNotEmpty
          ? mobileProfile.imageUrl
          : (enrichedProfile?.imageUrl.isNotEmpty == true
              ? enrichedProfile!.imageUrl
              : baseUser.imageUrl),
      createdAt: mobileProfile.createdAt.isNotEmpty
          ? mobileProfile.createdAt
          : (enrichedProfile?.createdAt.isNotEmpty == true
              ? enrichedProfile!.createdAt
              : baseUser.createdAt),
    );
  }

  Future<void> _openEditProfileSheet() async {
    final updatedUser = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(initialUser: _user),
    );

    if (!mounted || updatedUser == null) {
      return;
    }

    setState(() {
      _user = updatedUser;
    });
    widget.onUserUpdated?.call(updatedUser);
    if (widget.popOnUpdate) {
      Navigator.of(context).pop(updatedUser);
    }
  }

  Future<void> _handleLogout() async {
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto verifikasi final sudah tersimpan lokal.')),
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title masih disiapkan.')),
    );
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    widget.onBackRequested?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 18),
            _buildProfileMenuList(),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleLogout,
                child: const Text('Keluar'),
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
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
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
                          _user.name.trim().isEmpty ? 'Member Gymmaster' : _user.name,
                          style: TextStyle(
                            color: heroTextColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Atur profil dan data akun kamu di sini.',
                          style: TextStyle(
                            color: heroSubTextColor,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
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

  Widget _buildFaceEnrollmentCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.face_retouching_natural_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selfie verifikasi',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Liveness on-device dengan step tengah, sisi, sisi balik, lalu senyum.',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _openFaceEnrollment,
            child: Text(
              _faceEnrollmentResult == null ? 'Mulai' : 'Ulangi',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuList() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
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
        Divider(color: dividerColor),
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
        Divider(color: dividerColor),
        _MenuRowTile(
          icon: Icons.lock_outline_rounded,
          title: 'Keamanan',
          subtitle: 'Atur kunci aplikasi, PIN, dan proteksi akses.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
            );
          },
        ),
        if (_faceEnrollmentResult != null) ...[
          const SizedBox(height: 18),
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

class _EditProfileSheet extends StatefulWidget {
  final User initialUser;

  const _EditProfileSheet({required this.initialUser});

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUser.name);
    _phoneController = TextEditingController(text: widget.initialUser.phone);
    _addressController = TextEditingController(text: widget.initialUser.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
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
        throw const AuthException('Sesi login tidak ditemukan. Silakan login ulang.');
      }

      final updatedUser = await _authService.updateMemberProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        token: session.token,
        tokenType: session.tokenType,
        imageBytes: _selectedProfileBytes,
        imageFileName: _selectedProfileName,
      );

      await _sessionStorage.updateStoredUser(updatedUser);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
      Navigator.of(context).pop(updatedUser);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan perubahan profil ke server.'),
        ),
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
      });
    } catch (error, stackTrace) {
      debugPrint('===== PROFILE PICK IMAGE ERROR START =====');
      debugPrint('Error: $error');
      debugPrint('$stackTrace');
      debugPrint('===== PROFILE PICK IMAGE ERROR END =====');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil file. Coba lagi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
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
            mainAxisSize: MainAxisSize.min,
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
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
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
                  const SizedBox(height: 8),
                  Text(
                    'Perbarui data member kamu langsung dari slider ini.',
                    style: TextStyle(
                      color: onSurfaceVariant.withValues(alpha: 0.95),
                      height: 1.5,
                    ),
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
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
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
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
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
        border: Border.all(
          color: onSurfaceVariant.withValues(alpha: 0.14),
        ),
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
              child: _selectedProfileBytes != null
                  ? Image.memory(
                      _selectedProfileBytes!,
                      fit: BoxFit.cover,
                    )
                  : profileImageUrl.isNotEmpty
                      ? _buildProfileImage(
                          imageUrl: profileImageUrl,
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickProfileImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pilih file'),
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _MenuRowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFFFF2E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
