import 'package:flutter/material.dart';

/// Utilidad responsiva y adaptativa para optimizar la interfaz en Tablets, iPads y Celulares (iPhones y Android)
class Responsive {
  /// Retorna true si el dispositivo es Tablet o iPad (lado menor >= 600dp)
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }

  /// Retorna true si es una tablet grande o iPad Pro (lado menor >= 720dp)
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 720;
  }

  /// Retorna true si el dispositivo está en orientación horizontal (Landscape)
  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// Escala de fuentes: en celular devuelve el tamaño exacto, en tablet escala proporcionalmente
  static double font(BuildContext context, double phoneSize, {double tabletFactor = 1.18}) {
    if (isTablet(context)) {
      return phoneSize * tabletFactor;
    }
    return phoneSize;
  }

  /// Escala de iconos: en celular devuelve el tamaño exacto, en tablet escala proporcionalmente
  static double icon(BuildContext context, double phoneSize, {double tabletFactor = 1.22}) {
    if (isTablet(context)) {
      return phoneSize * tabletFactor;
    }
    return phoneSize;
  }

  /// Tamaño del código QR en pantalla: en celular 240dp, en tablet 340dp-380dp para modo Garita / Kiosco
  static double qrDisplaySize(BuildContext context) {
    if (isLargeTablet(context)) return 380.0;
    if (isTablet(context)) return 340.0;
    return 240.0;
  }

  /// Contenedor centrado ergonómico: en celular usa ancho completo (100% idéntico), en tablet limita el ancho máximo
  static Widget constrained(
    BuildContext context, {
    required Widget child,
    double maxTabletWidth = 840.0,
  }) {
    if (!isTablet(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxTabletWidth),
        child: child,
      ),
    );
  }

  /// Ancho ergonómico para diálogos modales en tablets
  static BoxConstraints dialogConstraints(BuildContext context, {double maxTabletWidth = 520.0}) {
    if (isTablet(context)) {
      return BoxConstraints(maxWidth: maxTabletWidth);
    }
    return const BoxConstraints();
  }
}
