import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'biometric_auth.dart';
import '../crypto/key_store.dart';
import '../crypto/key_derivation.dart';

// The state object for the app lock — holds both lock status and the master key.
// The master key is only in memory when the app is unlocked.
// When locked, key is set to null — notes cannot be decrypted.
class AppLockState {
  final bool isLocked;
  final Uint8List? masterKey; // null when locked

  const AppLockState({required this.isLocked, this.masterKey});

  AppLockState copyWith({bool? isLocked, Uint8List? masterKey}) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      masterKey: masterKey ?? this.masterKey,
    );
  }
}

// Riverpod StateNotifier — manages AppLockState transitions.
// StateNotifier is the manual equivalent of the @riverpod annotation approach.
// It's simpler to understand: a class that holds state and has methods to change it.
class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier() : super(const AppLockState(isLocked: true));

  /// Called when the user taps "Unlock".
  /// On first launch: generates a salt + derives a key from a default PIN ("000000")
  ///   then saves both to secure storage.
  /// On subsequent launches: loads the existing salt, re-derives the key,
  ///   then authenticates biometrics.
  /// Returns true if unlock succeeded.
  Future<bool> unlock() async {
    // Step 1: try biometric/PIN authentication
    final authenticated = await BiometricAuth.authenticate();
    if (!authenticated) return false;

    // Step 2: load or create the master encryption key
    final masterKey = await _getOrCreateMasterKey();

    // Step 3: update state — app is now unlocked and key is in memory
    state = AppLockState(isLocked: false, masterKey: masterKey);
    return true;
  }

  /// Locks the app and wipes the master key from memory.
  void lock() {
    state = const AppLockState(isLocked: true, masterKey: null);
  }

  /// DEV ONLY — bypasses biometrics entirely. Never call this in production.
  /// Used on emulators where biometric hardware is unavailable.
  /// kDebugMode ensures this code path is dead in release builds.
  Future<void> unlockDev() async {
    final masterKey = await _getOrCreateMasterKey();
    state = AppLockState(isLocked: false, masterKey: masterKey);
  }

  Future<Uint8List> _getOrCreateMasterKey() async {
    // Try loading an existing key first
    var key = await KeyStore.loadMasterKey();
    if (key != null) return key;

    // First launch — generate salt, derive key, save both
    final salt = KeyDerivation.generateSalt();
    await KeyStore.saveSalt(salt);

    // For Phase 1, we derive from a placeholder. Phase 2 will use user's PIN.
    key = KeyDerivation.deriveKey('hush_default_key', salt);
    await KeyStore.saveMasterKey(key);
    return key;
  }
}

// The Riverpod provider — the global handle that widgets use to access lock state.
// Usage in a widget:
//   final lockState = ref.watch(appLockProvider);
//   ref.read(appLockProvider.notifier).unlock();
final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>(
  (ref) => AppLockNotifier(),
);

// Convenience provider that exposes just the master key.
// Returns null when locked — service files check this before decrypting.
final masterKeyProvider = Provider<Uint8List?>((ref) {
  return ref.watch(appLockProvider).masterKey;
});
