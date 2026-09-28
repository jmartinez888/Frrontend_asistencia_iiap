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
              height: 156,
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
                        // Tarjeta llena y resaltada con el color del tema
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 104,
                          height: 114,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      itemColor.withValues(alpha: isSelected ? 0.38 : 0.22),
                                      item.darkContainer.withValues(alpha: isSelected ? 0.85 : 0.60),
                                      item.darkCardBg,
                                    ]
                                  : [
                                      item.lightContainer,
                                      itemColor.withValues(alpha: isSelected ? 0.38 : 0.20),
                                      Colors.white,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? itemColor
                                  : itemColor.withValues(alpha: isDark ? 0.70 : 0.55),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: itemColor.withValues(alpha: isSelected ? (isDark ? 0.65 : 0.45) : (isDark ? 0.22 : 0.12)),
                                blurRadius: isSelected ? 16 : 8,
                                spreadRadius: isSelected ? 1.5 : 0,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Marco decorativo cyberpunk interno con color temático
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: itemColor.withValues(alpha: isSelected ? 0.50 : 0.28),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Contenido del mockup interior lleno del color del tema
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Logo anillo Opera GX con el color del tema
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: itemColor.withValues(alpha: isSelected ? 0.22 : 0.14),
                                      border: Border.all(
                                        color: itemColor,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: itemColor.withValues(alpha: isSelected ? 0.45 : 0.28),
                                          border: Border.all(
                                            color: itemColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Barra simulada de búsqueda/nav coloreada
                                  Container(
                                    width: 58,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: itemColor.withValues(alpha: isSelected ? 0.70 : 0.50),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Cuadrículas simuladas llenas de color
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      4,
                                      (i) => Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: itemColor.withValues(alpha: isSelected ? 0.75 : 0.55),
                                          borderRadius: BorderRadius.circular(2.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Badge circular de confirmación cuando está seleccionado
                              if (isSelected)
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: itemColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: itemColor.withValues(alpha: 0.8),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Nombre tech en mayúsculas con su propio color
                        Text(
                          item.displayName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            letterSpacing: 0.6,
                            color: isSelected
                                ? (isDark ? Colors.white : item.lightPrimary)
                                : (isDark ? itemColor.withValues(alpha: 0.90) : item.lightPrimary),
                            shadows: isSelected
                                ? [
                                    Shadow(
                                      color: itemColor.withValues(alpha: 0.7),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Pequeña línea indicadora de tema activo
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 22 : 0,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: itemColor.withValues(alpha: 0.8),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          ],
        );
      },
    );
  }
}
