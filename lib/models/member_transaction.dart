class MemberTransaction {
  final int id;
  final String transactionCode;
  final String type;
  final String title;
  final String branchName;
  final String status;
  final int totalPrice;
  final String createdAt;
  final String paymentMethod;
  final String description;

  const MemberTransaction({
    required this.id,
    required this.transactionCode,
    required this.type,
    required this.title,
    required this.branchName,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    required this.paymentMethod,
    required this.description,
  });

  factory MemberTransaction.fromJson(Map<String, dynamic> json) {
    final membership = _asMap(json['membership']);
    final packageData = _asMap(json['package']);
    final branch = _asMap(json['branch']);

    return MemberTransaction(
      id: _firstInt(<Object?>[json['id'], json['transaction_id']]),
      transactionCode: _firstString(<Object?>[
        json['transaction_code'],
        json['code'],
        json['invoice_no'],
        json['invoice_number'],
      ]),
      type: _firstString(<Object?>[json['type'], json['transaction_type']]),
      title: _firstString(<Object?>[
        json['membership_name'],
        json['package_name'],
        json['item_name'],
        json['name'],
        membership['name'],
        packageData['name'],
      ]),
      branchName: _firstString(<Object?>[
        json['branch_name'],
        json['gym_name'],
        branch['name'],
      ]),
      status: _firstString(<Object?>[json['payment_status'], json['status']]),
      totalPrice: _firstInt(<Object?>[
        json['total_price'],
        json['grand_total'],
        json['amount'],
        json['price'],
        json['total'],
      ]),
      createdAt: _firstString(<Object?>[
        json['created_at'],
        json['transaction_date'],
        json['paid_at'],
        json['date'],
        json['updated_at'],
      ]),
      paymentMethod: _firstString(<Object?>[
        json['payment_method'],
        json['payment_type'],
        json['method'],
      ]),
      description: _firstString(<Object?>[json['description'], json['notes']]),
    );
  }

  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    if (description.trim().isNotEmpty) {
      return description.trim();
    }
    final normalizedType = type.trim().toUpperCase();
    if (normalizedType == 'PACKAGE') {
      return 'Transaksi Package';
    }
    return 'Transaksi Membership';
  }

  String get displayStatus {
    final normalized = status.trim();
    return normalized.isEmpty ? 'Menunggu' : normalized;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  static String _firstString(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  static int _firstInt(List<Object?> values) {
    for (final value in values) {
      final parsed = _toInt(value);
      if (parsed != 0) {
        return parsed;
      }
    }
    return 0;
  }

  static int _toInt(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }

    final trimmed = value.toString().trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    final normalized = trimmed.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (normalized.isEmpty) {
      return 0;
    }

    final direct = num.tryParse(normalized.replaceAll(',', ''));
    if (direct != null) {
      return direct.round();
    }

    final localized = num.tryParse(
      normalized.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (localized != null) {
      return localized.round();
    }

    return 0;
  }
}
