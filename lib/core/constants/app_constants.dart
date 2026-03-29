// App-wide constants used across the entire codebase.
// Change a value here and it updates everywhere.

class AppConstants {
  // App identity
  static const String appName = 'Hush';
  static const String defaultFolderName = 'General';

  // Editor auto-save debounce — waits this long after typing stops before saving
  static const int autoSaveDebounceMs = 1500;

  // Search debounce — waits before triggering decryption-based search
  static const int searchDebounceMs = 400;

  // Word count update interval in the editor
  static const int wordCountUpdateMs = 500;

  // Average reading speed (words per minute) — used to calculate reading time
  static const int avgReadingWpm = 200;

  // Max PIN length
  static const int maxPinLength = 6;

  // Secure storage keys
  static const String keyMasterSalt = 'hush_master_salt';
  static const String keyMasterKey = 'hush_master_key';
  static const String keyActiveThemeId = 'hush_active_theme_id';
  static const String keyOnboardingComplete = 'hush_onboarding_complete';
}
