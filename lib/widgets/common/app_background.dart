import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/background_provider.dart';

/// Wraps a child with the user-selected app background
/// (solid color, gradient, or local image).
///
/// Use as the `body` of any top-level Scaffold that should respect the
/// background setting:
///   body: AppBackgroundWrapper(child: YourContent()),
///
/// Screens that have their own styled background (BookScreen page texture,
/// LockScreen) should NOT wrap — they manage their own background.
class AppBackgroundWrapper extends ConsumerWidget {
  final Widget child;
  const AppBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ref.watch(backgroundProvider);

    switch (bg.type) {
      case AppBackgroundType.image:
        if (bg.imagePath != null && File(bg.imagePath!).existsSync()) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(bg.imagePath!),
                fit: BoxFit.cover,
              ),
              // Semi-transparent overlay so text remains readable
              Container(color: Colors.black.withValues(alpha: 0.15)),
              child,
            ],
          );
        }
        // File missing — fall through to default color
        return child;

      case AppBackgroundType.gradient:
        final colors = bg.gradientColors ?? [const Color(0xFFF9F7F4), const Color(0xFFEEEEEE)];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: child,
        );

      case AppBackgroundType.color:
        final color = bg.color ?? const Color(0xFFF9F7F4);
        return Container(color: color, child: child);
    }
  }
}
