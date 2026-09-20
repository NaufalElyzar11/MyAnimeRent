import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Theme Setting
            _SettingRow(
              label: 'Theme',
              currentValue: settings.currentTheme.name[0].toUpperCase() +
                  settings.currentTheme.name.substring(1),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: AppTheme.values
                          .map(
                            (t) => ListTile(
                              title: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                              trailing: settings.currentTheme == t
                                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                                  : null,
                              onTap: () {
                                settings.setTheme(t);
                                Navigator.pop(context);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _SettingRow(
              label: 'Language',
              currentValue: 'English',
              onTap: () {},
            ),

            const SizedBox(height: 32),
            // Brand / About Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kostum Hari Ini, Cerita Seru Esok Nanti ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Platform rental kostum anime di Indonesia yang lebih terorganisir, praktis, dan terpercaya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String currentValue;
  final VoidCallback onTap;

  const _SettingRow({
    required this.label,
    required this.currentValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.titleMedium),
            ),
            Text(
              currentValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
