import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  await dotenv.load(fileName: '.env');  // Load GIPHY_API_KEY and other secrets
  await IsarService.init();
  await ReminderService.init();
  await SecurityService.init();   // Apply FLAG_SECURE based on saved preference

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

  // Converts a HushTheme into Flutter's ThemeData.
  // All widgets (buttons, cards, text, appbars) automatically pick up these colors
  // without needing to manually style every widget.
  ThemeData _buildThemeData(HushTheme ft, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? ft.surface : ft.background;
    final surfaceColor = isDark ? ft.background : ft.surface;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ft.primary,
        brightness: brightness,
        surface: surfaceColor,
      ),
      textTheme: GoogleFonts.getTextTheme(
        ft.bodyFont,
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: isDark ? ft.textPrimary : ft.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ft.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
