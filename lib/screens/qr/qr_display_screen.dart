import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/qr_model.dart';
import '../../services/storage_service.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../widgets/qr_countdown_timer.dart';
import '../../widgets/app_button.dart';

enum QrMode {
  attendance,
  supervisorAssignment,
}

class QrDisplayScreen extends StatefulWidget {
  final QrMode mode;

  const QrDisplayScreen({
    super.key,
    this.mode = QrMode.attendance,
  });

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  QrGeneratedResponse? _qrData;
  bool _isLoading = true;
  bool _isGeneratingNew = false;
  bool _justRotated = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  Timer? _rotationResetTimer;

  @override
  void initState() {
    super.initState();
    StorageService.currentUserNotifier.addListener(_onUserRoleChanged);
    _loadQr(forceNew: false);
    _startPolling();
  }

  @override
  void dispose() {
    StorageService.currentUserNotifier.removeListener(_onUserRoleChanged);
    _pollingTimer?.cancel();
    _rotationResetTimer?.cancel();
    super.dispose();
  }

  void _onUserRoleChanged() {
    final user = StorageService.currentUser;
    // Si al usuario se le revoca el cargo mientras tiene abierta la pantalla de QR, salir de inmediato
    if (user != null && widget.mode == QrMode.attendance && !user.canManageAttendanceQr) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _startPolling() {
    // Sondeo rápido cada 1.5 segundos para rotación instantánea al escaneo
    if (widget.mode == QrMode.attendance) {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkForRotatedQr());
    }
  }

  Future<void> _checkForRotatedQr() async {
    if (!mounted || _isLoading || _isGeneratingNew || _qrData == null) return;
    try {
      final active = await AttendanceService.getActiveAttendanceQr();
      if (mounted && active.qrCode != _qrData?.qrCode) {
        HapticFeedback.heavyImpact();
        _rotationResetTimer?.cancel();

        setState(() {
          _qrData = active;
          _justRotated = true;
        });

        _rotationResetTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _justRotated = false);
          }
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Código QR renovado! Un colaborador acaba de registrar su asistencia.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 403) {
        try {
          await AuthService.getProfile();
        } catch (_) {}
      }
    } catch (_) {
      // Ignorar errores silenciosos en sondeo de fondo
    }
  }

  Future<void> _loadQr({bool forceNew = false}) async {
    if (!mounted) return;
    setState(() {
      if (forceNew) {
        _isGeneratingNew = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      QrGeneratedResponse response;
      if (widget.mode == QrMode.attendance) {
        response = forceNew
            ? await AttendanceService.generateAttendanceQr()
            : await AttendanceService.getActiveAttendanceQr();
      } else {
        response = await AttendanceService.generateSupervisorQr();
      }

      if (mounted) {
        setState(() {
          _qrData = response;
          _isLoading = false;
          _isGeneratingNew = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 403) {
        try {
          await AuthService.getProfile();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
          _isGeneratingNew = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar código QR: $e';
          _isLoading = false;
          _isGeneratingNew = false;
        });
      }
    }
  }

  void _copyHashToClipboard() {
    if (_qrData == null) return;
    Clipboard.setData(ClipboardData(text: _qrData!.qrCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hash SHA-256 copiado:\n${_qrData!.qrCode.substring(0, 24)}...',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = StorageService.currentUser;

    final isAttendance = widget.mode == QrMode.attendance;
    final title = isAttendance ? 'Generador de Código QR' : 'Designar Supervisor';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: _isGeneratingNew
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Generar nuevo QR SHA',
            onPressed: (_isLoading || _isGeneratingNew) ? null : () => _loadQr(forceNew: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.isTablet(context) ? (Responsive.isLargeTablet(context) ? 680 : 580) : 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Banner de Identidad Criptográfica SHA-256
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Color(0xFF16A34A),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isAttendance ? 'Toma de Asistencia' : 'Designación',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      'SHA-256',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Válido por 5 minutos • Renovación por escaneo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Aviso visual animado si se acaba de renovar automáticamente
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _justRotated
                        ? Container(
                            key: const ValueKey('rotated_badge'),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.autorenew_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '¡NUEVO QR GENERADO TRAS ESCANEO!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),

                  // Caja del Código QR Generado
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _justRotated ? const Color(0xFF16A34A) : Colors.transparent,
                        width: _justRotated ? 3.5 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _justRotated
                              ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: _justRotated ? 24 : 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: Responsive.qrDisplaySize(context) + 20,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Generando código QR con SHA-256...',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _errorMessage != null
                            ? SizedBox(
                                height: 250,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                                      const SizedBox(height: 12),
                                      Text(
                                        _errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                                      ),
                                      const SizedBox(height: 16),
                                      AppButton(
                                        text: 'Reintentar',
                                        height: 40,
                                        width: 130,
                                        onPressed: () => _loadQr(forceNew: true),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    transitionBuilder: (child, anim) => ScaleTransition(
                                      scale: anim,
                                      child: FadeTransition(opacity: anim, child: child),
                                    ),
                                    child: QrImageView(
                                      key: ValueKey(_qrData!.qrCode),
                                      data: _qrData!.qrCode,
                                      version: QrVersions.auto,
                                      size: Responsive.qrDisplaySize(context),
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Visualizador de Hash SHA-256 con opción de copiar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF475569)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'SHA: ${_qrData!.qrCode.length >= 18 ? "${_qrData!.qrCode.substring(0, 18)}..." : _qrData!.qrCode}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: _copyHashToClipboard,
                                          borderRadius: BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                  ),

                  const SizedBox(height: 20),

                  // Temporizador de 5 minutos
                  if (_qrData != null && !_isLoading && _errorMessage == null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: QrCountdownTimer(
                        expiresAt: _qrData!.expiresAt,
                        onExpired: () => _loadQr(forceNew: true),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Emisor del QR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            currentUser?.isAdmin == true
                                ? Icons.admin_panel_settings_rounded
                                : Icons.security_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Emisor: ${currentUser?.fullName ?? "Supervisor"} (${currentUser?.role.displayName ?? "Supervisor"})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botón de Regenerar QR SHA
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isGeneratingNew ? null : () => _loadQr(forceNew: true),
                        icon: _isGeneratingNew
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.autorenew_rounded, size: 20),
                        label: Text(
                          _isGeneratingNew ? 'Generando nuevo SHA...' : 'Generar Nuevo QR (SHA)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
