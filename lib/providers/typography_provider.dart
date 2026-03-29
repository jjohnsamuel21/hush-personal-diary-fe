import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global typography settings — applied across the app UI.
// Per-note font is separate (fontProvider / NoteFont enum).
class AppTypography {
  final String fontFamily;  // google-fonts name for body text
  final double fontScale;   // 0.85 / 1.0 / 1.15 / 1.3
  final Color textColor;    // override for body text color (null = theme default)
  final bool useCustomColor;

  const AppTypography({
    this.fontFamily = 'Merriweather',
    this.fontScale = 1.0,
    this.textColor = const Color(0xFF212121),
    this.useCustomColor = false,
  });

  AppTypography copyWith({
    String? fontFamily,
    double? fontScale,
    Color? textColor,
    bool? useCustomColor,
  }) => AppTypography(
    fontFamily: fontFamily ?? this.fontFamily,
    fontScale: fontScale ?? this.fontScale,
    textColor: textColor ?? this.textColor,
    useCustomColor: useCustomColor ?? this.useCustomColor,
  );
}

// Available font scale labels
const kFontScales = <String, double>{
  'Small':   0.85,
  'Default': 1.0,
  'Large':   1.15,
  'XL':      1.3,
};

// Available app-wide font families (google_fonts names)
const kAppFonts = [
  'Merriweather',
  'Lato',
  'Playfair Display',
  'Roboto',
  'Nunito',
  'Source Serif 4',
  'Caveat',
];

// Preset text color swatches
const kTextColorPresets = <String, Color>{
  'Dark':       Color(0xFF212121),
  'Warm Black': Color(0xFF3E2723),
  'Slate':      Color(0xFF37474F),
  'Navy':       Color(0xFF0D1B2A),
  'White':      Color(0xFFFFFFFF),
  'Cream':      Color(0xFFFFF8E7),
  'Purple':     Color(0xFF4A148C),
  'Sepia':      Color(0xFF5D4037),
};

const _keyFont       = 'typo_font';
const _keyScale      = 'typo_scale';
const _keyColor      = 'typo_color';
const _keyUseColor   = 'typo_use_color';

class TypographyNotifier extends StateNotifier<AppTypography> {
  TypographyNotifier() : super(const AppTypography()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppTypography(
      fontFamily: prefs.getString(_keyFont) ?? 'Merriweather',
      fontScale: prefs.getDouble(_keyScale) ?? 1.0,
      textColor: Color(prefs.getInt(_keyColor) ?? 0xFF212121),
      useCustomColor: prefs.getBool(_keyUseColor) ?? false,
    );
  }

  Future<void> setFontFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFont, family);
    state = state.copyWith(fontFamily: family);
  }

  Future<void> setFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScale, scale);
    state = state.copyWith(fontScale: scale);
  }

  Future<void> setTextColor(Color color, {bool useCustom = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColor, color.toARGB32());
    await prefs.setBool(_keyUseColor, useCustom);
    state = state.copyWith(textColor: color, useCustomColor: useCustom);
  }

  Future<void> resetTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseColor, false);
    state = state.copyWith(useCustomColor: false);
  }
}

final typographyProvider =
    StateNotifierProvider<TypographyNotifier, AppTypography>(
  (ref) => TypographyNotifier(),
);
