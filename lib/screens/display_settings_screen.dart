import 'package:flutter/material.dart';

import '../services/theme_mode_controller.dart';

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final controller = ThemeModeController.instance;
    final isSystem = controller.mode == ThemeMode.system;
    final isDark = controller.mode == ThemeMode.dark;
    final dividerColor = onSurfaceVariant.withValues(alpha: 0.18);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Text(
          'Tampilan',
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Tampilan',
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _SwitchRowTile(
            title: 'Ikuti sistem',
            subtitle: 'Otomatis menyesuaikan tema HP',
            value: isSystem,
            onChanged: (value) {
              controller.setMode(value ? ThemeMode.system : ThemeMode.light);
              setState(() {});
            },
          ),
          Divider(color: dividerColor),
          _SwitchRowTile(
            title: 'Mode gelap',
            subtitle: 'Aktifkan tampilan gelap',
            value: isDark,
            onChanged: isSystem
                ? null
                : (value) {
                    controller
                        .setMode(value ? ThemeMode.dark : ThemeMode.light);
                    setState(() {});
                  },
          ),
        ],
      ),
    );
  }
}

class _SwitchRowTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRowTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: scheme.primary,
          ),
        ],
      ),
    );
  }
}
