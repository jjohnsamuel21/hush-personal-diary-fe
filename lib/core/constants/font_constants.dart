import 'package:flutter/material.dart';

// The three diary fonts supported by Hush.
// All fonts are bundled as local assets in assets/fonts/ — no internet required.
enum NoteFont {
  merriweather('Merriweather', 'Serif — classic reading feel'),
  lato('Lato', 'Sans-serif — clean and modern'),
  caveat('Caveat', 'Handwritten — personal and expressive');

  final String label;
  final String description;
  const NoteFont(this.label, this.description);
}

// Returns a TextStyle using the given NoteFont.
// All fonts resolve from bundled assets — works offline on first launch.
TextStyle noteFontStyle(
  NoteFont font, {
  double fontSize = 16,
  Color? color,
  FontWeight fontWeight = FontWeight.normal,
}) {
  return TextStyle(
    fontFamily: font.label,   // matches the family name declared in pubspec.yaml
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
  );
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
