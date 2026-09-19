import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WallpaperType { none, preset, custom }

class WallpaperItem {
  final String id;
  final String title;
  final WallpaperType type;
  final String? assetPath;
  final String? customFilePath;

  const WallpaperItem({
    required this.id,
    required this.title,
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
  static const String _keyWallpaperId = 'active_wallpaper_id_v1';
  static const String _keyWallpaperType = 'active_wallpaper_type_v1';
  static const String _keyCustomPath = 'active_wallpaper_custom_path_v1';

  static const WallpaperItem defaultNone = WallpaperItem(
    id: 'none',
    title: 'Color Sólido',
    type: WallpaperType.none,
  );

  static const List<WallpaperItem> presets = [
    WallpaperItem(
      id: 'gx',
      title: 'GX',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_gx.jpg',
    ),
    WallpaperItem(
      id: 'ronin',
      title: 'RONIN',
      type: WallpaperType.preset,
      assetPath: 'assets/images/wallpapers/wallpaper_ronin.jpg',
    ),
    WallpaperItem(
      id: 'selva',
      title: 'SELVA IIAP',
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
  }

  /// Construye un contenedor con el fondo activo protegido por overlay oscuro
  /// para garantizar que ningún texto, tarjeta o botón pierda legibilidad.
  static Widget buildBackgroundContainer({
    required BuildContext context,
    required Widget child,
    bool isScaffold = false,
  }) {
    final wallpaper = wallpaperNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!wallpaper.hasWallpaper) {
      return child;
    }

    final provider = wallpaper.imageProvider;
    if (provider == null) {
      return child;
    }

    return Stack(
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
    );
  }
}
