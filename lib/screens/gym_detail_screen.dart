import 'package:flutter/material.dart';

import '../models/gym_access_history_item.dart';
import '../models/gym.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/gym_service.dart';
import '../theme/app_theme.dart';
import 'gym_access_qr_screen.dart';

class GymDetailScreen extends StatefulWidget {
  final Gym gym;
  final String memberCode;

  const GymDetailScreen({
    super.key,
    required this.gym,
    required this.memberCode,
  });

  @override
  State<GymDetailScreen> createState() => _GymDetailScreenState();
}

class _GymDetailScreenState extends State<GymDetailScreen> {
  final _gymService = const GymService();

  late Gym _gym;
  List<GymAccessHistoryItem> _accessHistory = const [];
  bool _isLoading = true;
  bool _isJoining = false;
  bool _isHistoryLoading = true;
  String? _errorMessage;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _gym = widget.gym;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _isHistoryLoading = true;
      _errorMessage = null;
      _historyError = null;
    });

    try {
      final detailGym = await _gymService.fetchGymDetail(
        gymCode: widget.gym.gymCode,
        fallbackGym: widget.gym,
      );

      GymAccessHistoryResult historyResult = const GymAccessHistoryResult(
        history: <GymAccessHistoryItem>[],
      );
      String? historyError;

      if (widget.memberCode.isNotEmpty) {
        try {
          historyResult = await _gymService.fetchMemberAccessHistory(
            memberCode: widget.memberCode,
            gymCode: widget.gym.gymCode,
          );
        } on AuthException catch (error) {
          historyError = error.message;
        } catch (_) {
          historyError = 'History akses belum bisa diambil saat ini.';
        }
      }

      if (!mounted) return;
      setState(() {
        _gym = historyResult.gym == null
            ? detailGym
            : _mergeGymData(detailGym, historyResult.gym!);
        _accessHistory = historyResult.history;
        _isLoading = false;
        _isHistoryLoading = false;
        _historyError = historyError;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _gym = widget.gym;
        _isLoading = false;
        _isHistoryLoading = false;
        _errorMessage = error.message;
        _historyError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gym = widget.gym;
        _isLoading = false;
        _isHistoryLoading = false;
        _errorMessage = 'Gagal mengambil detail gym. ${ApiConfig.serverHint}';
        _historyError = null;
      });
    }
  }

  Future<void> _joinGym() async {
    if (_isJoining || _gym.isJoined || widget.memberCode.isEmpty) {
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final result = await _gymService.joinGym(
        memberCode: widget.memberCode,
        gymCode: _gym.gymCode,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
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
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _openAccessQrPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GymAccessQrScreen(gym: _gym, memberCode: widget.memberCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _gym.isJoined;
    final isJoinAction = _gym.canJoinAction;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.memberCode.isEmpty || !_gym.isJoined
                  ? null
                  : _openAccessQrPage,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 10,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text(
                'Show QR',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 236,
            backgroundColor: AppTheme.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.heroGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.success.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isActive ? 'Active membership' : _gym.statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _gym.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                                _gym.city,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              _buildNoticeCard(
                                icon: Icons.info_outline_rounded,
                                title: 'Detail tambahan belum tersedia',
                                message: _errorMessage!,
                              ),
                              const SizedBox(height: 18),
                            ],
                            _buildOverviewCard(
                              isActive: isActive,
                              isJoinAction: isJoinAction,
                            ),
                            const SizedBox(height: 18),
                            _buildDetailsPanel(),
                            const SizedBox(height: 18),
                            _buildContentCard(
                              icon: Icons.description_outlined,
                              title: 'Description',
                              child: Text(
                                _gym.description.isEmpty
                                    ? 'Belum ada deskripsi gym dari API.'
                                    : _gym.description,
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildContentCard(
                              icon: Icons.location_city_outlined,
                              title: 'Address',
                              child: Text(
                                _gym.address.isEmpty ? '-' : _gym.address,
                                style: const TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Visit History',
                                    style: TextStyle(
                                      color: AppTheme.ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (_isHistoryLoading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.1,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _historyError != null
                                  ? _historyError!
                                  : 'Riwayat akses member per brand gym diambil dari endpoint history terbaru.',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._buildHistoryContent(),
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

  Widget _buildOverviewCard({
    required bool isActive,
    required bool isJoinAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                : _gym.isPending
                ? 'Request join sedang menunggu persetujuan dari server.'
                : 'Detail brand gym sudah terbuka. Kamu bisa kirim join request langsung ke server dari halaman ini.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSummaryChip(
                icon: Icons.badge_outlined,
                label: _gym.gymCode,
              ),
              _buildSummaryChip(
                icon: Icons.location_city_outlined,
                label: _gym.city,
              ),
              _buildSummaryChip(
                icon: Icons.verified_user_outlined,
                label: _gym.statusLabel,
              ),
            ],
          ),
          if (!_gym.isJoined) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gym.isPending
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white,
                  foregroundColor: _gym.isPending
                      ? Colors.white70
                      : AppTheme.primaryDark,
                ),
                onPressed: isJoinAction && !_isJoining && !_gym.isPending
                    ? _joinGym
                    : null,
                child: _isJoining
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryDark,
                          ),
                        ),
                      )
                    : Text(
                        _gym.isPending ? 'Request Pending' : _gym.actionLabel,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return _buildContentCard(
      icon: Icons.grid_view_rounded,
      title: 'Gym Details',
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.badge_outlined,
            label: 'Gym Code',
            value: _gym.gymCode.isEmpty ? '-' : _gym.gymCode,
          ),
          _buildDetailDivider(),
          _buildDetailRow(
            icon: Icons.pin_drop_outlined,
            label: 'Status',
            value: _gym.statusLabel.isEmpty ? '-' : _gym.statusLabel,
          ),
          if (_gym.requestedAt != null) ...[
            _buildDetailDivider(),
            _buildDetailRow(
              icon: Icons.schedule_outlined,
              label: 'Requested At',
              value: _gym.requestedAt!,
            ),
          ],
          if (_gym.joinedAt != null) ...[
            _buildDetailDivider(),
            _buildDetailRow(
              icon: Icons.event_available_outlined,
              label: 'Joined At',
              value: _gym.joinedAt!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.black.withValues(alpha: 0.06),
      ),
    );
  }

  List<Widget> _buildHistoryContent() {
    if (_isHistoryLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_historyError != null) {
      return [_HistoryEmptyState(message: _historyError!)];
    }

    if (_accessHistory.isEmpty) {
      return const [
        _HistoryEmptyState(
          message: 'Belum ada history akses untuk brand gym ini.',
        ),
      ];
    }

    return _accessHistory.map(_buildVisitLogTile).toList();
  }

  Widget _buildVisitLogTile(GymAccessHistoryItem log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _accessMethodLabel(log.accessMethod),
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Recorded',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Brand access log untuk ${_gym.name}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildLogMeta(
                      Icons.calendar_today_rounded,
                      _formatAccessDate(log.accessedAt),
                    ),
                    _buildLogMeta(
                      Icons.schedule_rounded,
                      _formatAccessTime(log.accessedAt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogMeta(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _accessMethodLabel(String accessMethod) {
    final normalized = accessMethod.trim().toLowerCase();
    if (normalized == 'qr') {
      return 'QR Scan Access';
    }
    if (normalized.isEmpty) {
      return 'Access Log';
    }

    return normalized
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _formatAccessDate(String raw) {
    final dateTime = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dateTime == null) {
      return raw.isEmpty ? '-' : raw;
    }

    const months = [
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

    return '${dateTime.day.toString().padLeft(2, '0')} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  String _formatAccessTime(String raw) {
    final dateTime = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dateTime == null) {
      return raw.isEmpty ? '-' : raw;
    }

    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Gym _mergeGymData(Gym primary, Gym secondary) {
    return primary.copyWith(
      id: secondary.id.isNotEmpty ? secondary.id : primary.id,
      gymCode: secondary.gymCode.isNotEmpty
          ? secondary.gymCode
          : primary.gymCode,
      name: secondary.name.isNotEmpty ? secondary.name : primary.name,
      city: secondary.city.isNotEmpty ? secondary.city : primary.city,
      address: secondary.address.isNotEmpty
          ? secondary.address
          : primary.address,
      description: secondary.description.isNotEmpty
          ? secondary.description
          : primary.description,
      isJoined: secondary.isJoined || primary.isJoined,
      canRequestJoin: secondary.canRequestJoin || primary.canRequestJoin,
      status: secondary.status.isNotEmpty ? secondary.status : primary.status,
      requestedAt: secondary.requestedAt ?? primary.requestedAt,
      approvedAt: secondary.approvedAt ?? primary.approvedAt,
      joinedAt: secondary.joinedAt ?? primary.joinedAt,
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final String message;

  const _HistoryEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 34,
            color: AppTheme.primaryDark,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
