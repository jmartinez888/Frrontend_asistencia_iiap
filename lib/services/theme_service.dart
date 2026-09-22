import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAccentColor {
  gxClassic(
    id: 'red',
    displayName: 'GX CLASSIC',
    lightPrimary: Color(0xFFDC2626),
    darkPrimary: Color(0xFFFA2A55),
    lightScaffoldBg: Color(0xFFFFF5F5),
    darkScaffoldBg: Color(0xFF130508),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF1E0B11),
    lightCardBorder: Color(0xFFFED7D7),
    darkCardBorder: Color(0xFF38141D),
    lightContainer: Color(0xFFFEE2E2),
    darkContainer: Color(0xFF4C0519),
    lightGradient: [Color(0xFFDC2626), Color(0xFF991B1B)],
    darkGradient: [Color(0xFF2B0B11), Color(0xFF160508)],
    accentSample: Color(0xFFFA2A55),
  ),
  ultraviolet(
    id: 'purple',
    displayName: 'ULTRAVIOLET',
    lightPrimary: Color(0xFF7C3AED),
    darkPrimary: Color(0xFFA855F7),
    lightScaffoldBg: Color(0xFFFAF5FF),
    darkScaffoldBg: Color(0xFF0C0717),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF170E2B),
    lightCardBorder: Color(0xFFE9D8FD),
    darkCardBorder: Color(0xFF321C5B),
    lightContainer: Color(0xFFEDE9FE),
    darkContainer: Color(0xFF4C1D95),
    lightGradient: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    darkGradient: [Color(0xFF230F38), Color(0xFF11071D)],
    accentSample: Color(0xFFA855F7),
  ),
  cyberpunk(
    id: 'pink',
    displayName: 'CYBERPUNK',
    lightPrimary: Color(0xFFDB2777),
    darkPrimary: Color(0xFFFF2A85),
    lightScaffoldBg: Color(0xFFFDF2F8),
    darkScaffoldBg: Color(0xFF140612),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF200B1E),
    lightCardBorder: Color(0xFFFBCFE8),
    darkCardBorder: Color(0xFF42143D),
    lightContainer: Color(0xFFFCE7F3),
    darkContainer: Color(0xFF831843),
    lightGradient: [Color(0xFFDB2777), Color(0xFF9D174D)],
    darkGradient: [Color(0xFF2D0E25), Color(0xFF160612)],
    accentSample: Color(0xFFFF2A85),
  ),
  verdeSelva(
    id: 'green',
    displayName: 'VERDE SELVA',
    lightPrimary: Color(0xFF2D5E2A),
    darkPrimary: Color(0xFF22C55E),
    lightScaffoldBg: Color(0xFFF0FDF4),
    darkScaffoldBg: Color(0xFF06140A),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF0E2416),
    lightCardBorder: Color(0xFFBBF7D0),
    darkCardBorder: Color(0xFF19472B),
    lightContainer: Color(0xFFDCFCE7),
    darkContainer: Color(0xFF14532D),
    lightGradient: [Color(0xFF2D5E2A), Color(0xFF1E4720)],
    darkGradient: [Color(0xFF122E1C), Color(0xFF08180E)],
    accentSample: Color(0xFF22C55E),
  ),
  electricBlue(
    id: 'blue',
    displayName: 'ELECTRIC BLUE',
    lightPrimary: Color(0xFF2563EB),
    darkPrimary: Color(0xFF38BDF8),
    lightScaffoldBg: Color(0xFFEFF6FF),
    darkScaffoldBg: Color(0xFF060E1D),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF0D1B36),
    lightCardBorder: Color(0xFFBFDBFE),
    darkCardBorder: Color(0xFF1A3566),
    lightContainer: Color(0xFFDBEAFE),
    darkContainer: Color(0xFF1E3A8A),
    lightGradient: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    darkGradient: [Color(0xFF0F1E38), Color(0xFF080F1E)],
    accentSample: Color(0xFF38BDF8),
  ),
  aquaGx(
    id: 'cyan',
    displayName: 'AQUA GX',
    lightPrimary: Color(0xFF0D9488),
    darkPrimary: Color(0xFF2DD4BF),
    lightScaffoldBg: Color(0xFFF0FDFA),
    darkScaffoldBg: Color(0xFF041414),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF092525),
    lightCardBorder: Color(0xFF99F6E4),
    darkCardBorder: Color(0xFF144A4A),
    lightContainer: Color(0xFFCCFBF1),
    darkContainer: Color(0xFF134E4A),
    lightGradient: [Color(0xFF0D9488), Color(0xFF115E59)],
    darkGradient: [Color(0xFF0D2524), Color(0xFF061413)],
    accentSample: Color(0xFF2DD4BF),
  ),
  neonSunset(
    id: 'orange',
    displayName: 'NEON SUNSET',
    lightPrimary: Color(0xFFEA580C),
    darkPrimary: Color(0xFFFB923C),
    lightScaffoldBg: Color(0xFFFFF7ED),
    darkScaffoldBg: Color(0xFF140A04),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF221309),
    lightCardBorder: Color(0xFFFED7AA),
    darkCardBorder: Color(0xFF472510),
    lightContainer: Color(0xFFFFEDD5),
    darkContainer: Color(0xFF7C2D12),
    lightGradient: [Color(0xFFEA580C), Color(0xFF9A3412)],
    darkGradient: [Color(0xFF2E150B), Color(0xFF170A04)],
    accentSample: Color(0xFFFB923C),
  ),
  cyberGold(
    id: 'yellow',
    displayName: 'CYBER GOLD',
    lightPrimary: Color(0xFFCA8A04),
    darkPrimary: Color(0xFFFACC15),
    lightScaffoldBg: Color(0xFFFEFCE8),
    darkScaffoldBg: Color(0xFF141004),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF221C09),
    lightCardBorder: Color(0xFFFEF08A),
    darkCardBorder: Color(0xFF463A10),
    lightContainer: Color(0xFFFEF9C3),
    darkContainer: Color(0xFF713F12),
    lightGradient: [Color(0xFFCA8A04), Color(0xFF854D0E)],
    darkGradient: [Color(0xFF281F08), Color(0xFF140F03)],
    accentSample: Color(0xFFFACC15),
  );

  final String id;
  final String displayName;
  final Color lightPrimary;
  final Color darkPrimary;
  final Color lightScaffoldBg;
  final Color darkScaffoldBg;
  final Color lightCardBg;
  final Color darkCardBg;
  final Color lightCardBorder;
  final Color darkCardBorder;
  final Color lightContainer;
  final Color darkContainer;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
  final Color accentSample;

  const AppAccentColor({
    required this.id,
    required this.displayName,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.lightScaffoldBg,
    required this.darkScaffoldBg,
    required this.lightCardBg,
    required this.darkCardBg,
    required this.lightCardBorder,
    required this.darkCardBorder,
    required this.lightContainer,
    required this.darkContainer,
    required this.lightGradient,
    required this.darkGradient,
    required this.accentSample,
  });

  Color primaryOf(bool isDark) => isDark ? darkPrimary : lightPrimary;
  Color scaffoldBgOf(bool isDark) => isDark ? darkScaffoldBg : lightScaffoldBg;
  Color cardBgOf(bool isDark) => isDark ? darkCardBg : lightCardBg;
  Color cardBorderOf(bool isDark) => isDark ? darkCardBorder : lightCardBorder;
  Color containerOf(bool isDark) => isDark ? darkContainer : lightContainer;
  List<Color> gradientOf(bool isDark) => isDark ? darkGradient : lightGradient;

  static AppAccentColor fromId(String? id) {
    return AppAccentColor.values.firstWhere(
      (c) => c.id == id,
      orElse: () => AppAccentColor.verdeSelva,
    );
  }
}

