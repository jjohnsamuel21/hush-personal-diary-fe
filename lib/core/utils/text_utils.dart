import '../constants/app_constants.dart';

class TextUtils {
  /// Counts words in [text] by splitting on whitespace.
  static int countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// Converts [wordCount] to estimated reading time in seconds.
  static int readingTimeSec(int wordCount) {
    if (wordCount == 0) return 0;
    return ((wordCount / AppConstants.avgReadingWpm) * 60).ceil();
  }

  /// Formats reading time for display, e.g. "< 1 min", "2 min read".
  static String formatReadingTime(int seconds) {
    if (seconds < 60) return '< 1 min read';
    final minutes = (seconds / 60).round();
    return '$minutes min read';
  }

  /// Generates an auto-title from the first line of [plaintext].
  /// Falls back to a date string if the note is empty.
  static String autoTitle(String plaintext, DateTime date) {
    // Normalise: collapse all whitespace-only lines, trim surrounding space.
    final firstLine = plaintext
        .replaceAll('\r', '')
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) {
      return 'Entry — ${date.day}/${date.month}/${date.year}';
    }
    // Truncate to 60 characters
    return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
  }
}
