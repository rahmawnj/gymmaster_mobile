import 'package:flutter/material.dart';

import '../data/mock_visits.dart';
import '../widgets/recent_visit_card.dart';

class VisitHistoryScreen extends StatelessWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Kunjungan'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        itemCount: allMockVisits.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final visit = allMockVisits[index];
          return RecentVisitCard(
            gym: visit.$1,
            time: visit.$2,
            status: visit.$3,
            statusBadge: visit.$3.trim().toUpperCase(),
            isDark: isDark,
          );
        },
      ),
    );
  }
}
