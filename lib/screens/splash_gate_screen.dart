import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../widgets/leaf_logo.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashGateScreen extends StatefulWidget {
  const SplashGateScreen({super.key});

  @override
  State<SplashGateScreen> createState() => _SplashGateScreenState();
}

class _SplashGateScreenState extends State<SplashGateScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Pausa breve para una transición visual impecable
    await Future.delayed(const Duration(milliseconds: 300));

    final user = StorageService.currentUser;
    final token = await StorageService.getToken();

    // SESIÓN PERMANENTE (Estilo redes sociales):
    // Si el usuario ya tiene sesión iniciada, entra SIEMPRE Y DIRECTAMENTE al Home.
    // Nunca se le pide volver a loguearse por inactividad o tiempo transcurrido.
    if (user != null || (token != null && token.isNotEmpty)) {
      if (mounted) {
        _navigateTo(const HomeScreen());
      }
      // De forma transparente y no bloqueante en segundo plano, refrescar datos
      unawaited(() async {
        try {
          await AuthService.getProfile();
        } catch (_) {}
      }());
      return;
    }

    // Solo si el usuario nunca ha iniciado sesión o cerró sesión voluntariamente, va al login
    if (mounted) {
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget targetScreen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0F2911),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF2B542E),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.05),
              radius: 1.15,
              colors: [
                Color(0xFF4C8050), // Centro verde luminoso
                Color(0xFF3F6C42), // Verde medio institucional
                Color(0xFF234B26), // Transición a verde oscuro
                Color(0xFF133215), // Verde profundo
                Color(0xFF0C240E), // Base inferior oscura
              ],
              stops: [0.0, 0.35, 0.65, 0.88, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Logo central IIAP
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const LeafLogo(
                        size: 46,
                        color: Color(0xFF98E28D),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'IIAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pie de página institucional
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CONTROL DE ASISTENCIA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 44,
                          height: 1.2,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Instituto de Investigaciones de la\nAmazonía Peruana',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
