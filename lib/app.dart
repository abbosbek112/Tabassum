import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router.dart';
import 'core/providers.dart';
import 'core/twa_service.dart';

// Optimization: Pre-initialize shared theme parts
final _baseTextTheme = Typography.material2021().black;
final _appTextTheme = GoogleFonts.outfitTextTheme(_baseTextTheme);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twaService = ref.watch(twaServiceProvider);
    final themeState = ref.watch(themeModeProvider);
    final router = ref.watch(goRouterProvider);

    // Initial TWA setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (twaService.isSupported) {
        twaService.ready();
        twaService.expand();
      }
    });

    // Reactive Theme Mode Selection
    // Only use TWA dark mode if the user hasn't explicitly chosen light/dark
    ThemeMode themeMode = themeState;
    if (themeState == ThemeMode.system && twaService.isSupported) {
      themeMode = twaService.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }

    return MaterialApp.router(
      title: 'Tabassum',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

// Premium Modern Light Theme
final _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF8F9FA), 
  primaryColor: const Color(0xFF0F172A), 
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F172A),
    primary: const Color(0xFF0F172A),
    secondary: const Color(0xFF475569),
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF0F172A),
    error: const Color(0xFFEF4444),
  ),
  textTheme: _appTextTheme.copyWith(
    displayLarge: _appTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -1.5),
    displayMedium: _appTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -1.0),
    titleLarge: _appTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), letterSpacing: -0.5),
    titleMedium: _appTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
    titleSmall: _appTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
    bodyLarge: _appTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400, color: const Color(0xFF334155)),
    bodyMedium: _appTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400, color: const Color(0xFF475569)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF0F172A),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    actionsIconTheme: IconThemeData(color: Color(0xFF0F172A)),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      side: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.5), width: 1),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF2F2F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1),
    ),
    hintStyle: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontWeight: FontWeight.w400),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    indicatorColor: const Color(0xFF0F172A).withOpacity(0.1),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w700);
      }
      return GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500);
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const IconThemeData(color: Color(0xFF0F172A));
      return const IconThemeData(color: Color(0xFF64748B));
    }),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFE5E5EA),
    thickness: 0.5,
    space: 1,
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
); 

// Professional Dark Theme — "Graphite Night"
final _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF111318), // Deep graphite, not pure black
  primaryColor: const Color(0xFF818CF8), // Indigo accent
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF818CF8),       // Indigo 400
    onPrimary: Colors.white,
    secondary: Color(0xFF6EE7B7),     // Emerald 300
    onSecondary: Color(0xFF064E3B),
    error: Color(0xFFF87171),
    onError: Colors.white,
    surface: Color(0xFF1C1F27),       // Card surface
    onSurface: Color(0xFFF1F5F9),
    surfaceContainerHighest: Color(0xFF252930),  // Elevated surface
    outline: Color(0xFF2E3340),       // Dividers/borders
  ),
  textTheme: _appTextTheme.copyWith(
    displayLarge: _appTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFFF8FAFC), letterSpacing: -1.5),
    displayMedium: _appTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFFF8FAFC), letterSpacing: -1.0),
    titleLarge: _appTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFFF1F5F9), letterSpacing: -0.5),
    titleMedium: _appTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFFE2E8F0)),
    titleSmall: _appTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
    bodyLarge: _appTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400, color: const Color(0xFFCBD5E1)),
    bodyMedium: _appTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400, color: const Color(0xFF94A3B8)),
    bodySmall: _appTextTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF111318),
    foregroundColor: const Color(0xFFF1F5F9),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
    actionsIconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
    titleTextStyle: GoogleFonts.outfit(color: const Color(0xFFF1F5F9), fontSize: 18, fontWeight: FontWeight.w700),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1C1F27),
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      side: const BorderSide(color: Color(0xFF2E3340), width: 1),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF818CF8),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF252930),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF2E3340), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF2E3340), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
    ),
    hintStyle: GoogleFonts.inter(color: const Color(0xFF4B5563), fontWeight: FontWeight.w400),
    labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF94A3B8)),
    trackColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? const Color(0xFF818CF8) : const Color(0xFF2E3340)),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF252930),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    tileColor: Colors.transparent,
    iconColor: Color(0xFF94A3B8),
  ),
);

