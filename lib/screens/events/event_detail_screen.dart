import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive.dart';
import '../qr/qr_scanner_screen.dart';
import 'create_event_screen.dart';
import 'event_certificate_modal.dart';
import 'event_qr_display_screen.dart';
import 'manual_attendee_modal.dart';

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
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    EventService.eventsNotifier.addListener(_onEventsUpdated);
    _startLiveRefresh();
  }

  void _startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    // Sondeo periódico para reflejar en tiempo real participantes que llenan el formulario web o escanean el QR
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        await EventService.getEvents();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    EventService.eventsNotifier.removeListener(_onEventsUpdated);
    super.dispose();
  }

  void _onEventsUpdated() {
    final updated = EventService.eventsNotifier.value.firstWhere(
      (e) => e.id == _currentEvent.id,
      orElse: () => _currentEvent,
    );
    if (mounted && (updated != _currentEvent || updated.attendees.length != _currentEvent.attendees.length)) {
      final hadFewer = updated.attendees.length > _currentEvent.attendees.length;
      setState(() => _currentEvent = updated);
      if (hadFewer) {
        HapticFeedback.lightImpact();
      }
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

  String _formatAttendeeTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'p. m.' : 'a. m.';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
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

  Future<void> _handleRemoveAttendee(EventAttendeeModel attendee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('¿Eliminar Asistente?'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar a "${attendee.userName}" de la lista oficial de asistencia de este evento? Si fue un error, la persona podrá volver a registrarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final idToRemove = attendee.id.isNotEmpty ? attendee.id : attendee.userId;
        final updated = await EventService.removeAttendee(
          eventId: _currentEvent.id,
          attendeeId: idToRemove,
        );
        if (mounted) {
          setState(() => _currentEvent = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Se eliminó a ${attendee.userName} del evento.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar participante: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleManualRegisterAttendee() async {
    final updated = await ManualAttendeeModal.show(context, event: _currentEvent);
    if (updated != null && mounted) {
      setState(() => _currentEvent = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Participante registrado exitosamente en el evento!'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleViewCertificate() {
    final currentUser = StorageService.currentUser;
    if (currentUser == null) return;

    EventAttendeeModel myAttendee;
    try {
      myAttendee = _currentEvent.attendees.firstWhere(
        (a) => a.userId == currentUser.id,
      );
    } catch (_) {
      myAttendee = EventAttendeeModel(
        id: '',
        userId: currentUser.id,
        userName: currentUser.fullName,
        userEmail: currentUser.email,
        userDepartment: currentUser.department,
        userPosition: currentUser.position,
        documentNumber: currentUser.documentNumber,
        registeredAt: DateTime.now(),
        isExternal: false,
      );
    }

    EventCertificateModal.show(context, event: _currentEvent, attendee: myAttendee);
  }

  String _toCalendarFormat(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}T${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}Z';
  }

  Future<void> _handleAddToCalendar() async {
    final startStr = _toCalendarFormat(_currentEvent.startDate);
    final endStr = _toCalendarFormat(_currentEvent.endDate);
    final title = Uri.encodeComponent(_currentEvent.title);
    final desc = Uri.encodeComponent(_currentEvent.description.isNotEmpty ? _currentEvent.description : 'Evento Institucional IIAP');
    final loc = Uri.encodeComponent(_currentEvent.location);

    final googleUrl = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$startStr/$endStr&details=$desc&location=$loc';
    final outlookUrl = 'https://outlook.live.com/calendar/0/deeplink/compose?subject=$title&startdt=${_currentEvent.startDate.toIso8601String()}&enddt=${_currentEvent.endDate.toIso8601String()}&body=$desc&location=$loc';

    final width = MediaQuery.sizeOf(context).width;
    final isTabletOrDesktop = width >= 640;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: isTabletOrDesktop ? 520 : double.infinity),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: ThemeService.cardBg(ctx),
            borderRadius: isTabletOrDesktop
                ? BorderRadius.circular(24)
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, isTabletOrDesktop ? 22 : 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isTabletOrDesktop) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Añadir a mi Calendario',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Selecciona el calendario de tu preferencia para sincronizar este evento:',
                style: TextStyle(fontSize: 12.5, color: ThemeService.subtextColor(ctx)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: ThemeService.cardBorder(ctx)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_available_rounded, color: Color(0xFF4285F4), size: 20),
                ),
                title: const Text('Google Calendar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Sincronizar en Android, iPhone o Web', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.parse(googleUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: ThemeService.cardBorder(ctx)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0078D4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.email_outlined, color: Color(0xFF0078D4), size: 20),
                ),
                title: const Text('Outlook / Microsoft 365', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Calendario corporativo', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.parse(outlookUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: ThemeService.cardBorder(ctx)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeService.primaryColor(ctx).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.copy_rounded, color: ThemeService.primaryColor(ctx), size: 20),
                ),
                title: const Text('Copiar Datos del Evento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Título, fecha, hora y ubicación en portapapeles', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.check_rounded, size: 18),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final text = '${_currentEvent.title}\nFecha: ${_formatDateTime(_currentEvent.startDate)}\nLugar: ${_currentEvent.location}\n${_currentEvent.description}';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Datos del evento copiados al portapapeles!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
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
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: ThemeService.primaryColor(context).withValues(alpha: 0.4)),
                          ),
                          onPressed: _handleAddToCalendar,
                          icon: Icon(Icons.calendar_month_rounded, size: 18, color: ThemeService.primaryColor(context)),
                          label: Text(
                            'Añadir a mi Calendario',
                            style: TextStyle(
                              color: ThemeService.primaryColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
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
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                children: [
                                  const Row(
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
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF16A34A),
                                        foregroundColor: Colors.white,
                                        elevation: 1,
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: _handleViewCertificate,
                                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                      label: const Text(
                                        'Ver Mi Constancia de Asistencia (PDF)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

                        // 2. Proyectar/Mostrar QR del Evento: Dos opciones (Usuario Registrado y Usuario Externo)
                        if (canProjectQr) ...[
                          if (canScanAttendance) const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, size: 18, color: ThemeService.primaryColor(context)),
                              const SizedBox(width: 8),
                              Text(
                                'Proyección de Asistencia (2 Modalidades)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 520;
                              final card1 = _buildQrOptionCard(
                                context: context,
                                title: 'Usuario Registrado',
                                badge: 'Con App IIAP',
                                badgeColor: const Color(0xFF16A34A),
                                icon: Icons.phone_android_rounded,
                                description:
                                    'Para colaboradores que tienen la aplicación instalada y su cuenta institucional activa. Al escanearlo, su asistencia queda confirmada al instante.',
                                buttonText: 'Proyectar QR Registrados',
                                buttonColor: const Color(0xFF16A34A),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EventQrDisplayScreen(
                                        event: _currentEvent,
                                        initialMode: EventQrMode.registered,
                                      ),
                                    ),
                                  );
                                },
                              );

                              final card2 = _buildQrOptionCard(
                                context: context,
                                title: 'Usuario Externo',
                                badge: 'Sin App / Formulario Web',
                                badgeColor: const Color(0xFF0284C7),
                                icon: Icons.language_rounded,
                                description:
                                    'Para personas que no tienen la app ni cuenta. Al escanear con su cámara, se abre el formulario web en su navegador y al registrarse aparecen aquí.',
                                buttonText: 'Proyectar QR Externo',
                                buttonColor: const Color(0xFF0284C7),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EventQrDisplayScreen(
                                        event: _currentEvent,
                                        initialMode: EventQrMode.external,
                                      ),
                                    ),
                                  );
                                },
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: card1),
                                    const SizedBox(width: 12),
                                    Expanded(child: card2),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    card1,
                                    const SizedBox(height: 12),
                                    card2,
                                  ],
                                );
                              }
                            },
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
                    Expanded(
                      child: Text(
                        'Participantes Registrados (${_currentEvent.attendees.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeService.primaryColor(context),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _handleManualRegisterAttendee,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text(
                          '+ Registrar',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
                                            if (attendee.career != null && attendee.career!.isNotEmpty)
                                              attendee.career!,
                                            if (attendee.gender != null && attendee.gender!.isNotEmpty)
                                              attendee.gender!,
                                            if (attendee.age != null)
                                              '${attendee.age} años',
                                            if (attendee.institution != null && attendee.institution!.isNotEmpty)
                                              attendee.institution!,
                                            if (attendee.userEmail.isNotEmpty && attendee.documentNumber == null)
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
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatAttendeeTime(attendee.registeredAt),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canManage) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                  color: Color(0xFFEF4444),
                                ),
                                tooltip: 'Eliminar participante del evento',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _isLoading ? null : () => _handleRemoveAttendee(attendee),
                              ),
                            ],
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

  Widget _buildQrOptionCard({
    required BuildContext context,
    required String title,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.06),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.38,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.qr_code_2_rounded, size: 17),
              label: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
