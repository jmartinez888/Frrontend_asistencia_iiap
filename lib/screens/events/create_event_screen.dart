import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class CreateEventScreen extends StatefulWidget {
  final EventModel? eventToEdit;

  const CreateEventScreen({
    super.key,
    this.eventToEdit,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  late EventType _selectedType;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late bool _requiresAttendance;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.eventToEdit;
    final now = DateTime.now();

    _titleController = TextEditingController(text: edit?.title ?? '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _locationController = TextEditingController(text: edit?.location ?? 'IIAP - Sede Central');

    _selectedType = edit?.type ?? EventType.CAPACITACION;

    final initialStart = edit?.startDate ?? now.add(const Duration(hours: 1));
    _startDate = DateTime(initialStart.year, initialStart.month, initialStart.day);
    _startTime = TimeOfDay(hour: initialStart.hour, minute: (initialStart.minute ~/ 5) * 5);

    final initialEnd = edit?.endDate ?? initialStart.add(const Duration(hours: 2));
    _endDate = DateTime(initialEnd.year, initialEnd.month, initialEnd.day);
    _endTime = TimeOfDay(hour: initialEnd.hour, minute: (initialEnd.minute ~/ 5) * 5);

    _requiresAttendance = edit?.requiresAttendance ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDate(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de inicio del evento',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Hora de inicio',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de culminación del evento',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Hora de culminación',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _combineDateTime(_startDate, _startTime);
    final end = _combineDateTime(_endDate, _endTime);

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora de culminación debe ser posterior al inicio.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.eventToEdit != null) {
        final updated = widget.eventToEdit!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          startDate: start,
          endDate: end,
          type: _selectedType,
          requiresAttendance: _requiresAttendance,
        );
        await EventService.updateEvent(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Evento actualizado exitosamente!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        await EventService.createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          startDate: start,
          endDate: end,
          type: _selectedType,
          requiresAttendance: _requiresAttendance,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Evento creado y programado exitosamente!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar evento: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  IconData _getTypeIcon(EventType type) {
    switch (type) {
      case EventType.CAPACITACION:
        return Icons.school_rounded;
      case EventType.REUNION:
        return Icons.groups_rounded;
      case EventType.INSTITUCIONAL:
        return Icons.account_balance_rounded;
      case EventType.TALLER:
        return Icons.handshake_rounded;
      case EventType.CONFERENCIA:
        return Icons.mic_external_on_rounded;
      case EventType.OTRO:
        return Icons.event_rounded;
    }
  }

  Color _getTypeColor(EventType type) {
    switch (type) {
      case EventType.CAPACITACION:
        return const Color(0xFF2563EB); // Azul
      case EventType.REUNION:
        return const Color(0xFF0D9488); // Teal
      case EventType.INSTITUCIONAL:
        return const Color(0xFF7C3AED); // Púrpura
      case EventType.TALLER:
        return const Color(0xFFEA580C); // Naranja
      case EventType.CONFERENCIA:
        return const Color(0xFFDB2777); // Rosa
      case EventType.OTRO:
        return const Color(0xFF4B5563); // Gris
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.eventToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Editar Evento' : 'Crear Nuevo Evento',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: ThemeService.cardBg(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Responsive.constrained(
            context,
            maxTabletWidth: 700,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner informativo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeService.primaryColor(context).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ThemeService.primaryColor(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThemeService.primaryColor(context).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: ThemeService.primaryColor(context),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Programación de Evento IIAP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Podrás generar un código QR único para que los asistentes registren su participación.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tipo de Evento
                  Text(
                    'Tipo de Evento',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EventType.values.map((type) {
                      final isSelected = _selectedType == type;
                      final typeColor = _getTypeColor(type);
                      return ChoiceChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(type),
                              size: 16,
                              color: isSelected ? Colors.white : typeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12.5,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                        selectedColor: typeColor,
                        backgroundColor: isDark ? ThemeService.cardBg(context) : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? typeColor : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedType = type);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Título
                  AppTextField(
                    controller: _titleController,
                    label: 'Título del Evento *',
                    hint: 'Ej. Taller Institucional de Asistencia y Gestión',
                    prefixIcon: Icons.title_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa el título del evento';
                      if (v.trim().length < 5) return 'El título debe tener al menos 5 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Ubicación
                  AppTextField(
                    controller: _locationController,
                    label: 'Ubicación / Plataforma *',
                    hint: 'Ej. Auditorio Principal IIAP / Google Meet',
                    prefixIcon: Icons.location_on_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa la ubicación o plataforma';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Descripción
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Descripción o Agenda',
                    hint: 'Detalla los objetivos, ponentes o temas a tratar...',
                    prefixIcon: Icons.notes_rounded,
                    keyboardType: TextInputType.multiline,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 20),

                  // Fecha y Hora de Inicio
                  Text(
                    'Inicio del Evento',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildPickerCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Fecha Inicio',
                          value: _formatDate(_startDate),
                          onTap: _selectStartDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildPickerCard(
                          icon: Icons.access_time_rounded,
                          label: 'Hora',
                          value: _formatTime(_startTime),
                          onTap: _selectStartTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Fecha y Hora de Culminación
                  Text(
                    'Culminación del Evento',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildPickerCard(
                          icon: Icons.event_available_rounded,
                          label: 'Fecha Fin',
                          value: _formatDate(_endDate),
                          onTap: _selectEndDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildPickerCard(
                          icon: Icons.access_time_filled_rounded,
                          label: 'Hora',
                          value: _formatTime(_endTime),
                          onTap: _selectEndTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Switch de Control de Asistencia
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: ThemeService.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _requiresAttendance
                            ? ThemeService.primaryColor(context).withValues(alpha: 0.5)
                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Color(0xFF16A34A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Control de Asistencia con QR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Permite a los asistentes escanear el QR del evento y quedar registrados.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _requiresAttendance,
                          activeTrackColor: ThemeService.primaryColor(context),
                          onChanged: (val) => setState(() => _requiresAttendance = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón de Enviar
                  AppButton(
                    text: isEdit ? 'Guardar Cambios' : 'Publicar Evento',
                    icon: isEdit ? Icons.check_circle_outline_rounded : Icons.add_circle_outline_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ThemeService.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? ThemeService.cardBorder(context) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ThemeService.primaryColor(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
