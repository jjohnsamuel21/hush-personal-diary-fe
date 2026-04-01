import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/theme_constants.dart';

const _keyPageStyle = 'page_style';

class PageStyleNotifier extends StateNotifier<PageStyle> {
  PageStyleNotifier() : super(PageStyle.blank) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyPageStyle) ?? 'blank';
    state = _fromString(saved);
  }

  Future<void> setStyle(PageStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPageStyle, style.name);
    state = style;
  }

  PageStyle _fromString(String value) {
    switch (value) {
      case 'ruled':  return PageStyle.ruled;
      case 'dotted': return PageStyle.dotted;
      case 'grid':   return PageStyle.grid;
      default:       return PageStyle.blank;
    }
  }
}

final pageStyleProvider =
    StateNotifierProvider<PageStyleNotifier, PageStyle>(
  (ref) => PageStyleNotifier(),
);
