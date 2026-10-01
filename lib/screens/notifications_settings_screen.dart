import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../utils/responsive.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _notifMorningEntry = true;
  bool _notifMorningExit = true;
  bool _notifAfternoonEntry = true;
  bool _notifAfternoonExit = true;
  bool _notifEvents = true;
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _notifMorningEntry = prefs.getBool('notif_morning_entry') ?? true;
          _notifMorningExit = prefs.getBool('notif_morning_exit') ?? true;
          _notifAfternoonEntry = prefs.getBool('notif_afternoon_entry') ?? true;
          _notifAfternoonExit = prefs.getBool('notif_afternoon_exit') ?? true;
          _notifEvents = prefs.getBool('notif_events') ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      if (mounted) {
        setState(() {
          if (key == 'notif_morning_entry') _notifMorningEntry = value;
          if (key == 'notif_morning_exit') _notifMorningExit = value;
          if (key == 'notif_afternoon_entry') _notifAfternoonEntry = value;
          if (key == 'notif_afternoon_exit') _notifAfternoonExit = value;
          if (key == 'notif_events') _notifEvents = value;
        });
      }
      // Reprogramar las alarmas en el sistema operativo offline
      await NotificationService.scheduleAllAttendanceReminders();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = ThemeService.primaryColor(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeService.cardBg(context),
        elevation: 0.5,
        titleSpacing: 0,
        title: Text(
          'Notificaciones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Responsive.constrained(
                context,
                maxTabletWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarjeta explicativa Offline-First
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: ThemeService.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThemeService.cardBorder(context)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_active_rounded,
                                  color: primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recordatorios en el Dispositivo',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildTag(
                                          icon: Icons.wifi_off_rounded,
                                          label: '100% Offline',
                                          color: const Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 6),
                                        _buildTag(
                                          icon: Icons.alarm_on_rounded,
                                          label: 'Fuera de la app',
                                          color: const Color(0xFF3B82F6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Las alarmas se configuran directamente en el Administrador de Notificaciones del sistema operativo de tu dispositivo. Sonarán a la hora exacta aunque estés sin internet, sin Wi-Fi ni datos móviles, o tengas la app cerrada.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Título de Sección: Jornada Laboral
                    _buildSectionHeader('JORNADA LABORAL Y REFRIGERIO'),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: ThemeService.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThemeService.cardBorder(context)),
                      ),
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: 'Entrada Mañana (07:45 a. m.)',
                            subtitle: 'Aviso para registrar ingreso al iniciar el día',
                            icon: Icons.wb_sunny_outlined,
                            iconColor: const Color(0xFFF59E0B),
                            value: _notifMorningEntry,
                            onChanged: (val) => _toggleSetting('notif_morning_entry', val),
                            isDark: isDark,
                            primary: primary,
                          ),
                          Divider(color: ThemeService.cardBorder(context), height: 1),
                          _buildSwitchTile(
                            title: 'Salida Mañana (01:00 p. m.)',
                            subtitle: 'Recordatorio oportuno para marcar refrigerio',
                            icon: Icons.restaurant_outlined,
                            iconColor: const Color(0xFF10B981),
                            value: _notifMorningExit,
                            onChanged: (val) => _toggleSetting('notif_morning_exit', val),
                            isDark: isDark,
                            primary: primary,
                          ),
                          Divider(color: ThemeService.cardBorder(context), height: 1),
                          _buildSwitchTile(
                            title: 'Entrada Tarde (02:00 p. m.)',
                            subtitle: 'Aviso para registrar reingreso de la tarde',
                            icon: Icons.access_time_rounded,
                            iconColor: const Color(0xFF6366F1),
                            value: _notifAfternoonEntry,
                            onChanged: (val) => _toggleSetting('notif_afternoon_entry', val),
                            isDark: isDark,
                            primary: primary,
                          ),
                          Divider(color: ThemeService.cardBorder(context), height: 1),
                          _buildSwitchTile(
                            title: 'Salida Tarde (06:30 p. m.)',
                            subtitle: 'Alerta oportuna de fin de jornada laboral',
                            icon: Icons.nightlight_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            value: _notifAfternoonExit,
                            onChanged: (val) => _toggleSetting('notif_afternoon_exit', val),
                            isDark: isDark,
                            primary: primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Título de Sección: Eventos
                    _buildSectionHeader('EVENTOS Y CAPACITACIONES'),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: ThemeService.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThemeService.cardBorder(context)),
                      ),
                      child: _buildSwitchTile(
                        title: 'Eventos IIAP (1 hora antes)',
                        subtitle: 'Notificación anticipada de talleres y eventos en los que participas',
                        icon: Icons.event_available_rounded,
                        iconColor: const Color(0xFFEC4899),
                        value: _notifEvents,
                        onChanged: (val) => _toggleSetting('notif_events', val),
                        isDark: isDark,
                        primary: primary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Botón Probar Notificación Ahora
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: ThemeService.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThemeService.cardBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnóstico del Sistema',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Envía una notificación de prueba inmediata a tu bandeja de entrada para verificar el sonido y los permisos.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _isTesting ? 'Enviando prueba...' : 'Probar Notificación Ahora',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              onPressed: _isTesting
                                  ? null
                                  : () async {
                                      setState(() => _isTesting = true);
                                      try {
                                        await NotificationService.triggerTestNotification();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '¡Notificación de prueba enviada! Revisa la barra superior de tu dispositivo.',
                                                    style: TextStyle(fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF16A34A),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: const Color(0xFFEF4444),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) setState(() => _isTesting = false);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTag({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
