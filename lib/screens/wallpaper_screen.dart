import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'package:image_picker/image_picker.dart';
import '../services/theme_service.dart';
import '../services/wallpaper_service.dart';

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickCustomImage(ImageSource source) async {
    try {
      setState(() => _isPicking = true);
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (file == null) return;

      await WallpaperService.setCustom(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Fondo personalizado aplicado con éxito.'),
            ],
          ),
          backgroundColor: ThemeService.primaryColor(context),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13111C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: ThemeService.cardBorder(ctx),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'AÑADIR FONDO DE PANTALLA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: ThemeService.primaryColor(ctx),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeService.containerColor(ctx),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: ThemeService.primaryColor(ctx),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Tomar Foto con la Cámara',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Captura una nueva imagen al instante',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCustomImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeService.containerColor(ctx),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: ThemeService.primaryColor(ctx),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Elegir de la Galería',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Selecciona de tus fotos o descargas',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCustomImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = ThemeService.primaryColor(context);

    // Separar presets por categoría
    // Nueva sección Fondos Oscuros AMOLED
    final oscurosPresets = WallpaperService.presets
        .where((p) => p.category == 'Fondos Oscuros')
        .toList();

    // Nueva seccion Animes (Inuyasha, Izumi Miyamura)
    final animesPresets = WallpaperService.presets.where((p) => p.category == 'Animes').toList();

    // Nueva seccion Fondos Rojos
    final rojosPresets = WallpaperService.presets.where((p) => p.category == 'Rojos').toList();

    final chicasPresets = WallpaperService.presets
        .where((p) => p.category == 'Chicas')
        .toList();

    final chicosPresets = WallpaperService.presets
        .where((p) => p.category == 'Chicos & Gaming' || p.category == 'Institucional')
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F1422).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Regresar',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF020617).withValues(alpha: 0.85)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            'FONDO DE PANTALLA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<WallpaperItem>(
        valueListenable: WallpaperService.wallpaperNotifier,
        builder: (context, activeWallpaper, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Responsive.constrained(
              context,
              maxTabletWidth: 900,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECCIÓN: FONDOS OSCUROS & AMOLED (Cyber Matrix, Nebula Abyss, Carbon, Shadow Ronin)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.dark_mode_rounded,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FONDOS OSCUROS & AMOLED',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: oscurosPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = oscurosPresets[index];
                      final isSelected = activeWallpaper.id == item.id;

                      return _buildPresetCard(
                        item: item,
                        isSelected: isSelected,
                        primary: primary,
                        onTap: () => WallpaperService.setPreset(item),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // SECCION: ANIMES (Inuyasha, Izumi Miyamura)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.animation_rounded,
                        color: Color(0xFFA855F7),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'COLECCIÓN ANIMES',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: animesPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = animesPresets[index];
                      final isSelected = activeWallpaper.id == item.id;

                      return _buildPresetCard(
                        item: item,
                        isSelected: isSelected,
                        primary: primary,
                        onTap: () => WallpaperService.setPreset(item),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // SECCION: FONDOS ROJOS (Red Neon Cyber, Seda Rubi)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFEF4444),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'COLECCIÓN ROJO & CYBER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rojosPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = rojosPresets[index];
                      final isSelected = activeWallpaper.id == item.id;

                      return _buildPresetCard(
                        item: item,
                        isSelected: isSelected,
                        primary: primary,
                        onTap: () => WallpaperService.setPreset(item),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // SECCIÓN: CHICAS & ANIME CUTE (Pucca, Angela, Anime Chica, Sakura)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2A85).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFF2A85),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'COLECCIÓN CHICAS & ANIME',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chicasPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = chicasPresets[index];
                      final isSelected = activeWallpaper.id == item.id;

                      return _buildPresetCard(
                        item: item,
                        isSelected: isSelected,
                        primary: primary,
                        onTap: () => WallpaperService.setPreset(item),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // SECCIÓN: CHICOS & GAMING (GX Neo, Ronin, Anime Hero, Selva IIAP)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'COLECCIÓN CHICOS & GAMING',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chicosPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = chicosPresets[index];
                      final isSelected = activeWallpaper.id == item.id;

                      return _buildPresetCard(
                        item: item,
                        isSelected: isSelected,
                        primary: primary,
                        onTap: () => WallpaperService.setPreset(item),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // SECCIÓN: PERSONALIZAR (Con Expanded para eliminar cualquier desbordamiento de píxeles)
                Text(
                  'PERSONALIZAR & SIN FONDO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),

                // Row con Expanded: CERO desbordamientos en cualquier ancho de pantalla
                Row(
                  children: [
                    // Tarjeta "+ Añade tu fondo de pantalla"
                    Expanded(
                      child: _buildAddCustomCard(
                        isSelected: activeWallpaper.type == WallpaperType.custom,
                        activeWallpaper: activeWallpaper,
                        primary: primary,
                        isDark: isDark,
                        onTap: _showImageSourceModal,
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Tarjeta "Color Sólido / Sin Fondo"
                    Expanded(
                      child: _buildDefaultCard(
                        isSelected: !activeWallpaper.hasWallpaper,
                        primary: primary,
                        isDark: isDark,
                        onTap: () async {
                          await WallpaperService.clearWallpaper();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text('Restablecido correctamente.'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF2D5E2A),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Mensaje informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeService.cardBg(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ThemeService.cardBorder(context),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'El fondo se proyecta con un velo ambiental inteligente que protege los textos, manteniendo siempre visible la barra de estado superior (hora, batería e internet) y legibilidad al 100%.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    ),
  );
  }

  Widget _buildPresetCard({
    required WallpaperItem item,
    required bool isSelected,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? primary : Colors.transparent,
                    width: isSelected ? 3.5 : 0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 1,
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        item.assetPath!,
                        fit: BoxFit.cover,
                      ),
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 1.1,
                color: isSelected ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCustomCard({
    required bool isSelected,
    required WallpaperItem activeWallpaper,
    required Color primary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final hasCustomImage = isSelected && activeWallpaper.imageProvider != null;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 230,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF140D1E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? primary : ThemeService.cardBorder(context),
                    width: isSelected ? 2.5 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.4),
                            blurRadius: 14,
                          )
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hasCustomImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              image: activeWallpaper.imageProvider!,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isPicking
                                  ? SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(primary),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 28,
                                        color: primary,
                                      ),
                                    ),
                              const SizedBox(height: 12),
                              Text(
                                'Añade tu fondo de pantalla',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasCustomImage ? 'MI FOTO' : 'PERSONALIZAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 1.0,
                color: isSelected ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCard({
    required bool isSelected,
    required Color primary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 230,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E131F) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? primary : ThemeService.cardBorder(context),
                    width: isSelected ? 2.5 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.4),
                            blurRadius: 14,
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isSelected ? primary : Colors.grey).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.format_paint_rounded,
                          size: 26,
                          color: isSelected ? primary : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Color Sólido\n(Por defecto)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SIN FONDO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 1.0,
                color: isSelected ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
