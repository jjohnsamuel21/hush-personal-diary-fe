import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/theme_constants.dart';

// Holds the active HushTheme. Persists to SharedPreferences so it survives restarts.
// main.dart watches this and rebuilds MaterialApp when it changes.
class ThemeNotifier extends StateNotifier<HushTheme> {
  ThemeNotifier() : super(kDefaultTheme) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(AppConstants.keyActiveThemeId);
    if (savedId == null) return;
    final found = kHushThemes.where((t) => t.id == savedId);
    if (found.isNotEmpty) state = found.first;
  }

  Future<void> setTheme(HushTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyActiveThemeId, theme.id);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, HushTheme>(
  (ref) => ThemeNotifier(),
);
