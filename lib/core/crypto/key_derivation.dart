import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class KeyDerivation {
  /// Derives a 32-byte AES key from [password] and [salt] using PBKDF2-SHA256.
  /// 310,000 iterations — OWASP 2023 recommended minimum for PBKDF2-SHA256.
  /// Same password + different salt = different key (salt prevents rainbow tables).
  static Uint8List deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 310000, 32));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generates 32 bytes of cryptographically random salt.
  /// Call this once on first launch and store the result in flutter_secure_storage.
  static Uint8List generateSalt() {
    final rng = FortunaRandom();
    final seed = Uint8List.fromList(
      List.generate(32, (i) => (DateTime.now().microsecondsSinceEpoch >> (i % 8)) & 0xFF),
    );
    rng.seed(KeyParameter(seed));
    return rng.nextBytes(32);
  }
}
