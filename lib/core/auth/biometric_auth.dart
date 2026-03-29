import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:local_auth/local_auth.dart';

// Wraps the local_auth package — handles fingerprint, face ID, and PIN fallback.
// All biometric logic goes through this class so it's easy to test/replace.
//
// IMPORTANT: local_auth requires MainActivity to extend FlutterFragmentActivity,
// not FlutterActivity. The biometric prompt is a DialogFragment and needs a
// FragmentManager — FlutterActivity doesn't provide one.
class BiometricAuth {
  static final _auth = LocalAuthentication();

  /// Returns true if the device has biometric hardware and it's configured.
  static Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  /// Shows the system biometric prompt. Returns true if authentication succeeded.
  ///
  /// biometricOnly: false — allows PIN/pattern fallback on devices where
  /// fingerprint scans fail (e.g. wet fingers, MIUI quirks).
  /// stickyAuth: true — prompt stays visible if user switches apps briefly.
  static Future<bool> authenticate({String reason = 'Unlock Hush'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      // Surface the real error in debug builds so failures aren't silent
      if (kDebugMode) {
        // ignore: avoid_print
        print('[BiometricAuth] authenticate() threw: $e');
      }
      return false;
    }
  }
}
