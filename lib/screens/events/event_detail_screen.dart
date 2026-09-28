import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive.dart';
import '../qr/qr_scanner_screen.dart';
import 'create_event_screen.dart';
import 'event_qr_display_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late EventModel _currentEvent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    EventService.eventsNotifier.addListener(_onEventsUpdated);
  }

  @override
  void dispose() {
    EventService.eventsNotifier.removeListener(_onEventsUpdated);
    super.dispose();
  }

  void _onEventsUpdated() {
    final updated = EventService.eventsNotifier.value.firstWhere(
      (e) => e.id == _currentEvent.id,
      orElse: () => _currentEvent,
    );
    if (mounted && updated != _currentEvent) {
      setState(() => _currentEvent = updated);
    }
  }

  String _formatDateTime(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'p. m.' : 'a. m.';
    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  Future<void> _handleScanAttendance() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          target: ScanTarget.eventAttendance,
          eventId: _currentEvent.id,
        ),
      ),
    );
    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Asistencia al evento registrada con éxito!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Future<void> _handleDirectRegisterAttendance() async {
    setState(() => _isLoading = true);
    try {
      final updated = await EventService.registerAttendance(
        eventId: _currentEvent.id,
        qrCode: _currentEvent.qrCode,
      );
      if (mounted) {
        setState(() => _currentEvent = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Asistencia confirmada exitosamente!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar Evento?'),
        content: Text('¿Estás seguro de cancelar y eliminar el evento "${_currentEvent.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await EventService.deleteEvent(_currentEvent.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento eliminado')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = StorageService.currentUser;
    final isAdmin = currentUser?.isAdmin == true;
    final isSupervisor = currentUser?.isSupervisor == true;
    final canManage = isAdmin || isSupervisor;
    final canProjectQr = isAdmin || isSupervisor;
    final canScanAttendance = !isAdmin;
    final isAlreadyRegistered = currentUser != null && _currentEvent.isUserRegistered(currentUser.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Evento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: ThemeService.cardBg(context),
        actions: [
          if (canManage) ...[
            IconButton(
              tooltip: 'Editar evento',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateEventScreen(eventToEdit: _currentEvent),
                  ),
                );
                if (updated == true) {
                  // Actualizado
                }
              },
            ),
            IconButton(
              tooltip: 'Eliminar evento',
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Responsive.constrained(
            context,
            maxTabletWidth: 800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera del Evento
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeService.cardBg(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThemeService.cardBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: ThemeService.primaryColor(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_rounded, size: 14, color: ThemeService.primaryColor(context)),
                                const SizedBox(width: 5),
                                Text(
                                  _currentEvent.type.displayName,
                                  style: TextStyle(
                                    color: ThemeService.primaryColor(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _currentEvent.isActiveNow
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                  : const Color(0xFF64748B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: _currentEvent.isActiveNow ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _currentEvent.isActiveNow ? 'En Curso' : _currentEvent.status.displayName,
                                  style: TextStyle(
                                    color: _currentEvent.isActiveNow ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _currentEvent.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        icon: Icons.access_time_rounded,
                        label: 'Inicio',
                        value: _formatDateTime(_currentEvent.startDate),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        context,
                        icon: Icons.event_available_rounded,
                        label: 'Culminación',
                        value: _formatDateTime(_currentEvent.endDate),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        context,
                        icon: Icons.location_on_rounded,
                        label: 'Ubicación',
                        value: _currentEvent.location,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: 'Organizador',
                        value: '${_currentEvent.createdByName} (${_currentEvent.createdByRole})',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sección Asistencia / Acciones Rápidas
                if (_currentEvent.requiresAttendance) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ThemeService.primaryColor(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ThemeService.primaryColor(context).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.how_to_reg_rounded, color: ThemeService.primaryColor(context), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Control de Asistencia del Evento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_currentEvent.attendees.length} asistentes registrados hasta el momento.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 1. Opciones de Registro / Escaneo de Asistencia (Solo Supervisor y Usuario regular)
                        if (canScanAttendance) ...[
                          if (isAlreadyRegistered) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '¡Tu asistencia a este evento ya está confirmada!',
                                      style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Botón para escanear asistencia
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ThemeService.primaryColor(context),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _handleScanAttendance,
                                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                                    label: const Text(
                                      'Escanear QR de Asistencia',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                                if (isSupervisor) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Confirmar asistencia directa',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: _isLoading
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.playlist_add_check_rounded),
                                    onPressed: _isLoading ? null : _handleDirectRegisterAttendance,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],

                        // 2. Proyectar/Mostrar QR del Evento (Solo Administrador y Supervisor)
                        if (canProjectQr) ...[
                          if (canScanAttendance) const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: ThemeService.primaryColor(context)),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EventQrDisplayScreen(event: _currentEvent),
                                  ),
                                );
                              },
                              icon: Icon(Icons.qr_code_2_rounded, color: ThemeService.primaryColor(context), size: 20),
                              label: Text(
                                'Mostrar / Proyectar QR del Evento',
                                style: TextStyle(color: ThemeService.primaryColor(context), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Descripción
                if (_currentEvent.description.isNotEmpty) ...[
                  Text(
                    'Descripción y Temario',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeService.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeService.cardBorder(context)),
                    ),
                    child: Text(
                      _currentEvent.description,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Lista de Asistentes Registrados
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Participantes Registrados (${_currentEvent.attendees.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_currentEvent.attendees.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: ThemeService.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeService.cardBorder(context)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 36, color: ThemeService.subtextColor(context)),
                          const SizedBox(height: 8),
                          Text(
                            'Aún no hay participantes registrados en este evento.',
                            style: TextStyle(fontSize: 13, color: ThemeService.subtextColor(context)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentEvent.attendees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final attendee = _currentEvent.attendees[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeService.cardBg(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ThemeService.cardBorder(context)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: ThemeService.primaryColor(context).withValues(alpha: 0.15),
                              radius: 18,
                              child: Text(
                                attendee.userName.isNotEmpty ? attendee.userName[0].toUpperCase() : 'P',
                                style: TextStyle(
                                  color: ThemeService.primaryColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          attendee.userName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (attendee.isExternal) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'EXTERNO',
                                            style: TextStyle(
                                              color: Color(0xFF0284C7),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    attendee.isExternal || (attendee.documentNumber != null && attendee.documentNumber!.isNotEmpty)
                                        ? [
                                            if (attendee.documentNumber != null && attendee.documentNumber!.isNotEmpty)
                                              'DNI: ${attendee.documentNumber}',
                                            if (attendee.phoneNumber != null && attendee.phoneNumber!.isNotEmpty)
                                              'Cel: ${attendee.phoneNumber}',
                                            if (attendee.userEmail.isNotEmpty)
                                              attendee.userEmail,
                                          ].join(' • ')
                                        : (attendee.userDepartment ?? attendee.userPosition ?? attendee.userEmail),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: ThemeService.subtextColor(context),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${attendee.registeredAt.hour.toString().padLeft(2, '0')}:${attendee.registeredAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ThemeService.primaryColor(context)),
        const SizedBox(width: 10),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
