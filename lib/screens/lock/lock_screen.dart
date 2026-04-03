import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/auth/biometric_auth.dart';

// The first screen the user sees every time they open the app.
// Shows the Hush logo and an unlock button.
// ConsumerWidget = a StatelessWidget that can also read Riverpod providers.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _isUnlocking = false;
  bool _biometricAvailable = true; // assume true until checked

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricAuth.isAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _handleUnlock() async {
    setState(() => _isUnlocking = true);

    final success = await ref.read(appLockProvider.notifier).unlock();

    if (!mounted) return;
    setState(() => _isUnlocking = false);

    if (success) {
      // Navigate to home — go_router replaces the lock screen so pressing back
      // doesn't return to it
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/logo/hush-diary-app-logo.jpeg',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your private diary',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 60),

                // Unlock button — label adapts based on device security
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _isUnlocking ? null : _handleUnlock,
                    icon: _isUnlocking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_biometricAvailable
                            ? Icons.fingerprint
                            : Icons.lock_open_rounded),
                    label: Text(
                      _isUnlocking
                          ? 'Opening…'
                          : (_biometricAvailable
                              ? 'Unlock with Biometric'
                              : 'Open Hush'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                if (!_biometricAvailable) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No device security detected — tap to open.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }
}
