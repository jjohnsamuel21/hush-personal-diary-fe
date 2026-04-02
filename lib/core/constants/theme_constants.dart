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
  final String defaultBackgroundPresetId; // ID from kBackgroundPresets auto-applied with theme

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
    required this.defaultBackgroundPresetId,
  });
}

// Four curated mood themes — each with full color + font coordination.
// Design principle: each theme has a distinct mood, cohesive palette, and
// editorial font pairing (DM Serif Display headings + DM Sans body).
const List<HushTheme> kHushThemes = [

  // ── Hush ─────────────────────────────────────────────────────────────────
  // Warm cream + sage green — inspired by the logo palette.
  // Calm, editorial, timeless. The default.
  HushTheme(
    id: 'hush',
    name: 'Hush',
    background: Color(0xFFF7F5F0),   // warm off-white cream
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF4A7B5F),      // sage green (logo color)
    accent: Color(0xFFC9A96E),       // warm gold (logo color)
    textPrimary: Color(0xFF2D2D2D),  // dark charcoal (logo color)
    textSecondary: Color(0xFF7A7A6A),
    pageBackground: Color(0xFFFDFBF7),
    pageLines: Color(0xFFE8E2D9),
    bodyFont: 'DM Sans',
    headingFont: 'DM Serif Display',
    pageStyle: PageStyle.blank,
    defaultBackgroundPresetId: 'parchment', // warm parchment matches Hush warmth
  ),

  // ── Midnight ─────────────────────────────────────────────────────────────
  // Deep navy + warm gold — noir, intimate, sophisticated.
  HushTheme(
    id: 'midnight',
    name: 'Midnight',
    background: Color(0xFF0F1117),   // near-black navy
    surface: Color(0xFF1A1D26),      // dark surface
    primary: Color(0xFFC9A96E),      // warm gold — accent on dark
    accent: Color(0xFFE8C98A),       // lighter gold
    textPrimary: Color(0xFFF0EDE8),  // warm white
    textSecondary: Color(0xFF8A8A9A),
    pageBackground: Color(0xFF12151E),
    pageLines: Color(0xFF1E2133),
    bodyFont: 'DM Sans',
    headingFont: 'DM Serif Display',
    pageStyle: PageStyle.blank,
    defaultBackgroundPresetId: 'midnight', // deep dark matches Midnight mood
  ),

  // ── Forest ────────────────────────────────────────────────────────────────
  // Deep greens + amber — earthy, grounded, organic.
  HushTheme(
    id: 'forest',
    name: 'Forest',
    background: Color(0xFFF0F7EE),   // pale sage
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF2D6A4F),      // deep forest green
    accent: Color(0xFF74C69D),       // fresh mint
    textPrimary: Color(0xFF1A2E20),  // near-black green
    textSecondary: Color(0xFF52796F),
    pageBackground: Color(0xFFF5FBF3),
    pageLines: Color(0xFFCAE6C8),
    bodyFont: 'DM Sans',
    headingFont: 'DM Serif Display',
    pageStyle: PageStyle.blank,
    defaultBackgroundPresetId: 'forest', // soft green matches Forest earthy feel
  ),

  // ── Ocean ─────────────────────────────────────────────────────────────────
  // Slate blue + cyan — serene, coastal, clear-headed.
  HushTheme(
    id: 'ocean',
    name: 'Ocean',
    background: Color(0xFFEEF4FB),   // pale sky blue
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF0277BD),      // deep ocean blue
    accent: Color(0xFF29B6F6),       // bright cyan
    textPrimary: Color(0xFF0D1B2A),  // deep navy
    textSecondary: Color(0xFF455A6A),
    pageBackground: Color(0xFFF5FAFE),
    pageLines: Color(0xFFB8D8F0),
    bodyFont: 'DM Sans',
    headingFont: 'DM Serif Display',
    pageStyle: PageStyle.blank,
    defaultBackgroundPresetId: 'ocean', // pale blue matches Ocean serenity
  ),
];

// The default theme used on first launch
final HushTheme kDefaultTheme = kHushThemes[0]; // Hush
