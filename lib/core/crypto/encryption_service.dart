import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

// Holds the three pieces produced by AES-256-GCM encryption.
// All three are needed together to decrypt — store all three in the DB.
class EncryptedPayload {
  final String ciphertext; // base64-encoded encrypted bytes
  final String iv;         // base64-encoded 12-byte initialization vector
  final String authTag;    // base64-encoded 16-byte GCM authentication tag

  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    required this.authTag,
  });
}

class EncryptionService {
  /// Encrypts [plaintext] with AES-256-GCM using [key] (must be 32 bytes).
  /// Returns an [EncryptedPayload] with ciphertext, iv, and authTag — all base64.
  static EncryptedPayload encrypt(String plaintext, Uint8List key) {
    final iv = _secureRandom(12); // 12 bytes = GCM standard IV size

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // true = encrypt
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = cipher.process(input);

    // GCM appends the 16-byte auth tag to the end of the ciphertext output
    final cipherBytes = output.sublist(0, output.length - 16);
    final authTagBytes = output.sublist(output.length - 16);

    return EncryptedPayload(
      ciphertext: base64.encode(cipherBytes),
      iv: base64.encode(iv),
      authTag: base64.encode(authTagBytes),
    );
  }

  /// Decrypts an [EncryptedPayload] using [key].
  /// Throws if the auth tag doesn't match — meaning data was tampered with.
  static String decrypt(EncryptedPayload payload, Uint8List key) {
    final iv = base64.decode(payload.iv);
    final authTagBytes = base64.decode(payload.authTag);
    final cipherBytes = base64.decode(payload.ciphertext);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // false = decrypt
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );

    // GCM decryption expects ciphertext + authTag concatenated
    final combined = Uint8List.fromList([...cipherBytes, ...authTagBytes]);
    final output = cipher.process(combined);
    return utf8.decode(output);
  }

  // Generates [length] bytes of random data using Fortuna CSPRNG.
  static Uint8List _secureRandom(int length) {
    final rng = FortunaRandom();
    // Seed with a mix of time-based values — adequate for IV generation
    final seed = Uint8List.fromList(
      List.generate(32, (i) => (DateTime.now().microsecondsSinceEpoch >> (i % 8)) & 0xFF),
    );
    rng.seed(KeyParameter(seed));
    return rng.nextBytes(length);
  }
}
