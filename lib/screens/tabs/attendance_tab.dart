import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/attendance_service.dart';
import '../../services/pdf_report_service.dart';
import '../../widgets/shift_journey_card.dart';
import '../../widgets/pending_checkout_card.dart';
import '../../services/theme_service.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with TickerProviderStateMixin {
  TabController? _tabController;
  List<AttendanceModel> _myRecords = [];
  List<AttendanceModel> _allRecords = [];
  List<Map<String, dynamic>> _pendingCheckouts = [];
  bool _isLoadingMy = true;
  bool _isLoadingAll = false;
  bool _isLoadingPending = false;
  bool _hasFetchedMy = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    final user = StorageService.currentUserNotifier.value;
    if (user != null && user.isAdmin) {
      _tabController = TabController(length: 2, vsync: this);
      _loadAllRecords();
      _loadPendingCheckouts();
    } else if (user != null && user.isSupervisor) {
      _tabController = TabController(length: 3, vsync: this);
      _loadAllRecords();
      _loadMyRecords();
      _loadPendingCheckouts();
    } else {
      _loadMyRecords();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadMyRecords() async {
    setState(() => _isLoadingMy = true);
    try {
      final records = await AttendanceService.getMyRecords();
      if (mounted) {
        setState(() {
          _myRecords = records;
          _isLoadingMy = false;
          _hasFetchedMy = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMy = false;
          _hasFetchedMy = true;
        });
      }
    }
  }

  Future<void> _loadAllRecords() async {
    setState(() => _isLoadingAll = true);
    try {
      final records = await AttendanceService.getAllRecords();
      if (mounted) {
        setState(() {
          _allRecords = records;
          _isLoadingAll = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
        });
      }
    }
  }

  Future<void> _loadPendingCheckouts() async {
    setState(() => _isLoadingPending = true);
    try {
      final list = await AttendanceService.getPendingCheckouts();
      if (mounted) {
        setState(() {
          _pendingCheckouts = list;
          _isLoadingPending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPending = false);
      }
    }
  }

  Future<void> _exportPdfReport() async {
    final user = StorageService.currentUserNotifier.value;
    if (user == null) return;

    if (_allRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de asistencias para exportar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando Reporte Oficial PDF del IIAP...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await PdfReportService.generateAndPreviewReport(
        records: _allRecords,
        currentUser: user,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _showManualAttendanceDialog() async {
    final dniController = TextEditingController();
    final obsController = TextEditingController();
    AttendanceType selectedType = AttendanceType.CHECK_IN;
    AttendanceShift selectedShift =
        DateTime.now().hour < 13 ? AttendanceShift.MORNING : AttendanceShift.AFTERNOON;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: ThemeService.cardBg(context),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emergency_outlined, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marcación Manual',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Contingencia por Celular Avariado/Robado',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registrar asistencia manual para un colaborador que no puede escanear el QR.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo DNI
                  const Text('Documento / DNI del Colaborador *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dniController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: InputDecoration(
                      hintText: 'Ingrese los 8 dígitos del DNI',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selector de Turno: MAÑANA / TARDE
                  const Text('Turno de la Jornada *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedShift = AttendanceShift.MORNING),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selectedShift == AttendanceShift.MORNING
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedShift == AttendanceShift.MORNING
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wb_sunny_rounded,
                                  size: 16,
                                  color: selectedShift == AttendanceShift.MORNING ? Colors.blue : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'MAÑANA',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedShift == AttendanceShift.MORNING ? Colors.blue : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedShift = AttendanceShift.AFTERNOON),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selectedShift == AttendanceShift.AFTERNOON
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedShift == AttendanceShift.AFTERNOON
                                    ? Colors.amber
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.nights_stay_rounded,
                                  size: 16,
                                  color: selectedShift == AttendanceShift.AFTERNOON ? Colors.amber : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'TARDE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedShift == AttendanceShift.AFTERNOON ? Colors.amber : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Selector de Tipo: ENTRADA / SALIDA
                  const Text('Tipo de Marcación *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedType = AttendanceType.CHECK_IN),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType == AttendanceType.CHECK_IN
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedType == AttendanceType.CHECK_IN ? Colors.green : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 18,
                                  color: selectedType == AttendanceType.CHECK_IN ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ENTRADA',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: selectedType == AttendanceType.CHECK_IN ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedType = AttendanceType.CHECK_OUT),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType == AttendanceType.CHECK_OUT
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedType == AttendanceType.CHECK_OUT ? Colors.orange : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                  color: selectedType == AttendanceType.CHECK_OUT ? Colors.orange : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SALIDA',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: selectedType == AttendanceType.CHECK_OUT ? Colors.orange : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Observación / Justificación
                  const Text('Motivo / Observación *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: obsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej. Celular averiado / Olvido involuntario',
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeService.primaryColor(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final dni = dniController.text.trim();
                        final obs = obsController.text.trim();
                        if (dni.length != 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('El DNI debe tener 8 dígitos numéricos.')),
                          );
                          return;
                        }
                        if (obs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa la observación del motivo.')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);

                        try {
                          final res = await AttendanceService.registerManualAttendance(
                            dni: dni,
                            type: selectedType.name,
                            shift: selectedShift.name,
                            observation: obs,
                          );
                          nav.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ?? 'Asistencia registrada con éxito.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          if (mounted) {
                            _loadAllRecords();
                            _loadPendingCheckouts();
                            if (_tabController != null) {
                              _loadMyRecords();
                            }
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Registrar Asistencia'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmWeeklyReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Reinicio Semanal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: const Text(
          'El sistema reinicia automáticamente todo el historial de asistencias los viernes a las 10:00 PM para evitar saturar la base de datos y la aplicación para todos (admin, supervisores y personal).\n\n¿Deseas ejecutar un reinicio manual en este momento?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reiniciar Ahora'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reiniciando historial semanal...')),
      );
      try {
        final res = await AttendanceService.clearWeeklyHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(res['message']?.toString() ?? 'Historial semanal reiniciado exitosamente.'),
            ),
          );
          _loadAllRecords();
          _loadPendingCheckouts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Error al reiniciar historial: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, user, _) {
        final isAdmin = user != null && user.isAdmin;
        final isSupervisor = user != null && user.isSupervisor;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // 1. Administrador General: TabBar con "Registro General" y "Pendientes de Salida"
        if (isAdmin) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Control Institucional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  tooltip: 'Marcación Manual de Emergencia',
                  onPressed: _showManualAttendanceDialog,
                ),
                IconButton(
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Exportar Reporte PDF (Entradas y Salidas)',
                  onPressed: _isGeneratingPdf ? null : _exportPdfReport,
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services_rounded),
                  tooltip: 'Reinicio Semanal (Viernes 10:00 PM)',
                  onPressed: _confirmWeeklyReset,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                  onPressed: () {
                    _loadAllRecords();
                    _loadPendingCheckouts();
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: ThemeService.primaryColor(context),
                indicatorColor: ThemeService.primaryColor(context),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                indicatorWeight: 3,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.corporate_fare_rounded, size: 20),
                    text: 'Registro General',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: _pendingCheckouts.isNotEmpty,
                      label: Text('${_pendingCheckouts.length}'),
                      backgroundColor: Colors.amber[800],
                      child: const Icon(Icons.pending_actions_rounded, size: 20),
                    ),
                    text: 'Pendientes de Salida',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildJourneyList(
                  ShiftJourneyRecord.groupFromRecords(_allRecords),
                  _isLoadingAll,
                  () async {
                    await _loadAllRecords();
                    await _loadPendingCheckouts();
                  },
                  showUserName: true,
                ),
                _buildPendingList(
                  _pendingCheckouts,
                  _isLoadingPending,
                  _loadPendingCheckouts,
                ),
              ],
            ),
          );
        }

        // 2. Colaborador Regular: Solo su propio historial de jornadas
        if (!isSupervisor) {
          if (!_hasFetchedMy && !_isLoadingMy) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMyRecords();
            });
          }
          return Scaffold(
            appBar: AppBar(
              title: const Text('Historial de Asistencias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                  onPressed: _loadMyRecords,
                ),
              ],
            ),
            body: _buildJourneyList(
              ShiftJourneyRecord.groupFromRecords(_myRecords),
              _isLoadingMy,
              _loadMyRecords,
              showUserName: false,
            ),
          );
        }

        // 3. Supervisor: 3 pestañas: "Mis Asistencias", "Registro Institucional", "Pendientes de Salida"
        return Scaffold(
          appBar: AppBar(
            title: const Text('Control de Asistencias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                tooltip: 'Marcación Manual de Emergencia',
                onPressed: _showManualAttendanceDialog,
              ),
              IconButton(
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'Exportar Reporte PDF (Entradas y Salidas)',
                onPressed: _isGeneratingPdf ? null : _exportPdfReport,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  _loadMyRecords();
                  _loadAllRecords();
                  _loadPendingCheckouts();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: ThemeService.primaryColor(context),
              indicatorColor: ThemeService.primaryColor(context),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorWeight: 3,
              tabs: [
                const Tab(
                  icon: Icon(Icons.person_outline_rounded, size: 20),
                  text: 'Mis Asistencias',
                ),
                const Tab(
                  icon: Icon(Icons.corporate_fare_rounded, size: 20),
                  text: 'Registro General',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: _pendingCheckouts.isNotEmpty,
                    label: Text('${_pendingCheckouts.length}'),
                    backgroundColor: Colors.amber[800],
                    child: const Icon(Icons.pending_actions_rounded, size: 20),
                  ),
                  text: 'Pendientes',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildJourneyList(
                ShiftJourneyRecord.groupFromRecords(_myRecords),
                _isLoadingMy,
                _loadMyRecords,
                showUserName: false,
              ),
              _buildJourneyList(
                ShiftJourneyRecord.groupFromRecords(_allRecords),
                _isLoadingAll,
                () async {
                  await _loadAllRecords();
                  await _loadPendingCheckouts();
                },
                showUserName: true,
              ),
              _buildPendingList(
                _pendingCheckouts,
                _isLoadingPending,
                _loadPendingCheckouts,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJourneyList(
    List<ShiftJourneyRecord> journeys,
    bool isLoading,
    Future<void> Function() onRefresh, {
    required bool showUserName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (journeys.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.assignment_late_outlined,
              size: 56,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron jornadas registradas',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Arrastra hacia abajo para actualizar la lista desde la base de datos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Responsive.constrained(
        context,
        maxTabletWidth: 860,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          itemCount: journeys.length,
          itemBuilder: (context, index) {
            return ShiftJourneyCard(
              journey: journeys[index],
              showUserName: showUserName,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPendingList(
    List<Map<String, dynamic>> items,
    bool isLoading,
    Future<void> Function() onRefresh,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: Colors.green.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin salidas pendientes',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Todos los colaboradores han completado su registro de salida para sus jornadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Responsive.constrained(
        context,
        maxTabletWidth: 860,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return PendingCheckoutCard(
              item: items[index],
            );
          },
        ),
      ),
    );
  }
}
