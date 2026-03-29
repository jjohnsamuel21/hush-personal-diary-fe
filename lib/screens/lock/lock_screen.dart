import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_lock_notifier.dart';

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
                // App logo / wordmark
                Icon(
                  Icons.book_rounded,
                  size: 80,
                  color: colors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Hush',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your private diary',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 60),

                // Unlock button
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
                        : const Icon(Icons.fingerprint),
                    label: Text(
                      _isUnlocking ? 'Unlocking…' : 'Unlock with Biometric',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                // DEV ONLY — shown in debug builds only, invisible in release.
                // kDebugMode is a Flutter constant that is false in release builds,
                // so this entire block is compiled out in production.
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(appLockProvider.notifier).unlockDev();
                        if (context.mounted) context.go('/home');
                      },
                      icon: const Icon(Icons.developer_mode, size: 18),
                      label: const Text('Dev: Skip Auth (emulator only)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
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
