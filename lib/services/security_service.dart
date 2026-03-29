import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app-level security settings:
///   • FLAG_SECURE — blocks screenshots and blanks the app in the recents switcher.
///
/// Default state: screenshots BLOCKED (secure = true).
/// The user can opt-in to allow screenshots via Settings.
///
/// Implementation: calls a native MethodChannel on Android.
/// On other platforms (iOS / desktop) the calls are silently ignored.
class SecurityService {
  static const _keyAllowScreenshots = 'security_allow_screenshots';
  static const _channel = MethodChannel('com.hush.frontend/security');

  /// Call once at startup (after WidgetsFlutterBinding.ensureInitialized).
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final allow = prefs.getBool(_keyAllowScreenshots) ?? false;
    await _apply(allow);
  }

  /// Returns whether screenshots are currently allowed.
  static Future<bool> isScreenshotAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllowScreenshots) ?? false;
  }

  /// Enables or disables screenshot protection and persists the setting.
  static Future<void> setScreenshotAllowed(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowScreenshots, allow);
    await _apply(allow);
  }

  // Calls the native MethodChannel to add/clear FLAG_SECURE.
  // No-op on non-Android platforms.
  static Future<void> _apply(bool allow) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod(
        allow ? 'clearFlagSecure' : 'addFlagSecure',
      );
    } on PlatformException {
      // Fail silently — security is best-effort if native side isn't wired.
    }
  }
}
