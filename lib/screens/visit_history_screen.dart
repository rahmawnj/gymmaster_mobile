import 'package:flutter/material.dart';

import '../models/member_visit_history.dart';
import '../services/member_visit_history_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/recent_visit_card.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final _historyService = const MemberVisitHistoryService();
  final _sessionStorage = const SessionStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<MemberVisitHistoryItem> _visits = const [];

  @override
  void initState() {
    super.initState();
    _loadVisitHistory();
  }

  Future<void> _loadVisitHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MemberVisitHistoryException(
          'Token tidak tersedia. Silakan login ulang.',
        );
      }

      final result = await _historyService.fetchVisitHistory(
        token: session.token,
        tokenType: session.tokenType,
        limit: 50,
      );

      if (!mounted) return;
      setState(() {
        _visits = result.visits;
        _isLoading = false;
      });
    } on MemberVisitHistoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Riwayat kunjungan belum bisa dimuat.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Kunjungan'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadVisitHistory,
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
        children: [
          Icon(Icons.cloud_off_rounded, size: 54, color: AppTheme.primaryDark),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _loadVisitHistory,
              child: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    if (_visits.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
        children: const [
          Icon(Icons.history_toggle_off_rounded, size: 54),
          SizedBox(height: 16),
          Text(
            'Belum ada riwayat kunjungan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: _visits.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final visit = _visits[index];
        return RecentVisitCard(
          gym: visit.branchName.trim().isEmpty ? '-' : visit.branchName,
          time: _formatDateTimeLabel(visit.scannedAt),
          status: _visitStatusLabel(visit.status),
          statusBadge: _visitStatusBadge(visit.status),
          isDark: isDark,
        );
      },
    );
  }

  String _visitStatusLabel(String status) {
    final normalized = status.trim().toUpperCase();
    switch (normalized) {
      case 'OPEN':
        return 'Check-in berhasil';
      case 'CLOSE':
        return 'Sesi selesai';
      default:
        return normalized.isEmpty ? '-' : normalized;
    }
  }

  String _visitStatusBadge(String status) {
    final normalized = status.trim().toUpperCase();
    return normalized.isEmpty ? '-' : normalized;
  }

  String _formatDateTimeLabel(String raw) {
    final parsed = _tryParseDate(raw);
    if (parsed == null) {
      return raw.trim().isEmpty ? '-' : raw.trim();
    }

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.day.toString().padLeft(2, '0')} '
        '${_monthLabel(parsed.month)} ${parsed.year} - $hour:$minute';
  }

  DateTime? _tryParseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return DateTime.tryParse(trimmed) ??
        DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
  }

  String _monthLabel(int month) {
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

    if (month < 1 || month > 12) {
      return '-';
    }
    return monthLabels[month - 1];
  }
}
