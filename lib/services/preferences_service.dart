import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _themeKey = 'app_theme';
  static const String _animeEffectsKey = 'anime_effects';

  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  Future<bool> getAnimeEffects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_animeEffectsKey) ?? true;
  }

  Future<void> setAnimeEffects(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animeEffectsKey, on);
  }
}
