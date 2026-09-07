import 'package:flutter/material.dart';

import '../models/member_transaction.dart';
import '../services/member_transaction_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';

class MemberTransactionsScreen extends StatefulWidget {
  const MemberTransactionsScreen({super.key});

  @override
  State<MemberTransactionsScreen> createState() =>
      _MemberTransactionsScreenState();
}

class _MemberTransactionsScreenState extends State<MemberTransactionsScreen> {
  final _transactionService = const MemberTransactionService();
  final _sessionStorage = const SessionStorage();

  List<MemberTransaction> _transactions = const <MemberTransaction>[];
  bool _isLoading = true;
  String? _errorMessage;
  int _page = 1;
  final int _limit = 25;
  String? _selectedType;
  String? _selectedPackageId;
  String? _selectedDate;
  String? _selectedStatus = 'UNPAID';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _sessionStorage.loadSession();
      if (session == null || session.token.isEmpty) {
        throw const MemberTransactionException(
          'Sesi login tidak ditemukan. Silakan login ulang.',
        );
      }

      final transactions = await _transactionService.fetchTransactions(
        token: session.token,
        tokenType: session.tokenType,
        page: _page,
        limit: _limit,
        type: _selectedType,
        packageId: _selectedPackageId,
        status: _selectedStatus,
        tanggal: _selectedDate,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } on MemberTransactionException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Riwayat transaksi belum bisa dimuat. Coba beberapa saat lagi.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF121418) : const Color(0xFFF6F7FB);
    final cardColor = isDark ? const Color(0xFF181B20) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE7EAF1);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(title: const Text('Transaksi'), centerTitle: true),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadTransactions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _buildHeaderCard(
              theme: theme,
              isDark: isDark,
              cardColor: cardColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 12),
            _buildFilterCard(
              isDark: isDark,
              cardColor: cardColor,
              borderColor: borderColor,
            ),
            if (_errorMessage != null && _transactions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _InlineMessageCard(
                icon: Icons.info_outline_rounded,
                title: 'Sebagian data belum termuat',
                message: _errorMessage!,
              ),
            ],
            const SizedBox(height: 18),
            if (_isLoading && _transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _transactions.isEmpty)
              _FeedbackState(
                icon: Icons.receipt_long_outlined,
                title: 'Transaksi belum tersedia',
                message: _errorMessage!,
                actionLabel: 'Coba Lagi',
                onPressed: _loadTransactions,
              )
            else if (_transactions.isEmpty)
              _FeedbackState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada transaksi',
                message:
                    'Riwayat transaksi membership kamu akan muncul di halaman ini.',
              )
            else
              ..._buildTransactionCards(
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF17191E);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF69707D);
    final filters = _activeFilterLabels();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openFilterSheet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Transaksi',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filters.isEmpty ? 'Semua transaksi' : filters.join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _activeFilterLabels() {
    return <String>[
      ?_selectedStatus,
      ?_selectedType,
      if (_selectedPackageId != null) 'Package: $_selectedPackageId',
      ?_selectedDate,
      'Page $_page',
      'Limit $_limit',
    ];
  }

  Future<void> _openFilterSheet() async {
    final packageController = TextEditingController(text: _selectedPackageId);
    var tempType = _selectedType;
    var tempStatus = _selectedStatus;
    var tempDate = _selectedDate;

    final result = await showModalBottomSheet<_TransactionFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;
        final sheetColor = isDark ? const Color(0xFF181B20) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF17191E);
        final muted = isDark
            ? Colors.white.withValues(alpha: 0.68)
            : const Color(0xFF69707D);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final initialDate =
                  _tryParseDate(tempDate ?? '') ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked == null) return;
              setSheetState(() {
                tempDate =
                    '${picked.year.toString().padLeft(4, '0')}-'
                    '${picked.month.toString().padLeft(2, '0')}-'
                    '${picked.day.toString().padLeft(2, '0')}';
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filter Transaksi',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FilterLabel('Status', color: muted),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChoiceChip(
                            label: 'Semua',
                            selected: tempStatus == null,
                            onSelected: () =>
                                setSheetState(() => tempStatus = null),
                          ),
                          for (final status in const [
                            'UNPAID',
                            'PAID',
                            'CANCELLED',
                          ])
                            _FilterChoiceChip(
                              label: status,
                              selected: tempStatus == status,
                              onSelected: () =>
                                  setSheetState(() => tempStatus = status),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _FilterLabel('Type', color: muted),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChoiceChip(
                            label: 'Semua',
                            selected: tempType == null,
                            onSelected: () =>
                                setSheetState(() => tempType = null),
                          ),
                          for (final type in const ['MEMBERSHIP', 'PACKAGE'])
                            _FilterChoiceChip(
                              label: type,
                              selected: tempType == type,
                              onSelected: () =>
                                  setSheetState(() => tempType = type),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: packageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Package / membership_id',
                          hintText: 'Contoh: 3',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(tempDate ?? 'Pilih tanggal'),
                      ),
                      if (tempDate != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setSheetState(() => tempDate = null),
                          child: const Text('Hapus tanggal'),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                packageController.clear();
                                Navigator.of(context).pop(
                                  const _TransactionFilterResult(clear: true),
                                );
                              },
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  _TransactionFilterResult(
                                    type: tempType,
                                    status: tempStatus,
                                    packageId: packageController.text.trim(),
                                    tanggal: tempDate,
                                  ),
                                );
                              },
                              child: const Text('Terapkan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    packageController.dispose();
    if (result == null || !mounted) return;

    setState(() {
      _page = 1;
      if (result.clear) {
        _selectedType = null;
        _selectedStatus = null;
        _selectedPackageId = null;
        _selectedDate = null;
      } else {
        _selectedType = result.type;
        _selectedStatus = result.status;
        _selectedPackageId = result.packageId.trim().isEmpty
            ? null
            : result.packageId.trim();
        _selectedDate = result.tanggal;
      }
    });
    await _loadTransactions();
  }

  Widget _buildHeaderCard({
    required ThemeData theme,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
  }) {
    final titleColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.92);
    final bodyColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? const []
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Transaksi Member',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _transactions.isEmpty
                      ? 'Tarik ke bawah untuk refresh data transaksi terbaru.'
                      : '${_transactions.length} transaksi berhasil dimuat.',
                  style: TextStyle(
                    color: bodyColor,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTransactionCards({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
  }) {
    final widgets = <Widget>[];

    for (var index = 0; index < _transactions.length; index++) {
      final transaction = _transactions[index];
      widgets.add(
        _TransactionCard(
          transaction: transaction,
          isDark: isDark,
          cardColor: cardColor,
          borderColor: borderColor,
          formattedAmount: _formatCurrency(transaction.totalPrice),
          formattedDate: _formatDateTimeLabel(transaction.createdAt),
          statusColor: _statusColor(transaction.displayStatus),
        ),
      );
      if (index != _transactions.length - 1) {
        widgets.add(const SizedBox(height: 14));
      }
    }

    return widgets;
  }

  Color _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.contains('unpaid') ||
        normalized.contains('pending') ||
        normalized.contains('wait') ||
        normalized.contains('proses')) {
      return const Color(0xFFF39C12);
    }
    if (normalized.contains('paid') ||
        normalized.contains('success') ||
        normalized.contains('berhasil') ||
        normalized.contains('lunas')) {
      return const Color(0xFF179B63);
    }
    if (normalized.contains('cancel') ||
        normalized.contains('failed') ||
        normalized.contains('gagal') ||
        normalized.contains('expired')) {
      return const Color(0xFFE05252);
    }
    return AppTheme.primary;
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

