import 'dart:io';
import 'package:flutter/material.dart';
import 'theme_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WallpaperType { none, preset, custom }

class WallpaperItem {
  final String id;
  final String title;
  final String category; // 'General', 'Chicas', 'Chicos', etc.
  final WallpaperType type;
  final String? assetPath;
  final String? customFilePath;

  const WallpaperItem({
    required this.id,
    required this.title,
    this.category = 'General',
    required this.type,
    this.assetPath,
    this.customFilePath,
  });

  bool get hasWallpaper => type != WallpaperType.none;

  ImageProvider? get imageProvider {
    if (type == WallpaperType.preset && assetPath != null) {
      return AssetImage(assetPath!);
    } else if (type == WallpaperType.custom && customFilePath != null) {
      final file = File(customFilePath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return null;
  }
}

class WallpaperService {
  static const String _keyWallpaperId = 'active_wallpaper_id_v2';
  static const String _keyWallpaperType = 'active_wallpaper_type_v2';
  static const String _keyCustomPath = 'active_wallpaper_custom_path_v2';

  static const WallpaperItem defaultNone = WallpaperItem(
    id: 'none',
    title: 'Color Sólido',
    category: 'General',
    type: WallpaperType.none,
  );

  static const List<WallpaperItem> presets = [
    // SECCIÓN FONDOS OSCUROS & AMOLED (Cyber Matrix, Nebula Abyss, Carbon Fiber, Shadow Ronin)
    WallpaperItem(
      id: 'dark_matrix',
      title: 'CYBER MATRIX OBSIDIAN',
      category: 'Fondos Oscuros',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_dark_matrix.jpg',
    ),
    WallpaperItem(
      id: 'dark_space',
      title: 'NEBULA DARK ABYSS',
      category: 'Fondos Oscuros',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_dark_space.jpg',
    ),
    WallpaperItem(
      id: 'dark_carbon',
      title: 'CARBON FIBER TITANIUM',
      category: 'Fondos Oscuros',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_dark_carbon.jpg',
    ),
    WallpaperItem(
      id: 'dark_samurai',
      title: 'SHADOW RONIN DARK',
      category: 'Fondos Oscuros',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_dark_samurai.jpg',
    ),
    // Seccion ANIMES (Inuyasha, Miyamura, Ichigo, Aizen)
    WallpaperItem(
      id: 'inuyasha_chibi_red',
      title: 'INUYASHA CHIBI RED',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_inuyasha_chibi_red.jpg',
    ),
    WallpaperItem(
      id: 'inuyasha_chibi_black',
      title: 'INUYASHA CHIBI NIGHT',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_inuyasha_chibi_black.jpg',
    ),
    WallpaperItem(
      id: 'ichigo_bankai',
      title: 'ICHIGO BANKAI',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_ichigo_bankai.jpg',
    ),
    WallpaperItem(
      id: 'aizen_throne',
      title: 'LORD AIZEN TRONO',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_aizen_throne.jpg',
    ),
    WallpaperItem(
      id: 'inuyasha_luna',
      title: 'INUYASHA LUNA',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_inuyasha_luna.jpg',
    ),
    WallpaperItem(
      id: 'inuyasha_torii',
      title: 'INUYASHA TORII',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_inuyasha_torii.jpg',
    ),
    WallpaperItem(
      id: 'miyamura_sunset',
      title: 'MIYAMURA ROOFTOP',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_miyamura_sunset.jpg',
    ),
    WallpaperItem(
      id: 'miyamura_winter',
      title: 'MIYAMURA INVIERNO',
      category: 'Animes',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_miyamura_winter.jpg',
    ),
    // Seccion ROJOS (Red Neon Cyber, Seda Rubi)
    WallpaperItem(
      id: 'red_neon',
      title: 'RED NEON CYBER',
      category: 'Rojos',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_red_neon.jpg',
    ),
    WallpaperItem(
      id: 'ruby_silk',
      title: 'SEDA RUBI VELVET',
      category: 'Rojos',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_ruby_silk.jpg',
    ),
    // Para Chicas & Estilo Cute / Anime
    WallpaperItem(
      id: 'pucca',
      title: 'PUCCA CHIC',
      category: 'Chicas',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_pucca.jpg',
    ),
    WallpaperItem(
      id: 'angela',
      title: 'GATITA ANGELA',
      category: 'Chicas',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_angela.jpg',
    ),
    WallpaperItem(
      id: 'anime_girl',
      title: 'ANIME CHICA',
      category: 'Chicas',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_anime_girl.jpg',
    ),
    WallpaperItem(
      id: 'sakura',
      title: 'SAKURA ROSA',
      category: 'Chicas',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_sakura.jpg',
    ),
    // Para Chicos & Cyber / Institucional
    WallpaperItem(
      id: 'gx',
      title: 'GX NEO',
      category: 'Chicos & Gaming',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_gx.jpg',
    ),
    WallpaperItem(
      id: 'ronin',
      title: 'RONIN CYBER',
      category: 'Chicos & Gaming',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_ronin.jpg',
    ),
    WallpaperItem(
      id: 'anime_boy',
      title: 'ANIME HERO',
      category: 'Chicos & Gaming',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_anime_boy.jpg',
    ),
    WallpaperItem(
      id: 'selva',
      title: 'SELVA IIAP',
      category: 'Institucional',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_selva.jpg',
    ),
  ];

  static final ValueNotifier<WallpaperItem> wallpaperNotifier =
      ValueNotifier<WallpaperItem>(defaultNone);

  static SharedPreferences? _prefs;

  static WallpaperItem get currentWallpaper => wallpaperNotifier.value;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedId = _prefs?.getString(_keyWallpaperId) ?? 'none';
    final savedType = _prefs?.getString(_keyWallpaperType) ?? 'none';
    final savedCustomPath = _prefs?.getString(_keyCustomPath);

    if (savedType == 'preset') {
      final found = presets.firstWhere(
        (p) => p.id == savedId,
        orElse: () => defaultNone,
      );
      wallpaperNotifier.value = found;
    } else if (savedType == 'custom' && savedCustomPath != null) {
      final file = File(savedCustomPath);
      if (file.existsSync()) {
        wallpaperNotifier.value = WallpaperItem(
          id: 'custom',
          title: 'Personalizado',
          type: WallpaperType.custom,
          customFilePath: savedCustomPath,
        );
      } else {
        wallpaperNotifier.value = defaultNone;
      }
    } else {
      wallpaperNotifier.value = defaultNone;
    }
  }

  static Future<void> setPreset(WallpaperItem preset) async {
    wallpaperNotifier.value = preset;
    await _prefs?.setString(_keyWallpaperId, preset.id);
    await _prefs?.setString(_keyWallpaperType, 'preset');
    await _prefs?.remove(_keyCustomPath);
  }

  static Future<void> setCustom(String filePath) async {
    final item = WallpaperItem(
      id: 'custom',
      title: 'Personalizado',
      type: WallpaperType.custom,
      customFilePath: filePath,
    );
    wallpaperNotifier.value = item;
    await _prefs?.setString(_keyWallpaperId, 'custom');
    await _prefs?.setString(_keyWallpaperType, 'custom');
    await _prefs?.setString(_keyCustomPath, filePath);
  }

  static Future<void> clearWallpaper() async {
    wallpaperNotifier.value = defaultNone;
    await _prefs?.setString(_keyWallpaperId, 'none');
    await _prefs?.setString(_keyWallpaperType, 'none');
    await _prefs?.remove(_keyCustomPath);
    ThemeService.setAccentColor(AppAccentColor.verdeSelva);
  }

  /// Construye un contenedor con el fondo activo protegido por overlay oscuro
  /// para garantizar que ningún texto, tarjeta o botón pierda legibilidad,
  /// asegurando que la barra de estado superior (batería, hora, red) nunca se oculte.
  static Widget buildBackgroundContainer({
    required BuildContext context,
    required Widget child,
  }) {
    final wallpaper = wallpaperNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Asegurar que la barra superior (Status Bar) del teléfono siempre se muestre con máxima nitidez
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark || wallpaper.hasWallpaper
          ? Brightness.light // Iconos blancos brillantes
          : Brightness.dark, // Iconos oscuros sobre fondo claro
      statusBarBrightness: isDark || wallpaper.hasWallpaper
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark || wallpaper.hasWallpaper
          ? Brightness.light
          : Brightness.dark,
    );

    final defaultBgColor = isDark
        ? ThemeService.currentAccent.darkScaffoldBg
        : ThemeService.currentAccent.lightScaffoldBg;

    if (!wallpaper.hasWallpaper) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: ColoredBox(
          color: defaultBgColor,
          child: child,
        ),
      );
    }

    final provider = wallpaper.imageProvider;
    if (provider == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: ColoredBox(
          color: defaultBgColor,
          child: child,
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Capa 1: Imagen de Fondo
          Positioned.fill(
            child: Image(
              image: provider,
              fit: BoxFit.cover,
            ),
          ),
          // Capa 2: Velo Protector de Legibilidad (Overlay con tinte ambiental)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                alpha: isDark ? 0.72 : 0.55,
              ),
            ),
          ),
          // Capa 3: Contenido de la pantalla
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
