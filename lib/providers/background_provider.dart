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
