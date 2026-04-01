import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';

/// Auth state: null = not signed in, non-null = signed-in user.
class AuthNotifier extends StateNotifier<AuthUser?> {
  AuthNotifier() : super(null) {
    _loadCached();
  }

  Future<void> _loadCached() async {
    final user = await AuthService.getCachedUser();
    if (mounted) state = user;
  }

  /// Launches the Google sign-in flow. Returns true on success.
  Future<bool> signIn() async {
    final user = await AuthService.signIn();
    if (user != null) {
      state = user;
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = null;
  }

  /// Re-fetches the user profile from the backend.
  Future<void> refresh() async {
    final user = await AuthService.refreshUser();
    if (user != null && mounted) state = user;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthUser?>(
  (ref) => AuthNotifier(),
);

/// Convenience: true if the user is signed in with Google.
final isGoogleSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authProvider) != null,
);
