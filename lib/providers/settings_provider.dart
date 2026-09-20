import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

enum AppTheme { system, light, dark }

class SettingsProvider extends ChangeNotifier {
  final PreferencesService _prefsService = PreferencesService();
  AppTheme _currentTheme = AppTheme.system;

  AppTheme get currentTheme => _currentTheme;

  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }

  Future<void> loadSettings() async {
    final themeName = await _prefsService.getTheme();
    _currentTheme = AppTheme.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppTheme.system,
    );
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    await _prefsService.setTheme(theme.name);
    notifyListeners();
  }
}
