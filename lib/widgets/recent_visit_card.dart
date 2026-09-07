import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RecentVisitCard extends StatelessWidget {
  final String gym;
  final String time;
  final String status;
  final String statusBadge;
  final bool isDark;

  const RecentVisitCard({
    super.key,
    required this.gym,
    required this.time,
    required this.status,
    required this.statusBadge,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedBadge = statusBadge.trim().toUpperCase();
    final normalizedStatus = status.trim().toUpperCase();
    final isCheckin =
        normalizedBadge.contains('CHECK-IN') ||
        normalizedBadge == 'OPEN' ||
        normalizedStatus.contains('CHECK-IN');
    final iconSurface = isCheckin
        ? (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFFFF2F4))
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF2FAF5));
    final iconColor = isCheckin ? AppTheme.primary : AppTheme.success;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF0E7EA);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFFFFCFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 18,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: iconSurface,
            ),
            child: Icon(Icons.location_on_outlined, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : AppTheme.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.muted.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Text(
            statusBadge,
            style: TextStyle(
              color: isCheckin
                  ? (isDark ? const Color(0xFF91E1B7) : const Color(0xFF167C4F))
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : AppTheme.muted),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