class ThemeService {
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyThemeMode = 'theme_mode_v3';
  static const String _keyAccentColor = 'selected_accent_color_v3';

  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  static final ValueNotifier<AppAccentColor> accentColorNotifier = ValueNotifier<AppAccentColor>(AppAccentColor.verdeSelva);

  static SharedPreferences? _prefs;

  static bool get isDarkMode => true;
  static AppAccentColor get currentAccent => accentColorNotifier.value;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeModeNotifier.value = ThemeMode.dark;

    final savedAccent = _prefs?.getString(_keyAccentColor);
    accentColorNotifier.value = AppAccentColor.fromId(savedAccent ?? 'green');
  }

  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
    String modeStr = 'dark';
    if (mode == ThemeMode.light) {
      modeStr = 'light';
    } else if (mode == ThemeMode.system) {
      modeStr = 'auto';
    }
    _prefs?.setString(_keyThemeMode, modeStr);
    _prefs?.setBool(_keyDarkMode, mode == ThemeMode.dark);
  }

  static void toggleDarkMode(bool enabled) {
    setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  static void setAccentColor(AppAccentColor color) {
    accentColorNotifier.value = color;
    _prefs?.setString(_keyAccentColor, color.id);
  }

  static Color primaryColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return currentAccent.primaryOf(isDark);
  }

  static Color scaffoldBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return currentAccent.scaffoldBgOf(isDark);
  }

  static Color cardBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return currentAccent.cardBgOf(isDark);
  }

  static Color cardBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return currentAccent.cardBorderOf(isDark);
  }

  static Color containerColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return currentAccent.containerOf(isDark);
  }

  static List<Color> bannerGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return currentAccent.gradientOf(isDark);
  }
}
