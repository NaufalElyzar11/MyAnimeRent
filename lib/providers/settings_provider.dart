import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../widgets/sakuga.dart';

enum AppTheme { system, light, dark }

class SettingsProvider extends ChangeNotifier {
  final PreferencesService _prefsService = PreferencesService();
  AppTheme _currentTheme = AppTheme.system;

  AppTheme get currentTheme => _currentTheme;

  /// Efek gerak bergaya anime (ledakan kecil, toast meluncur, dll.).
  bool get animeEffects => Sakuga.enabled.value;

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
    Sakuga.enabled.value = await _prefsService.getAnimeEffects();
    notifyListeners();
  }

  Future<void> setAnimeEffects(bool on) async {
    Sakuga.enabled.value = on;
    notifyListeners();
    await _prefsService.setAnimeEffects(on);
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    await _prefsService.setTheme(theme.name);
    notifyListeners();
  }
}
