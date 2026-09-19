import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/schedule_model.dart';
import '../../services/storage_service.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/schedule_service.dart';
import '../../widgets/attendance_card.dart';
import '../qr/qr_display_screen.dart';
import '../qr/qr_scanner_screen.dart';
import '../../services/theme_service.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback onNavigateToHistory;

  const DashboardTab({
    super.key,
    required this.onNavigateToHistory,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<AttendanceModel> _todayRecords = [];
  List<AttendanceModel> _institutionalRecords = [];
  bool _isLoadingToday = true;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
  }

  Future<void> _loadTodayAttendance() async {
    setState(() => _isLoadingToday = true);
    try {
      final user = StorageService.currentUser;
      if (user?.isAdmin == true) {
        final all = await AttendanceService.getAllRecords();
        if (mounted) {
          setState(() {
            _institutionalRecords = all.take(5).toList();
            _isLoadingToday = false;
          });
        }
      } else {
        final records = await AttendanceService.getTodayRecords();
        if (mounted) {
          setState(() {
            _todayRecords = records;
            _isLoadingToday = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingToday = false);
      }
    }
  }

  void _handleGenerarQr(BuildContext context, UserModel user) {
    if (user.canManageAttendanceQr) {
      // Admin o alguno de los 3 Supervisores
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const QrDisplayScreen(mode: QrMode.attendance),
        ),
      );
    } else {
      // Usuario regular (Empleado)
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 36),
          ),
          title: const Text(
            'Acceso Restringido',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: const Text(
            'La función Generar QR con cifrado SHA-256 está reservada exclusivamente para el Administrador y los 3 Supervisores autorizados para la toma de asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeService.primaryColor(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleEscanearQr(BuildContext context) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(target: ScanTarget.attendance),
      ),
    );
    if (res == true) {
      _loadTodayAttendance();
    }
  }

  String _getRoleShortName(UserRole role) {
    switch (role) {
      case UserRole.ADMIN:
        return 'ADMIN';
      case UserRole.SUPERVISOR:
        return 'SUPERVISOR';
      case UserRole.EMPLOYEE:
        return 'PERSONAL';
    }
  }

  String _getUserSubtitle(UserModel user) {
    if (user.isAdmin) return 'Administrador General';
    if (user.isSupervisor) return 'Supervisor de Asistencia';

    // Determinar dinámicamente según las marcas de hoy del colaborador
    final hasMorning = _todayRecords.any((r) {
      final local = r.timestamp.toLocal();
      return local.hour < 13 || (local.hour == 13 && local.minute <= 15);
    });
    final hasAfternoon = _todayRecords.any((r) {
      final local = r.timestamp.toLocal();
      return local.hour > 13 || (local.hour == 13 && local.minute > 15);
    });

    if (hasMorning && hasAfternoon) {
      return 'Personal • Tiempo Completo (Mañana y Tarde)';
    } else if (hasMorning) {
      return 'Personal • Turno Mañana (08:00 - 13:00)';
    } else if (hasAfternoon) {
      return 'Personal • Turno Tarde (14:00 - 19:00)';
    }

    // Si aún no tiene marcas hoy, comprobar si tiene asignado un horario explícito personalizado
    final schedule = ScheduleService.getSchedule(user.id, position: user.position);
    if (schedule.type != ScheduleType.flexible && schedule.type != ScheduleType.contratado) {
      return 'Personal • ${schedule.fullLabel}';
    }

    return 'Personal de la Institución';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final roleColor = user.isAdmin
            ? const Color(0xFFDC2626)
            : (user.isSupervisor ? const Color(0xFFD97706) : const Color(0xFF16A34A));

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await AuthService.getProfile();
              await _loadTodayAttendance();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Bienvenida y Rol
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: ThemeService.bannerGradient(context),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeService.primaryColor(context).withValues(alpha: isDark ? 0.2 : 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: roleColor.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : (user.isSupervisor ? Icons.security_rounded : Icons.person_rounded),
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _getRoleShortName(user.role),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Color(0xFF4ADE80), size: 7),
                                SizedBox(width: 4),
                                Text(
                                  'En línea',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Hola, ${user.fullName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getUserSubtitle(user),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Sección de Botones Principales: Generar QR y Escanear QR
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Control de Asistencia',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'SHA-256',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ACCIONES CONDICIONALES POR ROL:
                // - Administrador: SOLO botón "Generar QR"
                // - Supervisores: AMBOS botones ("Generar QR" y "Escanear QR" para marcar su propia asistencia)
                // - Personal regular: SOLO botón "Escanear QR"
                if (user.canManageAttendanceQr) ...[
                  _buildActionCard(
                    context,
                    title: 'Generar QR de Asistencia',
                    subtitle: 'Emisión institucional con cifrado SHA-256 (Rotación automática)',
                    icon: Icons.qr_code_2_rounded,
                    color: const Color(0xFF16A34A),
                    badgeText: 'SHA-256',
                    badgeColor: const Color(0xFF16A34A),
                    isLocked: false,
                    onTap: () => _handleGenerarQr(context, user),
                  ),
                  if (user.isSupervisor) const SizedBox(height: 12),
                ],

                if (!user.isAdmin) ...[
                  _buildActionCard(
                    context,
                    title: 'Escanear QR',
                    subtitle: 'Registra tu asistencia escaneando el código QR institucional',
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF2563EB),
                    badgeText: 'CÁMARA',
                    badgeColor: const Color(0xFF2563EB),
                    isLocked: false,
                    onTap: () => _handleEscanearQr(context),
                  ),
                ],

                const SizedBox(height: 24),

                // Sección Asistencias:
                // Para el Administrador: Registro Institucional Reciente
                // Para Personal / Supervisor: Mis Marcas de Hoy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        user.isAdmin ? 'Marcas Institucionales Recientes' : 'Mis Marcas de Hoy',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                      onPressed: widget.onNavigateToHistory,
                      child: Text(
                        user.isAdmin ? 'Ver Registro Completo' : 'Ver Historial',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoadingToday)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (user.isAdmin)
                  if (_institutionalRecords.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: ThemeService.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ThemeService.cardBorder(context),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.corporate_fare_rounded,
                            size: 38,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sin marcas registradas hoy',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cuando los colaboradores escaneen el QR, sus asistencias se mostrarán aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._institutionalRecords.map((r) => AttendanceCard(record: r, showUserName: true))
                else if (_todayRecords.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: ThemeService.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ThemeService.cardBorder(context),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 38,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Aún no has registrado asistencia hoy',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Presiona "Escanear QR" para registrar tu entrada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._todayRecords.map((r) => AttendanceCard(record: r, showUserName: false)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    required Color badgeColor,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeService.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ThemeService.cardBorder(context),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLocked ? Icons.lock_outline_rounded : Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}