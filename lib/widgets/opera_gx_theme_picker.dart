import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class OperaGxThemePicker extends StatelessWidget {
  const OperaGxThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.themeModeNotifier,
        ThemeService.accentColorNotifier,
      ]),
      builder: (context, _) {
        final currentMode = ThemeService.themeModeNotifier.value;
        final currentAccent = ThemeService.currentAccent;
        final activeColor = currentAccent.accentSample;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título TEMA estilo Opera GX
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TEMA',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activeColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    currentAccent.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: activeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Carrusel de tarjetas cyberpunk estilo Opera GX
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: AppAccentColor.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = AppAccentColor.values[index];
                  final isSelected = item == currentAccent;
                  final itemColor = item.accentSample;

                  return GestureDetector(
                    onTap: () => ThemeService.setAccentColor(item),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tarjeta Opera GX con Wireframe y Glow
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 102,
                          height: 114,
                          decoration: BoxDecoration(
                            color: isDark
                                ? (isSelected ? item.darkCardBg : const Color(0xFF141420))
                                : (isSelected ? item.lightContainer.withValues(alpha: 0.5) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? itemColor
                                  : (isDark ? const Color(0xFF262638) : const Color(0xFFCBD5E1)),
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: itemColor.withValues(alpha: isDark ? 0.6 : 0.4),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Marco decorativo cyberpunk interno
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? itemColor.withValues(alpha: 0.35)
                                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Contenido del mockup interior
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Logo anillo Opera GX
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? itemColor : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? itemColor : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Barra simulada de búsqueda/nav
                                  Container(
                                    width: 58,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? itemColor.withValues(alpha: 0.3)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Cuadrículas de Speed Dial simuladas (4 cuadritos)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      4,
                                      (i) => Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? itemColor.withValues(alpha: 0.35)
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                          borderRadius: BorderRadius.circular(2.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Nombre tech en mayúsculas
                        Text(
                          item.displayName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.6,
                            color: isSelected
                                ? (isDark ? Colors.white : item.lightPrimary)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // Selector Segmentado estilo Opera GX: [ Claro | Auto | Oscuro ]
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF262638) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  _buildSegmentButton(
                    label: 'Claro',
                    isSelected: currentMode == ThemeMode.light,
                    activeColor: activeColor,
                    isDark: isDark,
                    onTap: () => ThemeService.setThemeMode(ThemeMode.light),
                  ),
                  _buildSegmentButton(
                    label: 'Auto',
                    isSelected: currentMode == ThemeMode.system,
                    activeColor: activeColor,
                    isDark: isDark,
                    onTap: () {
                    ThemeService.setThemeMode(ThemeMode.system);
                    ThemeService.setAccentColor(AppAccentColor.verdeSelva);
                  },
                  ),
                  _buildSegmentButton(
                    label: 'Oscuro',
                    isSelected: currentMode == ThemeMode.dark,
                    activeColor: activeColor,
                    isDark: isDark,
                    onTap: () => ThemeService.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
