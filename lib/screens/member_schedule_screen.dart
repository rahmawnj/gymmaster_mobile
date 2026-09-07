import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/member_schedule.dart';
import '../models/member_training_package.dart';
import '../models/user.dart';
import '../services/membership_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/top_notification.dart';

class MemberScheduleScreen extends StatefulWidget {
  final User user;

  const MemberScheduleScreen({super.key, required this.user});

  @override
  State<MemberScheduleScreen> createState() => _MemberScheduleScreenState();
}

class _MemberScheduleScreenState extends State<MemberScheduleScreen> {
  final _membershipService = const MembershipService();
  final _sessionStorage = const SessionStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<MemberSchedule> _schedules = [];
  List<MemberTrainingPackage> _activePackages = [];

  bool _isCreating = false;
  MemberTrainingPackage? _selectedPackage;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException('Sesi tidak valid.');
      }

      final schedules = await _membershipService.fetchSchedules(
        token: session.token,
      );

      final packages = await _membershipService.fetchActiveTrainingPackages(
        token: session.token,
      );

      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _activePackages = packages;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createSchedule() async {
    if (_selectedPackage == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      TopNotification.show(
        context,
        message: 'Harap lengkapi semua data jadwal',
        type: TopNotificationType.error,
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MembershipException('Sesi tidak valid.');
      }

      final sessionDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final startTimeStr =
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      final endTimeStr =
          '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';

      await _membershipService.createSchedule(
        memberId: int.tryParse(widget.user.memberId) ?? 0,
        historyPackageId: _selectedPackage!.id,
        sessionDate: sessionDate,
        startTime: startTimeStr,
        endTime: endTimeStr,
        token: session.token,
      );

      if (!mounted) return;
      TopNotification.show(
        context,
        message: 'Berhasil membuat jadwal training',
        type: TopNotificationType.success,
      );

      // Reload data
      await _loadData();
      setState(() {
        _isCreating = false;
        _selectedPackage = null;
        _selectedDate = null;
        _startTime = null;
        _endTime = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
      });
      TopNotification.show(
        context,
        message: e.toString(),
        type: TopNotificationType.error,
      );
    }
  }

  void _showCreateScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
          final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
          final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;

          if (_activePackages.isEmpty) {
            return Container(
              margin: const EdgeInsets.only(top: 64),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada paket aktif',
                    style: TextStyle(
                      color: inkColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anda harus memiliki paket training aktif untuk membuat jadwal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(top: 64),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Buat Jadwal Baru',
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Paket Training',
                      style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MemberTrainingPackage>(
                      value: _selectedPackage,
                      hint: const Text('Pilih paket'),
                      dropdownColor: surfaceColor,
                      items: _activePackages.map((pkg) {
                        return DropdownMenuItem(
                          value: pkg,
                          child: Text(
                            pkg.packageName,
                            style: TextStyle(color: inkColor),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => _selectedPackage = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tanggal Sesi',
                      style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => _selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: muted.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate == null
                                  ? 'Pilih tanggal'
                                  : DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedDate!),
                              style: TextStyle(
                                color: inkColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_rounded,
                              color: muted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Waktu Mulai',
                                style: TextStyle(
                                  color: inkColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() => _startTime = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: muted.withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _startTime == null
                                            ? '00:00'
                                            : _startTime!.format(context),
                                        style: TextStyle(
                                          color: inkColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        Icons.schedule_rounded,
                                        color: muted,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Waktu Selesai',
                                style: TextStyle(
                                  color: inkColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _startTime ?? TimeOfDay.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() => _endTime = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: muted.withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _endTime == null
                                            ? '00:00'
                                            : _endTime!.format(context),
                                        style: TextStyle(
                                          color: inkColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        Icons.schedule_rounded,
                                        color: muted,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isCreating
                            ? null
                            : () async {
                                setModalState(() => _isCreating = true);
                                await _createSchedule();
                                if (mounted && context.mounted) {
                                  setModalState(() => _isCreating = false);
                                  if (_errorMessage == null) {
                                    Navigator.pop(context);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Buat Jadwal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        : const Color(0xFFF9FAFC);
    final surfaceColor = isDark ? const Color(0xFF18191C) : Colors.white;
    final inkColor = isDark ? const Color(0xFFF1F3F6) : AppTheme.ink;
    final muted = isDark ? const Color(0xFF9AA3B2) : AppTheme.muted;
    final borderColor = isDark
        ? const Color(0xFF2A2D33)
        : const Color(0xFFF0F0F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Jadwal Training',
          style: TextStyle(
            color: inkColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateScheduleSheet,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Jadwal Baru',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      body: _isLoading
          ? _buildSkeletonLoader(isDark)
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _loadData,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              // <--- PULL GESTURE
              onRefresh: _loadData,
              child: _schedules.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        return _buildScheduleCard(
                          _schedules[index],
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          inkColor: inkColor,
                          muted: muted,
                          borderColor: borderColor,
                        );
                      },
                    )
                  : ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy_rounded,
                                size: 80,
                                color: muted.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Belum Ada Jadwal',
                                style: TextStyle(
                                  color: inkColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Jadwal training yang Anda buat\nakan muncul di sini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18191C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2D33) : const Color(0xFFF0F0F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 120,
                    height: 24,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 16,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(
    MemberSchedule schedule, {
    required bool isDark,
    required Color surfaceColor,
    required Color inkColor,
    required Color muted,
    required Color borderColor,
  }) {
    // Format session date nicely
    String formattedDate = schedule.sessionDate;
    try {
      final dt = DateTime.parse(schedule.sessionDate);
      formattedDate = DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {}

    return Dismissible(
      // <--- SWIPE GESTURE
      key: Key(schedule.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        HapticFeedback.heavyImpact();
        TopNotification.show(
          context,
          message: 'Penghapusan jadwal belum tersedia di API',
          type: TopNotificationType.info,
        );
        return false; // Prevent actual removal for now since no API is available
      },
      background: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 32),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.red,
          size: 32,
        ),
      ),
      child: GestureDetector(
        // <--- HOLD / PRESS GESTURE
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showCreateScheduleSheet();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 24,
                    spreadRadius: -6,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        schedule.packageName,
                        style: TextStyle(
                          color: inkColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        schedule.status,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.person_outline_rounded,
                  'Trainer',
                  schedule.trainerName,
                  inkColor,
                  muted,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.calendar_today_rounded,
                  'Tanggal',
                  formattedDate,
                  inkColor,
                  muted,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.schedule_rounded,
                  'Waktu',
                  '${schedule.startTime} - ${schedule.endTime}',
                  inkColor,
                  muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color inkColor,
    Color muted,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: inkColor,
                  fontSize: 15,
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
