import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/api_config.dart';
import 'services/theme_service.dart';
import 'services/wallpaper_service.dart';
import 'services/storage_service.dart';
import 'services/schedule_service.dart';
import 'screens/splash_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Asegurar que la barra superior del celular (batería, hora, internet) NUNCA se oculte en toda la app
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  await ThemeService.init();
  await WallpaperService.init();
  await ApiConfig.init();
  await StorageService.init();
  await ScheduleService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.themeModeNotifier,
        ThemeService.accentColorNotifier,
        WallpaperService.wallpaperNotifier,
      ]),
      builder: (context, _) {
        final currentMode = ThemeService.themeModeNotifier.value;
        final accent = ThemeService.currentAccent;
        final hasWallpaper = WallpaperService.currentWallpaper.hasWallpaper;

        return MaterialApp(
          title: 'IIAP Asistencia',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: accent.lightPrimary,
            scaffoldBackgroundColor: hasWallpaper
                ? Colors.transparent
                : accent.lightScaffoldBg,
            cardColor: accent.lightCardBg,
            dividerColor: accent.lightCardBorder,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent.lightPrimary,
              primary: accent.lightPrimary,
              secondary: accent.accentSample,
              surface: accent.lightCardBg,
              onSurface: const Color(0xFF0F172A),
              primaryContainer: accent.lightContainer,
              brightness: Brightness.light,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: accent.lightCardBg,
              indicatorColor: accent.lightContainer,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: accent.lightCardBg,
              foregroundColor: accent.lightPrimary,
              elevation: 0.5,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: accent.darkPrimary,
            scaffoldBackgroundColor: hasWallpaper
                ? Colors.transparent
                : accent.darkScaffoldBg,
            cardColor: accent.darkCardBg,
            dividerColor: accent.darkCardBorder,
            colorScheme: ColorScheme.dark(
              primary: accent.darkPrimary,
              secondary: accent.accentSample,
              surface: accent.darkCardBg,
              onSurface: Colors.white,
              primaryContainer: accent.darkContainer,
              onPrimary: Colors.black,
              brightness: Brightness.dark,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: accent.darkCardBg,
              indicatorColor: accent.darkContainer,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: accent.darkCardBg,
              foregroundColor: Colors.white,
              elevation: 0.5,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              ),
            ),
            useMaterial3: true,
          ),
          builder: (context, child) {
            return WallpaperService.buildBackgroundContainer(
              context: context,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashGateScreen(),
        );
      },
    );
  }
}
