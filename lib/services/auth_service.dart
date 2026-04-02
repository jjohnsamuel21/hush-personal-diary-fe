import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/auth_user.dart';

/// Handles Google Sign-In, JWT storage, and the /auth/* backend calls.
///
/// SETUP REQUIRED:
///   1. Create a project in Google Cloud Console.
///   2. Enable the Google Sign-In API and create an OAuth 2.0 client ID
///      (Android package name: com.example.hush).
///   3. Download google-services.json and place it in android/app/.
///   4. Add your Web Client ID to .env as GOOGLE_CLIENT_ID (used by the
///      backend to verify idTokens).
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyJwt = 'hush_google_jwt';
  static const _keyUser = 'hush_google_user_json';

  static String get _baseUrl =>
      dotenv.env['HUSH_API_URL'] ?? 'http://10.0.2.2:8000';

  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  // ── Sign in ───────────────────────────────────────────────────────────────

  /// Launches the Google account picker, exchanges the idToken with the
  /// Hush backend, stores the JWT, and returns the [AuthUser].
  ///
  /// Returns null if the user cancels or any step fails.
  static Future<AuthUser?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      // Try backend JWT exchange first (works when backend is reachable).
      // Falls back to building the user directly from the Google account so
      // sign-in works on physical devices even when the dev backend is offline.
      try {
        final auth = await account.authentication;
        final idToken = auth.idToken;
        if (idToken != null) {
          final response = await http.post(
            Uri.parse('$_baseUrl/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'google_id_token': idToken}),
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final jwt = data['access_token'] as String;
            final user =
                AuthUser.fromJson(data['user'] as Map<String, dynamic>);
            await _storage.write(key: _keyJwt, value: jwt);
            await _storage.write(key: _keyUser, value: user.toJsonString());
            return user;
          }
        }
      } catch (_) {
        // Backend unreachable (dev server, emulator-only IP, no network, etc.)
        // Fall through to local-only sign-in below.
      }

      // Local-only: build AuthUser directly from the Google account.
      // No JWT is stored — backend-dependant features (shared notes sync) will
      // silently no-op until the backend is reachable.
      final user = AuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        avatarUrl: account.photoUrl,
      );
      await _storage.write(key: _keyUser, value: user.toJsonString());
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Signs out from Google and clears the stored JWT.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.delete(key: _keyJwt);
    await _storage.delete(key: _keyUser);
  }

  // ── Token & user accessors ────────────────────────────────────────────────

  static Future<String?> getToken() => _storage.read(key: _keyJwt);

  static Future<bool> isSignedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Returns the cached [AuthUser] without a network call. Returns null if
  /// the user has never signed in on this device.
  static Future<AuthUser?> getCachedUser() async {
    final json = await _storage.read(key: _keyUser);
    if (json == null) return null;
    try {
      return AuthUser.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  // ── Profile refresh ───────────────────────────────────────────────────────

  /// Fetches the current user profile from the backend and updates the cache.
  static Future<AuthUser?> refreshUser() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return null;

      final user = AuthUser.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
      await _storage.write(key: _keyUser, value: user.toJsonString());
      return user;
    } catch (_) {
      return null;
    }
  }
}
