import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/supervisors_tab.dart';
import 'tabs/profile_tab.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSyncTimer();
    NotificationService.checkAndTriggerCheckoutReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncProfile();
      NotificationService.checkAndTriggerCheckoutReminder();
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _syncProfile();
    });
  }

  Future<void> _syncProfile() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      NotificationService.checkAndTriggerCheckoutReminder();
      final oldUser = StorageService.currentUser;
      final newUser = await AuthService.getProfile();
      if (!mounted) return;

      final wasSupervisor = oldUser?.isSupervisor == true;
      final isNowSupervisor = newUser.isSupervisor == true;
      final wasAdmin = oldUser?.isAdmin == true;
      final isNowAdmin = newUser.isAdmin == true;

      // 1. Detectar revocación de cargo de supervisor en tiempo real
      if (wasSupervisor && !isNowSupervisor && !isNowAdmin) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu cargo de supervisor ha concluido. Has pasado automáticamente a tu usuario normal (Personal).',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (!wasSupervisor && !wasAdmin && isNowSupervisor) {
        // 2. Detectar asignación de supervisor en segundo plano
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Ahora eres Supervisor! Se han habilitado tus permisos para generar QR.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Silencioso ante pérdidas transitorias de conectividad
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, user, _) {
        final isAdmin = user?.isAdmin == true;
        final canManageStaff = user?.canManageAttendanceQr == true;

        final List<Widget> pages = [
          DashboardTab(onNavigateToHistory: () => setState(() => _currentIndex = 1)),
          const AttendanceTab(),
          if (canManageStaff) const SupervisorsTab(),
          const ProfileTab(),
        ];

        final List<NavigationDestination> destinations = [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.access_time_rounded),
            selectedIcon: Icon(Icons.access_time_filled_rounded),
            label: 'Asistencias',
          ),
          if (canManageStaff)
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups_rounded),
              label: isAdmin ? 'Personal' : 'Horarios',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ];

        // Asegurar que el indice no sobrepase si cambia el rol
        final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            backgroundColor: ThemeService.cardBg(context),
            indicatorColor: ThemeService.containerColor(context),
            elevation: 2,
            destinations: destinations,
          ),
        );
      },
    );
  }
}

