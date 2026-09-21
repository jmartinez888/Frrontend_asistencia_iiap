import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/attendance_service.dart';
import '../../widgets/attendance_card.dart';
import '../../services/theme_service.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<AttendanceModel> _myRecords = [];
  List<AttendanceModel> _allRecords = [];
  bool _isLoadingMy = true;
  bool _isLoadingAll = false;
  bool _hasFetchedMy = false;
  bool _hasFetchedAll = false;

  @override
  void initState() {
    super.initState();
    final user = StorageService.currentUserNotifier.value;
    if (user != null && user.isAdmin) {
      _loadAllRecords();
    } else if (user != null && user.isSupervisor) {
      _tabController = TabController(length: 2, vsync: this);
      _loadAllRecords();
      _loadMyRecords();
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
          _hasFetchedAll = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
          _hasFetchedAll = true;
        });
      }
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, user, _) {
        final isAdmin = user != null && user.isAdmin;
        final isSupervisor = user != null && user.isSupervisor;

        // 1. Administrador General: NO tiene "Mis Asistencias", SOLO Registro Institucional
        if (isAdmin) {
          return Scaffold(
          appBar: AppBar(
              title: const Text('Registro Institucional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.cleaning_services_rounded),
                  tooltip: 'Reinicio Semanal (Viernes 10:00 PM)',
                  onPressed: _confirmWeeklyReset,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                  onPressed: _loadAllRecords,
                ),
              ],
            ),
            body: _buildList(_allRecords, _isLoadingAll, _loadAllRecords, showUserName: true),
          );
        }

        // 2. Colaborador Regular: Solo su propio historial de asistencias
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
            body: _buildList(_myRecords, _isLoadingMy, _loadMyRecords, showUserName: false),
          );
        }

        // 3. Supervisor: Tiene sus marcas personales y el registro institucional general
        if (_tabController == null) {
          _tabController = TabController(length: 2, vsync: this);
          if (!_hasFetchedAll && !_isLoadingAll) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadAllRecords();
            });
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Control de Asistencias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  _loadMyRecords();
                  _loadAllRecords();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: ThemeService.primaryColor(context),
              indicatorColor: ThemeService.primaryColor(context),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_outline_rounded, size: 20),
                  text: 'Mis Asistencias',
                ),
                Tab(
                  icon: Icon(Icons.corporate_fare_rounded, size: 20),
                  text: 'Registro Institucional',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildList(_myRecords, _isLoadingMy, _loadMyRecords, showUserName: false),
              _buildList(_allRecords, _isLoadingAll, _loadAllRecords, showUserName: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    List<AttendanceModel> records,
    bool isLoading,
    Future<void> Function() onRefresh, {
    required bool showUserName,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (records.isEmpty) {
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
              'No se encontraron registros',
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
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        itemCount: records.length,
        itemBuilder: (context, index) {
          return AttendanceCard(
            record: records[index],
            showUserName: showUserName,
          );
        },
      ),
    );
  }
}
