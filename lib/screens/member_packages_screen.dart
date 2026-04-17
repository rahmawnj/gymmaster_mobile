import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/member_membership.dart';
import '../models/user.dart';
import '../services/api_config.dart';
import '../services/membership_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'scan_qr_hub_screen.dart';

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
  final _membershipService = const MembershipService();
  final _sessionStorage = const SessionStorage();
  final List<_BrandSectionData> _brandSections = const [
    _BrandSectionData(
      brandName: 'FTL Gym',
      tagline: 'Pilih cabang lalu lihat paket terbaik untuk kebutuhan latihanmu.',
      branches: [
        _BranchPackageData(
          branchName: 'Branch Demo',
          branchAddress: 'Jl. Sukajadi No. 21, Bandung',
          latitude: -6.890120,
          longitude: 107.596340,
          packages: [
            _PackageCardData(
              durationLabel: '1 Bulan',
              name: 'Silver 1 Bulan',
              price: 'Rp 350.000',
              perks: [
                'Akses semua alat berat',
                '1x Free Personal Trainer',
                'Akses Loker & Shower',
                'Berlaku di seluruh cabang Gymmaster yang ikut paket ini',
              ],
              isRecommended: false,
            ),
            _PackageCardData(
              durationLabel: '6 Bulan',
              name: 'Gold 6 Bulan',
              price: 'Rp 1.800.000',
              perks: [
                'Semua benefit Silver',
                'Akses Kelas Zumba & Yoga',
                'Free Handuk Setiap Latihan',
                'Diskon 10% di Gym Cafe',
                'Bisa dipakai lintas cabang yang tersedia',
              ],
              isRecommended: true,
            ),
          ],
        ),
        _BranchPackageData(
          branchName: 'Gymmaster Pasteur',
          branchAddress: 'Jl. Dr. Djunjunan No. 145, Bandung',
          latitude: -6.893540,
          longitude: 107.575920,
          packages: [
            _PackageCardData(
              durationLabel: '3 Bulan',
              name: 'Performance 3 Bulan',
              price: 'Rp 920.000',
              perks: [
                'Akses alat dan area functional',
                '2x sesi evaluasi trainer',
                'Free handuk setiap kunjungan',
                'Akses cabang lain jika paket tersedia di sana',
              ],
              isRecommended: true,
            ),
          ],
        ),
        _BranchPackageData(
          branchName: 'Studio Cihampelas',
          branchAddress: 'Jl. Cihampelas No. 88, Bandung',
          latitude: -6.893980,
          longitude: 107.604810,
          packages: [
            _PackageCardData(
              durationLabel: '1 Bulan',
              name: 'Starter Studio',
              price: 'Rp 290.000',
              perks: [
                'Akses studio dan area cardio',
                'Kelas group training pilihan',
                'Locker harian',
                'Bisa digunakan di cabang studio terkait',
              ],
              isRecommended: false,
            ),
          ],
        ),
      ],
    ),
    _BrandSectionData(
      brandName: 'Apex Strength',
      tagline: 'Membership studio dengan fokus strength, cardio, dan class harian.',
      branches: [
        _BranchPackageData(
          branchName: 'Fit Vault Dago',
          branchAddress: 'Jl. Ir. H. Juanda No. 112, Bandung',
          latitude: -6.884870,
          longitude: 107.613410,
          packages: [
            _PackageCardData(
              durationLabel: '1 Bulan',
              name: 'Studio Pass',
              price: 'Rp 320.000',
              perks: [
                'Akses semua area studio',
                '2x kelas pilihan setiap minggu',
                'Berlaku di cabang Fit Vault terkait',
              ],
              isRecommended: false,
            ),
          ],
        ),
        _BranchPackageData(
          branchName: 'Fit Vault Setiabudi',
          branchAddress: 'Jl. Setiabudi No. 77, Bandung',
          latitude: -6.861230,
          longitude: 107.596920,
          packages: [
            _PackageCardData(
              durationLabel: '3 Bulan',
              name: 'Vault Unlimited',
              price: 'Rp 840.000',
              perks: [
                'Unlimited class access',
                '1x body composition check',
                'Akses lintas cabang Fit Vault',
              ],
              isRecommended: true,
            ),
          ],
        ),
      ],
    ),
    _BrandSectionData(
      brandName: 'Core Republic',
      tagline: 'Pilihan tepat untuk latihan intensif dengan fasilitas alat lengkap.',
      branches: [
        _BranchPackageData(
          branchName: 'Iron Temple Jakarta Barat',
          branchAddress: 'Jl. Panjang No. 45, Jakarta Barat',
          latitude: -6.198440,
          longitude: 106.769220,
          packages: [
            _PackageCardData(
              durationLabel: '1 Bulan',
              name: 'Temple Basic',
              price: 'Rp 410.000',
              perks: [
                'Akses area free weight',
                'Locker harian',
                'Bisa dipakai di cabang aktif lainnya',
              ],
              isRecommended: false,
            ),
          ],
        ),
        _BranchPackageData(
          branchName: 'Iron Temple Kelapa Gading',
          branchAddress: 'Jl. Boulevard Raya No. 8, Jakarta Utara',
          latitude: -6.159870,
          longitude: 106.908230,
          packages: [
            _PackageCardData(
              durationLabel: '6 Bulan',
              name: 'Temple Elite',
              price: 'Rp 2.150.000',
              perks: [
                'Unlimited access seluruh jam operasional',
                '4x personal coach session',
                'Akses multi-cabang Iron Temple',
              ],
              isRecommended: true,
            ),
          ],
        ),
      ],
    ),
    _BrandSectionData(
      brandName: 'Urban Motion',
      tagline: 'Hybrid gym dengan class room, cardio deck, dan recovery corner.',
      branches: [
        _BranchPackageData(
          branchName: 'Pulse Seminyak',
          branchAddress: 'Jl. Kayu Aya No. 10, Bali',
          latitude: -8.682540,
          longitude: 115.164820,
          packages: [
            _PackageCardData(
              durationLabel: '1 Bulan',
              name: 'Pulse Starter',
              price: 'Rp 375.000',
              perks: [
                'Akses gym dan cardio deck',
                '1x kelas group training',
                'Akses cabang Pulse yang setara',
              ],
              isRecommended: false,
            ),
          ],
        ),
        _BranchPackageData(
          branchName: 'Pulse Kuta',
          branchAddress: 'Jl. Sunset Road No. 21, Bali',
          latitude: -8.701640,
          longitude: 115.184310,
          packages: [
            _PackageCardData(
              durationLabel: '12 Bulan',
              name: 'Pulse Signature',
              price: 'Rp 3.200.000',
              perks: [
                'Akses semua fasilitas premium',
                'Recovery lounge access',
                'Berlaku untuk seluruh cabang Pulse',
              ],
              isRecommended: true,
            ),
          ],
        ),
      ],
    ),
    _BrandSectionData(
      brandName: 'Forge Athletics',
      tagline: 'Brand modern untuk latihan fungsional, mobility, dan transformasi tubuh.',
      branches: [
        _BranchPackageData(
          branchName: 'Core Union Surabaya Barat',
          branchAddress: 'Jl. Mayjen Sungkono No. 51, Surabaya',
          latitude: -7.289420,
          longitude: 112.707540,
          packages: [
            _PackageCardData(
              durationLabel: '1 Bulan',
              name: 'Core Start',
              price: 'Rp 340.000',
              perks: [
                'Akses area latihan functional',
                'Program mobility mingguan',
                'Bisa digunakan di cabang Core Union aktif',
              ],
              isRecommended: false,
            ),
          ],
        ),
        _BranchPackageData(
          branchName: 'Core Union Tunjungan',
          branchAddress: 'Jl. Tunjungan No. 90, Surabaya',
          latitude: -7.257840,
          longitude: 112.737880,
          packages: [
            _PackageCardData(
              durationLabel: '6 Bulan',
              name: 'Core Transformation',
              price: 'Rp 1.980.000',
              perks: [
                'Training plan personal',
                'Monthly progress review',
                'Akses lintas cabang Core Union',
              ],
              isRecommended: true,
            ),
          ],
        ),
      ],
    ),
  ];

  int _tabIndex = 0; // 0 = Paket Aktif, 1 = Beli Paket
  bool _isLoading = true;
  bool _locationEnabled = false;
  final _searchController = TextEditingController();
  Position? _currentPosition;
  String? _locationError;
  String? _errorMessage;
  List<MemberMembership> _memberships = const [];
  late final PageController _membershipPageController;
  int _currentMembershipIndex = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _membershipPageController = PageController(viewportFraction: 0.92);
    _loadMemberships();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _membershipPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleLocation() async {
    if (_locationEnabled) {
      setState(() {
        _locationEnabled = false;
        _currentPosition = null;
        _locationError = null;
      });
      return;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationEnabled = false;
          _locationError = 'Izin lokasi belum diberikan.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationEnabled = false;
          _locationError = 'GPS perangkat belum aktif.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _locationEnabled = true;
        _currentPosition = position;
        _locationError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationEnabled = false;
        _locationError = 'Gagal mengambil lokasi perangkat.';
      });
    }
  }

  List<_BrandSectionData> _buildVisibleBrands() {
    final query = _searchController.text.trim().toLowerCase();
    var brands = _brandSections.where((brand) {
      if (query.isEmpty) {
        return true;
      }

      final matchesBrand = brand.brandName.toLowerCase().contains(query);
      final matchesBranch = brand.branches.any(
        (branch) =>
            branch.branchName.toLowerCase().contains(query) ||
            branch.branchAddress.toLowerCase().contains(query),
      );
      return matchesBrand || matchesBranch;
    }).toList();

    if (_locationEnabled && _currentPosition != null) {
      brands.sort((a, b) {
        final aDistance = _nearestBranchDistanceKm(a);
        final bDistance = _nearestBranchDistanceKm(b);
        return aDistance.compareTo(bDistance);
      });
    }

    return brands;
  }

  double _nearestBranchDistanceKm(_BrandSectionData brand) {
    if (_currentPosition == null) {
      return double.infinity;
    }

    return brand.branches
        .map((branch) {
          final meters = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            branch.latitude,
            branch.longitude,
          );
          return meters / 1000;
        })
        .reduce(math.min);
  }

  Future<void> _loadMemberships() async {
    final userId = widget.currentUser.id.trim();
    if (userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User ID tidak tersedia. Silakan login ulang.';
      });
      return;
    }

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

      final result = await _membershipService.fetchMemberships(
        userId: userId,
        token: session.token,
        tokenType: session.tokenType,
        status: 'ACTIVE',
      );

      if (!mounted) return;
      
      // Mengisi rentang dummy data jika api belum mengembalikan langganan aktif
      // Dirancang agar desain kartu membership yang baru dapat dilihat pengguna
      final finalResult = result.isEmpty 
          ? [
              const MemberMembership(
                branchName: 'Fit Vault Dago',
                membershipName: 'Elite Functional 12 Bulan (Premium)',
                startDate: '01 Jan 2026',
                expDate: '01 Jan 2027',
                status: 'ACTIVE',
              ),
              const MemberMembership(
                branchName: 'Core Union Surabaya',
                membershipName: 'Studio Starter Pass (Trial)',
                startDate: '15 Mar 2026',
                expDate: '15 Apr 2026',
                status: 'ACTIVE',
              ),
            ]
          : result;

      setState(() {
        _memberships = finalResult;
        _isLoading = false;
        _currentMembershipIndex = 0;
      });
      _resetAutoSlide();
    } on MembershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengambil paket. ${ApiConfig.serverHint}';
        _isLoading = false;
      });
    }
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
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0F1012) : const Color(0xFFF6F7FB);
    final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
    final surfaceSoft =
        isDark ? const Color(0xFF22242A) : const Color(0xFFF4F6FB);
    final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
    final inkSoft = isDark ? const Color(0xFFB5BCC8) : AppTheme.inkSoft;
    final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;
    final borderColor =
        isDark ? const Color(0xFF2A2D33) : const Color(0xFFE8E8E8);

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
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSegmentedTabs(
              isDark: isDark,
              surfaceColor: surfaceColor,
              inkSoft: inkSoft,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildBody(
                isDark: isDark,
                surfaceColor: surfaceColor,
                surfaceSoft: surfaceSoft,
                inkColor: inkColor,
                inkSoft: inkSoft,
                muted: muted,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    if (_tabIndex == 1) {
      return _buildBuyPackageView(
        isDark: isDark,
        surfaceColor: surfaceColor,
        surfaceSoft: surfaceSoft,
        inkColor: inkColor,
        inkSoft: inkSoft,
        muted: muted,
        borderColor: borderColor,
      );
    }

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
              Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
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
      return _buildEmptyState(
        inkColor: inkColor,
        muted: muted,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMemberships,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          _buildMembershipCarousel(
            isDark: isDark,
            surfaceColor: surfaceColor,
            surfaceSoft: surfaceSoft,
            inkColor: inkColor,
            inkSoft: inkSoft,
            muted: muted,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          _buildMembershipIndicators(),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required Color inkColor,
    required Color muted,
  }) {
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
              'Paket akan muncul setelah status ACTIVE.',
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

  Widget _buildSegmentedTabs({
    required bool isDark,
    required Color surfaceColor,
    required Color inkSoft,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
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
                  setState(() {
                    _tabIndex = 1;
                  });
                  _autoSlideTimer?.cancel();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCarousel({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    if (_memberships.length == 1) {
      return _buildMembershipCard(
        _memberships.first,
        isDark: isDark,
        surfaceColor: surfaceColor,
        surfaceSoft: surfaceSoft,
        inkColor: inkColor,
        inkSoft: inkSoft,
        muted: muted,
        borderColor: borderColor,
      );
    }

    return SizedBox(
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
              inkSoft: inkSoft,
              muted: muted,
              borderColor: borderColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembershipIndicators() {
    if (_memberships.length <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
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
    );
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : inactiveColor,
            fontWeight: FontWeight.w800,
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
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    final visibleBrands = _buildVisibleBrands();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildBuyToolbar(
          isDark: isDark,
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
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (visibleBrands.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18191C) : surfaceColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              'Tidak ada brand yang cocok dengan pencarianmu.',
              style: TextStyle(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...List.generate(visibleBrands.length, (index) {
            final brand = visibleBrands[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleBrands.length - 1 ? 0 : 18,
              ),
              child: _buildBrandSection(
                brand: brand,
                isDark: isDark,
                surfaceColor: surfaceColor,
                surfaceSoft: surfaceSoft,
                inkColor: inkColor,
                inkSoft: inkSoft,
                muted: muted,
                borderColor: borderColor,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBuyToolbar({
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color muted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191C) : surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: inkColor),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search brand atau branch',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleTabChangeFromToolbar(2),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan QR'),
                ),
              ),
              const SizedBox(width: 10),
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
                            color: _locationEnabled ? AppTheme.primary : inkColor,
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

  void _handleTabChangeFromToolbar(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanQrHubScreen(currentUser: widget.currentUser),
      ),
    );
  }

  Widget _buildBrandSection({
    required _BrandSectionData brand,
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    final nearestDistanceKm =
        _locationEnabled ? _nearestBranchDistanceKm(brand) : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191C) : surfaceColor,
        borderRadius: BorderRadius.circular(24),
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      brand.brandName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: inkColor,
                        fontSize: 19,
                      ),
                    ),
                    if (nearestDistanceKm != null &&
                        nearestDistanceKm.isFinite) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Jarak: ${nearestDistanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _BrandPackagesDetailScreen(brand: brand),
                    ),
                  );
                },
                child: const Text('Pilih Paket'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            brand.tagline,
            style: TextStyle(
              color: muted.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(brand.branches.length, (index) {
            final branch = brand.branches[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == brand.branches.length - 1 ? 0 : 10,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
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
                      child: Icon(
                        Icons.location_on_outlined,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.branchName,
                            style: TextStyle(
                              color: inkColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            branch.branchAddress,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    _PackageCardData data, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceSoft,
    required Color inkColor,
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    final cardBorderColor = data.isRecommended
        ? AppTheme.primary.withValues(alpha: isDark ? 0.55 : 1)
        : borderColor;
    final buttonBackground = isDark
        ? (data.isRecommended
              ? AppTheme.primary
              : const Color(0xFF24272D))
        : Colors.white;
    final buttonForeground = isDark
        ? Colors.white
        : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1E22) : surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardBorderColor,
          width: data.isRecommended ? 1.2 : 1,
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.durationLabel,
                  style: TextStyle(
                    color: inkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (data.isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'REKOMENDASI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.name,
            style: TextStyle(
              color: inkColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.price,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...data.perks.map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: TextStyle(
                        color: inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: buttonBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.transparent : AppTheme.primary,
                  width: 1.2,
                ),
              ),
              child: Text(
                'Paket mengikuti brand yang dipilih',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: buttonForeground.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
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
    required Color inkSoft,
    required Color muted,
    required Color borderColor,
  }) {
    final isActive = membership.isActive;
    
    final gradient = isActive 
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B2D31), Color(0xFF111214)],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1F2024), const Color(0xFF141518)]
                : [const Color(0xFFF0F2F5), const Color(0xFFE2E5EA)],
          );

    final textColor = isActive || isDark ? Colors.white : AppTheme.ink;
    final mutedText = isActive || isDark 
        ? Colors.white.withValues(alpha: 0.55) 
        : AppTheme.muted;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              ]
            : [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        isActive ? Icons.verified_rounded : Icons.info_outline_rounded,
                        color: isActive ? AppTheme.primary : mutedText,
                        size: 20,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : textColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive 
                                ? AppTheme.success.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          membership.status.isEmpty ? '-' : membership.status,
                          style: TextStyle(
                            color: isActive ? AppTheme.success : textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    membership.membershipName.isEmpty ? '-' : membership.membershipName,
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
                  const SizedBox(height: 4),
                  Text(
                    membership.branchName.isEmpty ? '-' : membership.branchName,
                    style: TextStyle(
                      color: mutedText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BERLAKU MULAI',
                            style: TextStyle(
                              color: mutedText,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            membership.startDate.isEmpty ? '-' : membership.startDate,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: textColor.withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BERAKHIR PADA',
                            style: TextStyle(
                              color: mutedText,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            membership.expDate.isEmpty ? '-' : membership.expDate,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }
}

class _BrandPackagesDetailScreen extends StatelessWidget {
  final _BrandSectionData brand;

  const _BrandPackagesDetailScreen({required this.brand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0F1012) : const Color(0xFFF6F7FB);
    final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
    final surfaceSoft =
        isDark ? const Color(0xFF22242A) : const Color(0xFFF4F6FB);
    final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
    final inkSoft = isDark ? const Color(0xFFB5BCC8) : AppTheme.inkSoft;
    final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;
    final borderColor =
        isDark ? const Color(0xFF2A2D33) : const Color(0xFFE8E8E8);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Text(
          brand.brandName,
          style: TextStyle(
            color: inkColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
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
                        brand.brandName,
                        style: TextStyle(
                          color: inkColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        brand.tagline,
                        style: TextStyle(
                          color: muted,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...brand.branches.map(
            (branch) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.branchName,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      branch.branchAddress,
                      style: TextStyle(
                        color: muted,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...branch.packages.map(
                      (item) => _BrandPackageCard(
                        data: item,
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        surfaceSoft: surfaceSoft,
                        inkColor: inkColor,
                        inkSoft: inkSoft,
                        muted: muted,
                        borderColor: borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPackageCard extends StatelessWidget {
  final _PackageCardData data;
  final bool isDark;
  final Color surfaceColor;
  final Color surfaceSoft;
  final Color inkColor;
  final Color inkSoft;
  final Color muted;
  final Color borderColor;

  const _BrandPackageCard({
    required this.data,
    required this.isDark,
    required this.surfaceColor,
    required this.surfaceSoft,
    required this.inkColor,
    required this.inkSoft,
    required this.muted,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardBorderColor = data.isRecommended
        ? AppTheme.primary.withValues(alpha: isDark ? 0.55 : 1)
        : borderColor;
    final buttonBackground = isDark
        ? (data.isRecommended ? AppTheme.primary : const Color(0xFF24272D))
        : Colors.white;
    final buttonForeground = isDark ? Colors.white : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1E22) : surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardBorderColor,
          width: data.isRecommended ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.durationLabel,
                  style: TextStyle(
                    color: inkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (data.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'REKOMENDASI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.name,
            style: TextStyle(
              color: inkColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.price,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...data.perks.map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: TextStyle(
                        color: inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                backgroundColor: buttonBackground,
                foregroundColor: buttonForeground,
              ),
              child: const Text('Pilih Paket'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCardData {
  final String durationLabel;
  final String name;
  final String price;
  final List<String> perks;
  final bool isRecommended;

  const _PackageCardData({
    required this.durationLabel,
    required this.name,
    required this.price,
    required this.perks,
    required this.isRecommended,
  });
}

class _BrandSectionData {
  final String brandName;
  final String tagline;
  final List<_BranchPackageData> branches;

  const _BrandSectionData({
    required this.brandName,
    required this.tagline,
    required this.branches,
  });
}

class _BranchPackageData {
  final String branchName;
  final String branchAddress;
  final double latitude;
  final double longitude;
  final List<_PackageCardData> packages;

  const _BranchPackageData({
    required this.branchName,
    required this.branchAddress,
    required this.latitude,
    required this.longitude,
    required this.packages,
  });
}
