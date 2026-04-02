import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Background type ──────────────────────────────────────────────────────────
enum AppBackgroundType { color, gradient, image }

class AppBackground {
  final AppBackgroundType type;
  final Color? color;               // used when type == color
  final List<Color>? gradientColors; // used when type == gradient
  final String? imagePath;          // absolute file path when type == image

  const AppBackground.color(this.color)
      : type = AppBackgroundType.color,
        gradientColors = null,
        imagePath = null;

  const AppBackground.gradient(this.gradientColors)
      : type = AppBackgroundType.gradient,
        color = null,
        imagePath = null;

  const AppBackground.image(this.imagePath)
      : type = AppBackgroundType.image,
        color = null,
        gradientColors = null;
}

// ── Preset backgrounds ───────────────────────────────────────────────────────
class BackgroundPreset {
  final String id;
  final String name;
  final AppBackground background;
  const BackgroundPreset({required this.id, required this.name, required this.background});
}

final kBackgroundPresets = <BackgroundPreset>[
  BackgroundPreset(id: 'default',   name: 'Default',     background: AppBackground.color(const Color(0xFFF9F7F4))),
  BackgroundPreset(id: 'midnight',  name: 'Midnight',    background: AppBackground.color(const Color(0xFF121212))),
  BackgroundPreset(id: 'parchment', name: 'Parchment',   background: AppBackground.color(const Color(0xFFF5ECD7))),
  BackgroundPreset(id: 'sakura',    name: 'Sakura',      background: AppBackground.color(const Color(0xFFFCE4EC))),
  BackgroundPreset(id: 'ocean',     name: 'Ocean',       background: AppBackground.color(const Color(0xFFE3F2FD))),
  BackgroundPreset(id: 'forest',    name: 'Forest',      background: AppBackground.color(const Color(0xFFE8F5E9))),
  BackgroundPreset(id: 'noir',      name: 'Noir',        background: AppBackground.color(const Color(0xFF0A0A0A))),
  BackgroundPreset(id: 'grad-dusk', name: 'Dusk',        background: AppBackground.gradient([const Color(0xFF2C3E50), const Color(0xFF4CA1AF)])),
  BackgroundPreset(id: 'grad-rose', name: 'Rose Mist',   background: AppBackground.gradient([const Color(0xFFFFB7C5), const Color(0xFFFFF0F5)])),
  BackgroundPreset(id: 'grad-sun',  name: 'Sunrise',     background: AppBackground.gradient([const Color(0xFFFF9966), const Color(0xFFFF5E62)])),
  BackgroundPreset(id: 'grad-sky',  name: 'Sky',         background: AppBackground.gradient([const Color(0xFF56CCF2), const Color(0xFF2F80ED)])),
  BackgroundPreset(id: 'grad-mint', name: 'Mint',        background: AppBackground.gradient([const Color(0xFFACE0C1), const Color(0xFF3D9970)])),
];

// ── Provider ─────────────────────────────────────────────────────────────────
const _keyBgType   = 'bg_type';
const _keyBgColor  = 'bg_color';
const _keyBgGrad0  = 'bg_grad0';
const _keyBgGrad1  = 'bg_grad1';
const _keyBgImage  = 'bg_image';

class BackgroundNotifier extends StateNotifier<AppBackground> {
  BackgroundNotifier() : super(AppBackground.color(const Color(0xFFF9F7F4))) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString(_keyBgType) ?? 'color';
    switch (typeStr) {
      case 'gradient':
        final c0 = Color(prefs.getInt(_keyBgGrad0) ?? 0xFF2C3E50);
        final c1 = Color(prefs.getInt(_keyBgGrad1) ?? 0xFF4CA1AF);
        state = AppBackground.gradient([c0, c1]);
      case 'image':
        final path = prefs.getString(_keyBgImage);
        if (path != null && File(path).existsSync()) {
          state = AppBackground.image(path);
        }
      default:
        final colorVal = prefs.getInt(_keyBgColor) ?? 0xFFF9F7F4;
        state = AppBackground.color(Color(colorVal));
    }
  }

  Future<void> setColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBgType, 'color');
    await prefs.setInt(_keyBgColor, color.toARGB32());
    state = AppBackground.color(color);
  }

  Future<void> setGradient(List<Color> colors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBgType, 'gradient');
    await prefs.setInt(_keyBgGrad0, colors[0].toARGB32());
    await prefs.setInt(_keyBgGrad1, colors[1].toARGB32());
    state = AppBackground.gradient(colors);
  }

  Future<void> setImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBgType, 'image');
    await prefs.setString(_keyBgImage, path);
    state = AppBackground.image(path);
  }

  Future<void> setPreset(BackgroundPreset preset) async {
    switch (preset.background.type) {
      case AppBackgroundType.color:
        await setColor(preset.background.color!);
      case AppBackgroundType.gradient:
        await setGradient(preset.background.gradientColors!);
      case AppBackgroundType.image:
        if (preset.background.imagePath != null) {
          await setImage(preset.background.imagePath!);
        }
    }
  }
}