class _TransactionFilterResult {
  final String? type;
  final String? status;
  final String packageId;
  final String? tanggal;
  final bool clear;

  const _TransactionFilterResult({
    this.type,
    this.status,
    this.packageId = '',
    this.tanggal,
    this.clear = false,
  });
}

class _FilterLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _FilterLabel(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : Theme.of(context).dividerColor.withValues(alpha: 0.6),
      ),
      showCheckmark: false,
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final MemberTransaction transaction;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final String formattedAmount;
  final String formattedDate;
  final Color statusColor;

  const _TransactionCard({
    required this.transaction,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.formattedAmount,
    required this.formattedDate,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = isDark ? Colors.white : const Color(0xFF17191E);
    final secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF69707D);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? const []
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.displayTitle,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.branchName.trim().isNotEmpty
                          ? transaction.branchName.trim()
                          : 'Transaksi membership',
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(label: transaction.displayStatus, color: statusColor),
            ],
          ),
          const SizedBox(height: 16),
          if (transaction.transactionCode.trim().isNotEmpty)
            _InfoRow(
              label: 'Kode Transaksi',
              value: transaction.transactionCode,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          _InfoRow(
            label: 'Tanggal',
            value: formattedDate,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          _InfoRow(
            label: 'Total',
            value: formattedAmount,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          if (transaction.paymentMethod.trim().isNotEmpty)
            _InfoRow(
              label: 'Metode',
              value: transaction.paymentMethod,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          if (transaction.id > 0)
            _InfoRow(
              label: 'ID',
              value: '#${transaction.id}',
              primaryText: primaryText,
              secondaryText: secondaryText,
              isLast: true,
            )
          else if (transaction.description.trim().isNotEmpty)
            _InfoRow(
              label: 'Catatan',
              value: transaction.description,
              primaryText: primaryText,
              secondaryText: secondaryText,
              isLast: true,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color primaryText;
  final Color secondaryText;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.primaryText,
    required this.secondaryText,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: primaryText, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeedbackState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _FeedbackState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF17191E),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.68)
                  : const Color(0xFF69707D),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _InlineMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D22) : const Color(0xFFFFF6EA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF4D9A7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF39C12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF17191E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF6D634E),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
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
