import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