final backgroundProvider =
    StateNotifierProvider<BackgroundNotifier, AppBackground>(
  (ref) => BackgroundNotifier(),
);

// ── Background luminance helpers ─────────────────────────────────────────────
// Returns the single most-representative color of an AppBackground.
// Used to decide whether overlaid text should be light or dark.
Color? dominantColor(AppBackground bg) {
  switch (bg.type) {
    case AppBackgroundType.color:
      return bg.color;
    case AppBackgroundType.gradient:
      if (bg.gradientColors == null || bg.gradientColors!.isEmpty) return null;
      final c0 = bg.gradientColors![0];
      final c1 = bg.gradientColors![1];
      // Average of the two stops gives a reasonable mid-point
      return Color.fromARGB(
        255,
        (c0.red + c1.red) ~/ 2,
        (c0.green + c1.green) ~/ 2,
        (c0.blue + c1.blue) ~/ 2,
      );
    case AppBackgroundType.image:
      return null; // unknown — caller keeps existing theme colors
  }
}

/// Returns true when light (white-ish) text is needed on this background.
/// [defaultIsLight] used when the background color is unknowable (images).
bool needsLightText(AppBackground bg, {bool defaultIsLight = false}) {
  final color = dominantColor(bg);
  if (color == null) return defaultIsLight;
  return color.computeLuminance() < 0.35;
}

/// Adapt a [ThemeData] so that all text/icon AND surface colors are readable
/// on [bg]. For solid colors and gradients the luminance is computed; for
/// image backgrounds the semi-transparent overlay handles contrast so the
/// theme is returned unchanged.
ThemeData adaptThemeForBackground(ThemeData theme, AppBackground bg) {
  final color = dominantColor(bg);
  if (color == null) return theme; // image bg — keep as-is

  final lightBg = color.computeLuminance() > 0.35;

  final textColor = lightBg ? const Color(0xFF1A1A1A) : const Color(0xFFF2F0EB);
  final subColor  = lightBg ? const Color(0xFF5A5A5A) : const Color(0xFFB0ADA8);

  // Card / dialog surface: derive from the background color itself so the
  // card surface is always consistent regardless of which app theme is active.
  // Light bg → near-white card; dark bg → slightly elevated dark card.
  final surfaceColor = lightBg
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.90), color)
      : Color.alphaBlend(Colors.white.withValues(alpha: 0.10), color);

  final cardBorderColor = lightBg
      ? const Color(0xFF000000).withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.10);

  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      surface: surfaceColor,
      onSurface: textColor,
      onSurfaceVariant: subColor,
      outline: subColor,
      outlineVariant: subColor.withValues(alpha: 0.4),
    ),
    textTheme: theme.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    ),
    // Explicitly update cardTheme so Card widgets pick up the right surface
    // color even if they don't re-read colorScheme.surface directly.
    cardTheme: theme.cardTheme.copyWith(
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
    ),
  );
}

// ── Note background resolution ────────────────────────────────────────────────
// Returns the effective AppBackground for a specific entry's view/read mode.
// Priority: note image → note preset → journal-level → global backgroundProvider.
AppBackground resolveNoteBackground({
  required String? noteBgPresetId,
  required String? noteBgImagePath,
  required AppBackground journalOrGlobalBackground,
}) {
  if (noteBgImagePath != null && noteBgImagePath.isNotEmpty && File(noteBgImagePath).existsSync()) {
    return AppBackground.image(noteBgImagePath);
  }
  if (noteBgPresetId != null && noteBgPresetId.isNotEmpty) {
    try {
      final preset = kBackgroundPresets.firstWhere((p) => p.id == noteBgPresetId);
      return preset.background;
    } catch (_) {}
  }
  return journalOrGlobalBackground;
}

// ── Journal background resolution ────────────────────────────────────────────
// Returns the effective AppBackground for a journal's reading view.
// Priority: journal-specific (preset or image) → global backgroundProvider.
AppBackground resolveJournalBackground({
  required String? presetId,
  required String? imagePath,
  required AppBackground globalBackground,
}) {
  // Custom image background takes highest priority
  if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
    return AppBackground.image(imagePath);
  }
  // Preset background
  if (presetId != null && presetId.isNotEmpty) {
    try {
      final preset = kBackgroundPresets.firstWhere((p) => p.id == presetId);
      return preset.background;
    } catch (_) {}
  }
  // Fall back to global setting
  return globalBackground;
}
