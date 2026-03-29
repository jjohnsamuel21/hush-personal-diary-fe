import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// The three diary fonts supported by Hush.
// Merriweather and Caveat are served by google_fonts at runtime (cached after
// first download). Lato is bundled as a local asset.
enum NoteFont {
  merriweather('Merriweather', 'Serif — classic reading feel'),
  lato('Lato', 'Sans-serif — clean and modern'),
  caveat('Caveat', 'Handwritten — personal and expressive');

  final String label;
  final String description;
  const NoteFont(this.label, this.description);
}

// Returns a TextStyle using the given NoteFont.
// Pass [fontSize] and [color] to override defaults.
TextStyle noteFontStyle(
  NoteFont font, {
  double fontSize = 16,
  Color? color,
  FontWeight fontWeight = FontWeight.normal,
}) {
  switch (font) {
    case NoteFont.merriweather:
      return GoogleFonts.merriweather(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    case NoteFont.lato:
      return TextStyle(
        fontFamily: 'Lato',
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    case NoteFont.caveat:
      return GoogleFonts.caveat(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
  }
}

// SharedPreferences key for the globally selected font.
const String kPrefGlobalFont = 'hush_global_font';

// Maps the font family string stored in Note.fontFamily to a NoteFont.
NoteFont noteFontFromString(String? s) {
  switch (s) {
    case 'Lato':
      return NoteFont.lato;
    case 'Caveat':
      return NoteFont.caveat;
    default:
      return NoteFont.merriweather;
  }
}
