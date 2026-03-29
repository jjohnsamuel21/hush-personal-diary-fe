import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

// Wraps flutter_secure_storage for saving/loading the master encryption key.
// On Android, flutter_secure_storage uses the Android Keystore — hardware-backed
// on modern devices. The key bytes are stored as base64.
class KeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Saves the 32-byte master key to secure storage.
  static Future<void> saveMasterKey(Uint8List key) async {
    await _storage.write(
      key: AppConstants.keyMasterKey,
      value: base64.encode(key),
    );
  }

  /// Loads the master key from secure storage.
  /// Returns null if not found (first launch before key is set).
  static Future<Uint8List?> loadMasterKey() async {
    final encoded = await _storage.read(key: AppConstants.keyMasterKey);
    if (encoded == null) return null;
    return base64.decode(encoded);
  }

  /// Saves the salt used for PBKDF2 key derivation.
  /// Generated once on first launch, stored permanently.
  static Future<void> saveSalt(Uint8List salt) async {
    await _storage.write(
      key: AppConstants.keyMasterSalt,
      value: base64.encode(salt),
    );
  }

  /// Loads the salt. Returns null if this is the first launch.
  static Future<Uint8List?> loadSalt() async {
    final encoded = await _storage.read(key: AppConstants.keyMasterSalt);
    if (encoded == null) return null;
    return base64.decode(encoded);
  }

  /// Wipes the key and salt from secure storage.
  /// Called on app reset or when the user changes their PIN.
  static Future<void> clearAll() async {
    await _storage.delete(key: AppConstants.keyMasterKey);
    await _storage.delete(key: AppConstants.keyMasterSalt);
  }
}
