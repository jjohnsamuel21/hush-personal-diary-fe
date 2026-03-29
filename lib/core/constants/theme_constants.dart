import 'package:flutter/material.dart';

// Page background style options — the "texture" behind note text
enum PageStyle { blank, ruled, dotted, grid }

// A single Hush theme — holds all colors, fonts, and page style for one theme.
// main.dart converts this into Flutter's ThemeData.
class HushTheme {
  final String id;
  final String name;
  final Color background;       // App scaffold background
  final Color surface;          // Cards, app bar
  final Color primary;          // Buttons, accents, FAB
  final Color accent;           // Highlight color
  final Color textPrimary;      // Main body text
  final Color textSecondary;    // Subtitles, captions
  final Color pageBackground;   // The "paper" color in the book view
  final Color pageLines;        // Ruled line color on the page
  final String bodyFont;        // Font for note body text
  final String headingFont;     // Font for headings
  final PageStyle pageStyle;    // Blank / ruled / dotted / grid

  const HushTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.pageBackground,
    required this.pageLines,
    required this.bodyFont,
    required this.headingFont,
    required this.pageStyle,
  });
}

// All available themes. ThemePicker displays this list.
const List<HushTheme> kHushThemes = [
  HushTheme(
    id: 'classic-light',
    name: 'Classic',
    background: Color(0xFFF9F7F4),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF5C6BC0),
    accent: Color(0xFF7986CB),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF757575),
    pageBackground: Color(0xFFFFFDE7),
    pageLines: Color(0xFFE0D7C5),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.ruled,
  ),
  HushTheme(
    id: 'midnight',
    name: 'Midnight',
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    primary: Color(0xFF7C4DFF),
    accent: Color(0xFFB39DDB),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: Color(0xFF9E9E9E),
    pageBackground: Color(0xFF1A1A2E),
    pageLines: Color(0xFF2A2A3E),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.ruled,
  ),
  HushTheme(
    id: 'parchment',
    name: 'Parchment',
    background: Color(0xFFF5ECD7),
    surface: Color(0xFFEDE0C4),
    primary: Color(0xFF795548),
    accent: Color(0xFFA1887F),
    textPrimary: Color(0xFF3E2723),
    textSecondary: Color(0xFF6D4C41),
    pageBackground: Color(0xFFFFF8E1),
    pageLines: Color(0xFFD7CCC8),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.ruled,
  ),
  HushTheme(
    id: 'sakura',
    name: 'Sakura',
    background: Color(0xFFFCE4EC),
    surface: Color(0xFFF8BBD9),
    primary: Color(0xFFE91E63),
    accent: Color(0xFFF48FB1),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF757575),
    pageBackground: Color(0xFFFFF0F5),
    pageLines: Color(0xFFF8BBD9),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.dotted,
  ),
  HushTheme(
    id: 'ocean',
    name: 'Ocean',
    background: Color(0xFFE3F2FD),
    surface: Color(0xFFBBDEFB),
    primary: Color(0xFF1565C0),
    accent: Color(0xFF42A5F5),
    textPrimary: Color(0xFF0D1B2A),
    textSecondary: Color(0xFF37474F),
    pageBackground: Color(0xFFF0F8FF),
    pageLines: Color(0xFFB3D9F7),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.ruled,
  ),
  HushTheme(
    id: 'forest',
    name: 'Forest',
    background: Color(0xFFE8F5E9),
    surface: Color(0xFFC8E6C9),
    primary: Color(0xFF2E7D32),
    accent: Color(0xFF66BB6A),
    textPrimary: Color(0xFF1B2A1C),
    textSecondary: Color(0xFF388E3C),
    pageBackground: Color(0xFFF1F8F1),
    pageLines: Color(0xFFC8E6C9),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.ruled,
  ),
  HushTheme(
    id: 'slate',
    name: 'Slate',
    background: Color(0xFF263238),
    surface: Color(0xFF37474F),
    primary: Color(0xFF80CBC4),
    accent: Color(0xFF4DB6AC),
    textPrimary: Color(0xFFECEFF1),
    textSecondary: Color(0xFFB0BEC5),
    pageBackground: Color(0xFF2C3E50),
    pageLines: Color(0xFF3A4F5E),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.ruled,
  ),
  HushTheme(
    id: 'rose-gold',
    name: 'Rose Gold',
    background: Color(0xFFFFF5F7),
    surface: Color(0xFFFFE4E8),
    primary: Color(0xFFB5838D),
    accent: Color(0xFFE8A0A8),
    textPrimary: Color(0xFF3D2B2D),
    textSecondary: Color(0xFF8B6163),
    pageBackground: Color(0xFFFFF0F2),
    pageLines: Color(0xFFF5C6CB),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.dotted,
  ),
  HushTheme(
    id: 'noir',
    name: 'Noir',
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    primary: Color(0xFFFFFFFF),
    accent: Color(0xFFCCCCCC),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF888888),
    pageBackground: Color(0xFF0F0F0F),
    pageLines: Color(0xFF1A1A1A),
    bodyFont: 'Merriweather',
    headingFont: 'Lato',
    pageStyle: PageStyle.blank,
  ),
];

// The default theme used on first launch
// Note: can't index a const list in a const expression in Dart,
// so this is declared as a regular final variable.
final HushTheme kDefaultTheme = kHushThemes[0]; // Classic
