import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/font_constants.dart';

// Persists and exposes the globally selected note font.
// Individual notes can override this via Note.fontFamily.
class FontNotifier extends StateNotifier<NoteFont> {
  FontNotifier() : super(NoteFont.merriweather) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefGlobalFont);
    state = noteFontFromString(saved);
  }

  Future<void> setFont(NoteFont font) async {
    state = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefGlobalFont, font.label);
  }
}

final fontProvider = StateNotifierProvider<FontNotifier, NoteFont>(
  (_) => FontNotifier(),
);
