import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gym.dart';
import '../models/user.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/camera_permission_service.dart';
import '../services/gym_service.dart';
import 'gym_detail_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class HomeScreen extends StatefulWidget {
  final User? currentUser;

  const HomeScreen({super.key, this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _pendingJoinPollInterval = Duration(seconds: 6);

  late final TabController _tabController;
  final _gymService = const GymService();
  final _cameraPermissionService = const CameraPermissionService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  User? _currentUser;
  Timer? _pendingJoinWatcherTimer;
  String? _pendingJoinGymCode;
  bool _isPendingJoinCheckInFlight = false;

  List<Gym> _joinedGyms = const [];
  List<Gym> _availableGyms = const [];
  List<Gym> _allGyms = const [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;

  String get _displayName {
    final name = _currentUser?.name.trim() ?? '';
    return name.isEmpty ? 'Member Gymmaster' : name;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = widget.currentUser;
    _tabController = TabController(length: 3, vsync: this);
    _loadGyms();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousMemberCode = oldWidget.currentUser?.memberCode ?? '';
    final currentMemberCode = widget.currentUser?.memberCode ?? '';
    final shouldReload = previousMemberCode != currentMemberCode;
    _currentUser = widget.currentUser;
    if (shouldReload) {
      unawaited(_loadGyms());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPendingJoinWatcher();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkPendingJoinStatus(force: true));
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pendingJoinWatcherTimer?.cancel();
    }
  }

  Future<void> _loadGyms() async {
    final memberCode = _currentUser?.memberCode ?? '';
    if (memberCode.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Member code tidak tersedia. Silakan login ulang.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _gymService.fetchAllLists(memberCode);
      if (!mounted) return;

      setState(() {
        _joinedGyms = result.joinedGyms;
        _availableGyms = result.availableGyms;
        _allGyms = result.allGyms;
        _isLoading = false;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal mengambil data gym. ${ApiConfig.serverHint}';
      });
    }
  }

  Future<void> _openGymDetailsPage(
    Gym gym, {
    bool showResultDialog = true,
  }) async {
    final memberCode = _currentUser?.memberCode ?? '';
    final result = await Navigator.of(context).push<JoinGymResult>(
      MaterialPageRoute(
        builder: (_) => GymDetailScreen(gym: gym, memberCode: memberCode),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadGyms();
    if (!mounted || result == null) {
      return;
    }
    if (showResultDialog) {
      await _showJoinSuccessDialog(result.message, result.gym);
    }
    _startPendingJoinWatcherIfNeeded(result.gym);
  }

  Future<void> _handleJoinRequest(Gym gym) async {
    final memberCode = _currentUser?.memberCode ?? '';
    if (memberCode.isEmpty) {
      return;
    }

    try {
      final result = await _gymService.joinGym(
        memberCode: memberCode,
        gymCode: gym.gymCode,
      );
      if (!mounted) return;

      await _loadGyms();
      if (!mounted) {
        return;
      }
      _startPendingJoinWatcherIfNeeded(result.gym);
      await _showJoinSuccessDialog(result.message, result.gym);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim join request ke server.')),
      );
    }
  }

  Future<void> _showJoinSuccessDialog(String message, Gym gym) async {
    final isWaitingApproval =
        gym.isPending || message.toLowerCase().contains('menunggu');

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Join Success',
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 360,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.84, end: 1),
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Container(
                            height: 84,
                            width: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isWaitingApproval
                                    ? const [
                                        Color(0xFFFF8A65),
                                        AppTheme.primary,
                                      ]
                                    : const [
                                        Color(0xFF37C37A),
                                        Color(0xFF178A52),
                                      ],
                              ),
                            ),
                            child: Icon(
                              isWaitingApproval
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isWaitingApproval
                              ? 'Request Berhasil Dikirim'
                              : 'Berhasil',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F4F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gym.name,
                                style: const TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isWaitingApproval
                                    ? 'Status saat ini: pending approval'
                                    : 'Status saat ini: ${gym.statusLabel}',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _startPendingJoinWatcherIfNeeded(Gym gym) {
    if (!gym.isPending) {
      _stopPendingJoinWatcher();
      return;
    }

    _pendingJoinGymCode = gym.gymCode;
    _pendingJoinWatcherTimer?.cancel();
    _pendingJoinWatcherTimer = Timer.periodic(
      _pendingJoinPollInterval,
      (_) => unawaited(_checkPendingJoinStatus()),
    );
    unawaited(_checkPendingJoinStatus(force: true));
  }

  void _stopPendingJoinWatcher() {
    _pendingJoinWatcherTimer?.cancel();
    _pendingJoinWatcherTimer = null;
    _pendingJoinGymCode = null;
    _isPendingJoinCheckInFlight = false;
  }

  Future<void> _checkPendingJoinStatus({bool force = false}) async {
    if (!mounted || _isPendingJoinCheckInFlight) {
      return;
    }

    final gymCode = _pendingJoinGymCode;
    final memberCode = _currentUser?.memberCode ?? '';
    if (gymCode == null || gymCode.isEmpty || memberCode.isEmpty) {
      _stopPendingJoinWatcher();
      return;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (!force && lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }

    _isPendingJoinCheckInFlight = true;

    try {
      final gyms = await _gymService.fetchAllGyms(memberCode);
      if (!mounted) {
        return;
      }

      final matchedGym = gyms.cast<Gym?>().firstWhere(
        (item) => item?.gymCode == gymCode,
        orElse: () => null,
      );

      if (matchedGym == null) {
        _stopPendingJoinWatcher();
        return;
      }

      if (matchedGym.isPending) {
        if (_pendingJoinWatcherTimer == null) {
          _startPendingJoinWatcherIfNeeded(matchedGym);
        }
        return;
      }

      _stopPendingJoinWatcher();

      if (!matchedGym.isJoined) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${matchedGym.name} sudah di-approve. Membuka halaman detail...',
          ),
        ),
      );
      await _openGymDetailsPage(matchedGym, showResultDialog: false);
    } catch (_) {
      // Keep polling lightweight and quiet on transient failures.
    } finally {
      _isPendingJoinCheckInFlight = false;
    }
  }

  Future<void> _openProfileSettingsPage() async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final updatedUser = await Navigator.of(context).push<User>(
      MaterialPageRoute(
        builder: (_) => ProfileSettingsScreen(initialUser: user),
      ),
    );

    if (!mounted || updatedUser == null) {
      return;
    }

    setState(() {
      _currentUser = updatedUser;
    });
  }

  Future<bool> _showJoinConfirmationDialog(Gym gym) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text(
            'Konfirmasi Request',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Kirim request join ke ${gym.name} sekarang?',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Request'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showGymDetailsSheet(Gym gym) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isActive = gym.isJoined;
        final isJoinAction = gym.canJoinAction;
        final isPending = gym.isPending;
        final primaryActionLabel = isActive
            ? 'Lihat Halaman Detail'
            : isPending
            ? 'Request Pending'
            : 'Request';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.70,
          minChildSize: 0.50,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9F4F1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  gym.name,
                                  style: const TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.success.withValues(alpha: 0.16)
                                      : AppTheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  isActive ? 'Active membership' : gym.statusLabel,
                                  style: TextStyle(
                                    color: isActive
                                        ? AppTheme.success
                                        : AppTheme.primaryDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  gym.city,
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _buildSheetHighlightCard(gym, isActive),
                          const SizedBox(height: 18),
                          const Text(
                            'Description',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            gym.description.isEmpty
                                ? 'Belum ada deskripsi gym dari API.'
                                : gym.description,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Gym Details',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSheetDetailsCard(gym: gym),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return const Color(0xFFD2D2D2);
                                  }
                                  return AppTheme.primary;
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return const Color(0xFF8F8F8F);
                                  }
                                  return Colors.white;
                                }),
                                overlayColor: WidgetStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return Colors.transparent;
                                  }
                                  return null;
                                }),
                                elevation: const WidgetStatePropertyAll(0),
                              ),
                              onPressed: isPending
                                  ? null
                                  : () async {
                                      if (isJoinAction) {
                                        final confirmed =
                                            await _showJoinConfirmationDialog(
                                              gym,
                                            );
                                        if (!confirmed || !mounted) {
                                          return;
                                        }
                                        Navigator.of(sheetContext).pop();
                                        await _handleJoinRequest(gym);
                                        return;
                                      }

                                      Navigator.of(sheetContext).pop();
                                      await _openGymDetailsPage(gym);
                                    },
                              child: Text(primaryActionLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleQrTap() async {
    await _openQrScanner();
  }

  Future<void> _openQrScanner() async {
    final result = await _cameraPermissionService.ensureCameraPermission();
    if (!mounted) return;

    switch (result) {
      case CameraPermissionResult.granted:
      case CameraPermissionResult.unsupported:
        final rawValue = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
        );

        if (!mounted || rawValue == null || rawValue.trim().isEmpty) {
          return;
        }

        await _showQrResultSheet(rawValue, sourceLabel: 'Kamera');
        break;
      case CameraPermissionResult.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin kamera dibutuhkan untuk scan QR langsung.'),
          ),
        );
        break;
      case CameraPermissionResult.permanentlyDenied:
        await _showCameraSettingsDialog();
        break;
    }
  }

  Future<void> _showQrResultSheet(
    String rawValue, {
    required String sourceLabel,
  }) async {
    final matchedGym = _findGymFromQrValue(rawValue);

    if (matchedGym != null) {
      if (matchedGym.isJoined) {
        await _openGymDetailsPage(matchedGym);
        return;
      }

      await _showGymDetailsSheet(matchedGym);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F4F1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Terbaca dari $sourceLabel',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QR berhasil dibaca',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    matchedGym != null
                        ? 'QR ini cocok dengan data gym yang ada di akun kamu.'
                        : 'Isi QR sudah terbaca. Kamu bisa pakai hasil ini untuk mencari gym.',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Isi QR',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rawValue,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _applyQrSearch(rawValue);
                      },
                      child: const Text('Gunakan untuk Pencarian'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Gym? _findGymFromQrValue(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final gym in _allGyms) {
      final gymCode = gym.gymCode.toLowerCase();
      final name = gym.name.toLowerCase();

      if (normalized == gymCode ||
          normalized.contains(gymCode) ||
          normalized == name) {
        return gym;
      }
    }

    return null;
  }

  void _applyQrSearch(String rawValue) {
    _searchController.text = rawValue;
    setState(() {
      _searchQuery = rawValue;
    });
    _tabController.animateTo(2);
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

  List<Gym> _filterGyms(List<Gym> gyms) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return gyms;
    }

    return gyms.where((gym) {
      return gym.name.toLowerCase().contains(query) ||
          gym.city.toLowerCase().contains(query) ||
          gym.gymCode.toLowerCase().contains(query) ||
          gym.address.toLowerCase().contains(query) ||
          gym.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const AppLogo(size: 85),
                        const Spacer(),
                        _buildProfilePill(),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSearchRow(),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          dividerColor: Colors.transparent,
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          splashBorderRadius: BorderRadius.circular(20),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: EdgeInsets.zero,
                          indicator: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppTheme.ink,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          tabs: const [
                            SizedBox(
                              height: 28,
                              child: Center(child: Text('My Gyms')),
                            ),
                            SizedBox(
                              height: 28,
                              child: Center(child: Text('Available')),
                            ),
                            SizedBox(
                              height: 28,
                              child: Center(child: Text('All')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfileSettingsPage,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56, maxWidth: 210),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person_rounded, color: AppTheme.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: 12),
        _buildQrButton(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: double.infinity,
            child: Center(
              child: Icon(
                Icons.manage_search_rounded,
                color: AppTheme.primary,
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                textInputAction: TextInputAction.search,
                maxLines: 1,
                cursorColor: AppTheme.primary,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hintText: 'Cari gym, kota, atau kode',
                  hintStyle: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Center(
            child: SizedBox(
              height: 42,
              width: 42,
              child: IconButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _handleQrTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: AppTheme.primary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loadGyms,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final hasSearch = _searchQuery.trim().isNotEmpty;
    final filteredJoinedGyms = _filterGyms(_joinedGyms);
    final filteredAvailableGyms = _filterGyms(_availableGyms);
    final filteredAllGyms = _filterGyms(_allGyms);

    return TabBarView(
      controller: _tabController,
      children: [
        _buildGymList(
          gyms: filteredJoinedGyms,
          title: 'Membership aktif kamu',
          subtitle: hasSearch
              ? 'Hasil pencarian untuk gym yang sudah kamu join.'
              : 'Daftar gym yang sudah kamu join berdasarkan data API member joined.',
          emptyTitle: hasSearch
              ? 'Gym aktif tidak ditemukan'
              : 'Belum ada gym aktif',
          emptySubtitle: hasSearch
              ? 'Coba kata kunci lain untuk mencari gym aktif kamu.'
              : 'Kamu belum join gym mana pun saat ini.',
        ),
        _buildGymList(
          gyms: filteredAvailableGyms,
          title: 'Tempat baru untuk dijelajahi',
          subtitle: hasSearch
              ? 'Hasil pencarian dari gym yang masih tersedia untuk join.'
              : 'Semua gym yang belum kamu join, langsung dari endpoint not-joined.',
          emptyTitle: hasSearch
              ? 'Gym available tidak ditemukan'
              : 'Semua gym sudah diikuti',
          emptySubtitle: hasSearch
              ? 'Coba kata kunci lain untuk melihat gym yang tersedia.'
              : 'Tidak ada gym baru yang tersedia untuk dijoin.',
        ),
        _buildGymList(
          gyms: filteredAllGyms,
          title: 'Semua brand gym',
          subtitle: hasSearch
              ? 'Hasil pencarian dari seluruh daftar brand gym.'
              : 'Gabungan gym joined dan not-joined dari endpoint all.',
          emptyTitle: hasSearch ? 'Gym tidak ditemukan' : 'Data gym kosong',
          emptySubtitle: hasSearch
              ? 'Belum ada gym yang cocok dengan pencarian kamu.'
              : 'Belum ada data gym dari server.',
        ),
      ],
    );
  }

  Widget _buildGymList({
    required List<Gym> gyms,
    required String title,
    required String subtitle,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: gyms.isEmpty ? 2 : gyms.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.muted, height: 1.45),
                  ),
                ],
              ),
            ),
          );
        }

        if (gyms.isEmpty) {
          return _buildEmptyState(emptyTitle, emptySubtitle);
        }

        return _buildGymCard(gyms[index - 1], index - 1);
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_rounded,
            size: 44,
            color: AppTheme.primaryDark,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymCard(Gym gym, int index) {
    final palettes = [
      const [Color(0xFFF44336), Color(0xFFB71C1C)],
      const [Color(0xFF2C2C2C), Color(0xFF111111)],
      const [Color(0xFFE53935), Color(0xFF3A0B0B)],
    ];
    final colors = palettes[index % palettes.length];
    final isActive = gym.isJoined;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 188,
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: AppLogo(size: 30),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.success.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        isActive ? 'Active membership' : gym.statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 12),
                Text(
                  gym.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        gym.city,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.description.isEmpty
                      ? 'Belum ada deskripsi gym dari API.'
                      : gym.description,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.badge_outlined,
                        text: gym.gymCode,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.place_outlined,
                        text: gym.statusLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  gym.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _showGymDetailsSheet(gym);
                    },
                    child: Text(gym.isJoined ? 'View Details' : 'Open Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHighlightCard(Gym gym, bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF1F8B4C), Color(0xFF163D24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isActive ? 'Membership Active' : 'Ready to Join',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isActive
                ? 'Gym ini sudah aktif di akun kamu.'
                : gym.isPending
                ? 'Request join masih menunggu persetujuan. Tombol di bawah akan cek atau kirim request lagi ke server.'
                : 'Brand gym ini belum aktif di akun kamu. Tombol di bawah akan kirim request join ke server.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetDetailsCard({
    required Gym gym,
  }) {
    final details = <({
      IconData icon,
      String label,
      String value,
      bool isMultiline,
    })>[
      (
        icon: Icons.badge_outlined,
        label: 'Gym Code',
        value: gym.gymCode,
        isMultiline: false,
      ),
      (
        icon: Icons.pin_drop_outlined,
        label: 'Status',
        value: gym.statusLabel,
        isMultiline: false,
      ),
      (
        icon: Icons.location_city_outlined,
        label: 'Address',
        value: gym.address,
        isMultiline: true,
      ),
      if (gym.requestedAt != null)
        (
          icon: Icons.schedule_outlined,
          label: 'Requested At',
          value: gym.requestedAt!,
          isMultiline: false,
        ),
      if (gym.approvedAt != null)
        (
          icon: Icons.verified_outlined,
          label: 'Approved At',
          value: gym.approvedAt!,
          isMultiline: false,
        ),
      if (gym.joinedAt != null)
        (
          icon: Icons.event_available_outlined,
          label: 'Joined At',
          value: gym.joinedAt!,
          isMultiline: false,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var index = 0; index < details.length; index++) ...[
            _buildCompactSheetDetailRow(
              icon: details[index].icon,
              label: details[index].label,
              value: details[index].value,
              isMultiline: details[index].isMultiline,
            ),
            if (index != details.length - 1)
              Divider(
                height: 1,
                color: AppTheme.muted.withValues(alpha: 0.14),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSheetDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isMultiline,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: isMultiline ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
