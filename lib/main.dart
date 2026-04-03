import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/database/isar_service.dart';
import 'services/reminder_service.dart';
import 'services/security_service.dart';
import 'core/constants/theme_constants.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // Increase image cache to 150 MB so GIFs and backgrounds don't get evicted.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  await IsarService.init();
  await ReminderService.init();
  await SecurityService.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone =
      prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteProvider.overrideWithValue(onboardingDone),
      ],
      child: const HushApp(),
    ),
  );
}

class HushApp extends ConsumerWidget {
  const HushApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final hushTheme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Hush',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _buildThemeData(hushTheme, Brightness.light),
      darkTheme: _buildThemeData(hushTheme, Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }

  ThemeData _buildThemeData(HushTheme ft, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? ft.surface : ft.background;
    final surfaceColor = isDark ? ft.background : ft.surface;
    final seedColor = ft.primary;

    // Editorial text theme: DM Serif Display for large text, body font for the rest
    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    // Apply body font + explicit text colors to the entire text theme.
    // Using apply(bodyColor/displayColor) ensures every Text() widget gets
    // the theme's hand-tuned colors regardless of what colorScheme generates.
    // Fonts are bundled as assets — no internet required.
    final textTheme = baseTextTheme
        .apply(
          fontFamily: ft.bodyFont,
          bodyColor: ft.textPrimary,
          displayColor: ft.textPrimary,
        )
        .copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: ft.headingFont,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontFamily: ft.headingFont,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontFamily: ft.headingFont,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: ft.headingFont,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: ft.headingFont,
        fontWeight: FontWeight.w400,
      ),
    );

    // ColorScheme.fromSeed auto-generates onSurface/onSurfaceVariant from the
    // seed color — on real devices those tonal colors can be near-invisible
    // against the background. Override them explicitly with the theme's
    // hand-tuned text colors so text is always legible on every device.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: surfaceColor,
    ).copyWith(
      onSurface: ft.textPrimary,
      onSurfaceVariant: ft.textSecondary,
      onBackground: ft.textPrimary,
      outline: ft.textSecondary,
      outlineVariant: ft.textSecondary.withValues(alpha: 0.4),
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      colorScheme: colorScheme,
      textTheme: textTheme,

      // ── AppBar: borderless, minimal ──────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: ft.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _headingFontFamily(ft.headingFont),
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: ft.textPrimary,
          letterSpacing: 0,
        ),
      ),

      // ── Cards: generous radius, minimal shadow ───────────────────────────
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── FAB: pill/stadium shape ──────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ft.primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      ),

      // ── Filled buttons: stadium ──────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Outlined buttons ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ── Text buttons ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ── Input fields: filled, rounded ────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: const TextStyle(fontSize: 13),
      ),

      // ── List tiles ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minLeadingWidth: 24,
        iconColor: colorScheme.onSurfaceVariant,
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),

      // ── Navigation bar ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
      ),

      // ── Tab bar ──────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w400),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
    );
  }

  // Fonts are declared as local assets in pubspec.yaml — return the family name directly.
  String? _headingFontFamily(String fontName) => fontName;
}
