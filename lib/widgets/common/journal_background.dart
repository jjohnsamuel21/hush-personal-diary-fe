import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/background_provider.dart';

/// Renders the effective background for the journal reading view and adapts
/// all descendant text/icon colors so any background stays readable.
class JournalBackgroundWrapper extends ConsumerWidget {
  final String? journalPresetId;
  final String? journalImagePath;
  final Widget child;

  const JournalBackgroundWrapper({
    super.key,
    required this.child,
    this.journalPresetId,
    this.journalImagePath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalBg = ref.watch(backgroundProvider);
    final bg = resolveJournalBackground(
      presetId: journalPresetId,
      imagePath: journalImagePath,
      globalBackground: globalBg,
    );

    final adapted = Theme(
      data: adaptThemeForBackground(Theme.of(context), bg),
      child: child,
    );

    switch (bg.type) {
      case AppBackgroundType.image:
        if (bg.imagePath != null && File(bg.imagePath!).existsSync()) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(bg.imagePath!), fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.15)),
              adapted,
            ],
          );
        }
        return adapted;

      case AppBackgroundType.gradient:
        final colors = bg.gradientColors ??
            [const Color(0xFFF9F7F4), const Color(0xFFEEEEEE)];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: adapted,
        );

      case AppBackgroundType.color:
        final color = bg.color ?? const Color(0xFFF9F7F4);
        return Container(color: color, child: adapted);
    }
  }
}
