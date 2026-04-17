import 'dart:typed_data';

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

class ProfileSettingsScreen extends StatefulWidget {
  final User initialUser;
  final bool popOnUpdate;
  final ValueChanged<User>? onUserUpdated;
  final VoidCallback? onBackRequested;

  const ProfileSettingsScreen({
    super.key,
    required this.initialUser,
    this.popOnUpdate = true,
    this.onUserUpdated,
    this.onBackRequested,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _sessionStorage = const SessionStorage();
  late User _user;
  FaceEnrollmentResult? _faceEnrollmentResult;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
  }

  @override
  void didUpdateWidget(covariant ProfileSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialUser.memberCode != widget.initialUser.memberCode ||
        oldWidget.initialUser.name != widget.initialUser.name ||
        oldWidget.initialUser.phone != widget.initialUser.phone ||
        oldWidget.initialUser.address != widget.initialUser.address) {
      _user = widget.initialUser;
    }
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
                      child: Image.asset(
                        'assets/images/logo/logo-icon-black-red.png',
                        fit: BoxFit.cover,
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
  late final TextEditingController _provinceIdController;
  late final TextEditingController _cityIdController;
  late final TextEditingController _districtIdController;
  late final TextEditingController _subDistrictIdController;
  late final TextEditingController _postCodeController;

  bool _isSaving = false;
  Uint8List? _selectedProfileBytes;
  String? _selectedProfileName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUser.name);
    _phoneController = TextEditingController(text: widget.initialUser.phone);
    _addressController = TextEditingController(text: widget.initialUser.address);
    _provinceIdController = TextEditingController(
      text: widget.initialUser.provinceId,
    );
    _cityIdController = TextEditingController(text: widget.initialUser.cityId);
    _districtIdController = TextEditingController(
      text: widget.initialUser.districtId,
    );
    _subDistrictIdController = TextEditingController(
      text: widget.initialUser.subDistrictId,
    );
    _postCodeController = TextEditingController(text: widget.initialUser.postCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _provinceIdController.dispose();
    _cityIdController.dispose();
    _districtIdController.dispose();
    _subDistrictIdController.dispose();
    _postCodeController.dispose();
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
      final updatedUser = await _authService.updateMemberProfile(
        memberCode: widget.initialUser.memberCode,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        provinceId: _provinceIdController.text.trim(),
        cityId: _cityIdController.text.trim(),
        districtId: _districtIdController.text.trim(),
        subDistrictId: _subDistrictIdController.text.trim(),
        postCode: _postCodeController.text.trim(),
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
        imageQuality: 90,
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka galeri. Coba lagi.'),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _provinceIdController,
                          label: 'Province ID',
                          icon: Icons.map_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _cityIdController,
                          label: 'City ID',
                          icon: Icons.location_city_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _districtIdController,
                          label: 'District ID',
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _subDistrictIdController,
                          label: 'Sub District ID',
                          icon: Icons.place_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _postCodeController,
                    label: 'Post code',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
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
