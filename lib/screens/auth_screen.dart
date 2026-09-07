import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_session.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/top_notification.dart';
import 'main_shell_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Ubah nilai ini kalau seluruh kartu/login sheet ingin dinaikkan atau diturunkan.
  static const double _cardStackVerticalOffset = -10;
  static const double _collapsedSheetMinHeight = 286;
  static const double _loginSheetMinHeight = 410;
  static const double _registerSheetMinHeight = 560;
  static const String _heroBackgroundImage = 'assets/images/auth-gym-bg.jpg';
  static const String _heroLogoImage =
      'assets/images/logo/logo-swoosh-red-left.png';

  final _formKey = GlobalKey<FormState>();
  final _authService = const AuthService();
  final _sessionStorage = const SessionStorage();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _provinceIdController;
  late final TextEditingController _cityIdController;
  late final TextEditingController _districtIdController;
  late final TextEditingController _subDistrictIdController;
  late final TextEditingController _postCodeController;
  late final TextEditingController _addressController;

  late bool _isLoginMode;

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _sheetVisible = false;
  bool _sheetExpanded = true;
  DateTime? _lastBackPressedAt;
  late final AnimationController _sheetSwitchController;
  late final Animation<double> _sheetSwitchOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLoginMode = widget.isLogin;
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _phoneController = TextEditingController();
    _provinceIdController = TextEditingController();
    _cityIdController = TextEditingController();
    _districtIdController = TextEditingController();
    _subDistrictIdController = TextEditingController();
    _postCodeController = TextEditingController();
    _addressController = TextEditingController();
    _sheetSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _sheetSwitchOffset = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 28.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 44,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 28.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 56,
      ),
    ]).animate(_sheetSwitchController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _sheetVisible = true;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _provinceIdController.dispose();
    _cityIdController.dispose();
    _districtIdController.dispose();
    _subDistrictIdController.dispose();
    _postCodeController.dispose();
    _addressController.dispose();
    _sheetSwitchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lastBackPressedAt = null;
      TopNotification.clear();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = _isLoginMode
          ? await _authService.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await _authService.register(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              phone: _phoneController.text.trim(),
              provinceId: int.parse(_provinceIdController.text.trim()),
              cityId: int.parse(_cityIdController.text.trim()),
              districtId: int.parse(_districtIdController.text.trim()),
              subDistrictId: int.parse(_subDistrictIdController.text.trim()),
              postCode: _postCodeController.text.trim(),
              address: _addressController.text.trim(),
            );

      var activeSession = session;
      if (_isLoginMode) {
        try {
          final member = await _authService.fetchMemberProfile(
            userId: session.user.userId,
            token: session.token,
            tokenType: session.tokenType,
          );

          final mergedUser = session.user.copyWith(
            id: session.user.id.isNotEmpty ? session.user.id : member.id,
            userId: member.userId.isNotEmpty
                ? member.userId
                : session.user.userId,
            memberCode: member.memberCode.isNotEmpty
                ? member.memberCode
                : session.user.memberCode,
            name: member.name.isNotEmpty ? member.name : session.user.name,
            email: member.email.isNotEmpty ? member.email : session.user.email,
            phone: member.phone.isNotEmpty ? member.phone : session.user.phone,
            provinceId: member.provinceId.isNotEmpty
                ? member.provinceId
                : session.user.provinceId,
            cityId: member.cityId.isNotEmpty
                ? member.cityId
                : session.user.cityId,
            districtId: member.districtId.isNotEmpty
                ? member.districtId
                : session.user.districtId,
            subDistrictId: member.subDistrictId.isNotEmpty
                ? member.subDistrictId
                : session.user.subDistrictId,
            postCode: member.postCode.isNotEmpty
                ? member.postCode
                : session.user.postCode,
            address: member.address.isNotEmpty
                ? member.address
                : session.user.address,
            createdAt: member.createdAt.isNotEmpty
                ? member.createdAt
                : session.user.createdAt,
            status: member.status.isNotEmpty
                ? member.status
                : session.user.status,
            isActive: member.status.isNotEmpty
                ? member.isActive
                : session.user.isActive,
            imageUrl: member.imageUrl.isNotEmpty
                ? member.imageUrl
                : session.user.imageUrl,
          );

          activeSession = AuthSession(
            status: session.status,
            message: session.message,
            token: session.token,
            tokenType: session.tokenType,
            user: mergedUser,
          );
        } on AuthException {
          activeSession = session;
        }
      }

      if (!mounted) return;
      await _sessionStorage.saveSession(activeSession);
      if (!mounted) return;
      TopNotification.show(
        context,
        message: _isLoginMode
            ? 'Login berhasil. Selamat datang ${activeSession.user.name}.'
            : 'Pendaftaran berhasil. Selamat datang ${activeSession.user.name}.',
        type: TopNotificationType.success,
      );
      _openHome(activeSession);
    } on AuthException catch (error) {
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
        message: 'Gagal terhubung ke server. ${ApiConfig.serverHint}',
        type: TopNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _openHome(AuthSession session) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainShellScreen(currentUser: session.user),
      ),
    );
  }

  void _switchMode(bool isLogin) {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (_isLoginMode == isLogin) {
      if (!_sheetExpanded) {
        setState(() {
          _sheetExpanded = true;
        });
      }
      return;
    }
    setState(() {
      _isLoginMode = isLogin;
      _sheetExpanded = true;
    });
    _sheetSwitchController.forward(from: 0);
  }

  void _handleBackPressed() {
    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <
            const Duration(milliseconds: 1200);

    if (shouldExit) {
      _lastBackPressedAt = null;
      TopNotification.clear();
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    TopNotification.show(
      context,
      message: 'Tekan 2 kali untuk keluar.',
      type: TopNotificationType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = mediaQuery.size.width < 360 ? 20.0 : 36.0;
            final sheetHeight = _resolveSheetHeight(
              mediaQuery: mediaQuery,
              viewportHeight: constraints.maxHeight,
            );

            return Container(
              color: const Color(0xFFF8F8F8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackgroundImage(),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        20,
                        horizontalPadding,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          const SizedBox(
                            width: 240,
                            height: 108,
                            child: Center(
                              child: Image(
                                image: AssetImage(_heroLogoImage),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: Center(
                              key: ValueKey(_isLoginMode),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _isLoginMode
                                          ? 'Selamat Datang'
                                          : 'Daftar Akun',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0x66000000),
                                                blurRadius: 18,
                                                offset: Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isLoginMode
                                          ? 'Masuk untuk melanjutkan.'
                                          : 'Lengkapi data diri untuk mendaftar akun baru.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.84,
                                            ),
                                            height: 1.4,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0x55000000),
                                                blurRadius: 12,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                        bottom: mediaQuery.viewInsets.bottom,
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 360),
                        opacity: _sheetVisible ? 1 : 0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 460),
                          curve: Curves.easeOutBack,
                          offset: _sheetVisible
                              ? Offset.zero
                              : const Offset(0, 1),
                          child: AnimatedBuilder(
                            animation: _sheetSwitchOffset,
                            child: _buildBottomSheet(theme),
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  _sheetSwitchOffset.value +
                                      _cardStackVerticalOffset,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  height: sheetHeight,
                                  width: double.infinity,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 560,
                                      ),
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _resolveSheetHeight({
    required MediaQueryData mediaQuery,
    required double viewportHeight,
  }) {
    final expandedFactor = _isLoginMode ? 0.48 : 0.70;
    final collapsedFactor = mediaQuery.size.height < 760 ? 0.38 : 0.35;
    final heightFactor = _sheetExpanded ? expandedFactor : collapsedFactor;
    final minHeight =
        (_sheetExpanded
            ? (_isLoginMode ? _loginSheetMinHeight : _registerSheetMinHeight)
            : _collapsedSheetMinHeight) +
        mediaQuery.padding.bottom;
    final maxHeight = math.max(minHeight, viewportHeight - 12);
    final preferredHeight = viewportHeight * heightFactor;

    return preferredHeight.clamp(minHeight, maxHeight).toDouble();
  }

  Widget _buildBackgroundImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _heroBackgroundImage,
          fit: BoxFit.cover,
          alignment: const Alignment(0.24, 0),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.24),
                const Color(0xB0130B0C),
                const Color(0xF2090909),
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.32),
              ],
              stops: const [0, 0.52, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.02, -0.52),
              radius: 0.92,
              colors: [
                Colors.white.withValues(alpha: 0.035),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(ThemeData theme) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _sheetExpanded = !_sheetExpanded;
              });
            },
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -4 && !_sheetExpanded) {
                setState(() {
                  _sheetExpanded = true;
                });
              } else if (details.delta.dy > 4 && _sheetExpanded) {
                setState(() {
                  _sheetExpanded = false;
                });
              }
            },
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!_sheetExpanded) ...[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 16 + bottomSafeArea),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Masuk ke Gymmaster',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pilih salah satu untuk lanjut.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _switchMode(true),
                        child: const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoginMode ? null : () => _switchMode(false),
                        child: const Text('Daftar — Coming Soon'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              _isLoginMode ? 'Masuk' : 'Daftar',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels < -40 && _sheetExpanded) {
                    setState(() {
                      _sheetExpanded = false;
                    });
                    FocusScope.of(context).unfocus();
                    return true;
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isLoginMode) ...[
                          _buildField(
                            controller: _nameController,
                            label: 'Nama lengkap',
                            icon: Icons.badge_outlined,
                            validator: _requiredValidator('Nama diperlukan'),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildField(
                          controller: _emailController,
                          label: 'example@mail.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email diperlukan';
                            }
                            if (!value.contains('@')) {
                              return 'Email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _passwordController,
                          label: 'Masukkan password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.muted,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password diperlukan';
                            }
                            if (value.length < 6) {
                              return 'Password minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        if (!_isLoginMode) ...[
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _phoneController,
                            label: 'Nomor telepon',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: _requiredValidator(
                              'Nomor telepon diperlukan',
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _provinceIdController,
                            label: 'Province ID',
                            icon: Icons.map_outlined,
                            keyboardType: TextInputType.number,
                            validator: _numberValidator('Province ID wajib'),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _cityIdController,
                            label: 'City ID',
                            icon: Icons.location_city_outlined,
                            keyboardType: TextInputType.number,
                            validator: _numberValidator('City ID wajib'),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _districtIdController,
                            label: 'District ID',
                            icon: Icons.pin_drop_outlined,
                            keyboardType: TextInputType.number,
                            validator: _numberValidator('District ID wajib'),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _subDistrictIdController,
                            label: 'Sub District ID',
                            icon: Icons.place_outlined,
                            keyboardType: TextInputType.number,
                            validator: _numberValidator(
                              'Sub District ID wajib',
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _postCodeController,
                            label: 'Post Code',
                            icon: Icons.markunread_mailbox_outlined,
                            keyboardType: TextInputType.number,
                            validator: _requiredValidator(
                              'Post code diperlukan',
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _addressController,
                            label: 'Alamat',
                            icon: Icons.home_outlined,
                            maxLines: 3,
                            validator: _requiredValidator('Alamat diperlukan'),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(_isLoginMode ? 'Masuk' : 'Daftar'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _isLoginMode
                                    ? 'Belum punya akun?'
                                    : 'Sudah punya akun?',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                              TextButton(
                                onPressed: _isSubmitting || _isLoginMode
                                    ? null
                                    : () => _switchMode(!_isLoginMode),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppTheme.primary,
                                ),
                                child: Text(
                                  _isLoginMode ? 'Daftar — Coming Soon' : 'Masuk',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  String? Function(String?) _numberValidator(String requiredMessage) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return requiredMessage;
      }
      if (int.tryParse(value.trim()) == null) {
        return 'Harus berupa angka';
      }
      return null;
    };
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? trailing,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: const TextStyle(color: AppTheme.ink),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: AppTheme.ink.withValues(alpha: 0.55)),
        prefixIcon: Icon(icon, color: AppTheme.muted),
        suffixIcon: trailing,
        filled: true,
        fillColor: const Color(0xFFF0F1F4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
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
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      ),
    );
  }
}
