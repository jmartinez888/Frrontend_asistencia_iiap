import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/api_config.dart';
import '../../models/event_model.dart';
import '../../services/api_client.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_button.dart';

class EventQrDisplayScreen extends StatefulWidget {
  final EventModel event;

  const EventQrDisplayScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventQrDisplayScreen> createState() => _EventQrDisplayScreenState();
}

class _EventQrDisplayScreenState extends State<EventQrDisplayScreen> {
  static const int _rotationSeconds = 30;

  late String _currentQrData;
  late int _attendeesCount;

  int _secondsRemaining = _rotationSeconds;
  bool _justRotated = false;
  String _rotationReason = '';

  Timer? _countdownTimer;
  Timer? _pollingTimer;
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _attendeesCount = widget.event.attendeesCount;
    _currentQrData = _generateDynamicQr();
    _startTimers();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _badgeTimer?.cancel();
    super.dispose();
  }

  /// Genera una URL web dinámica con timestamp y nonce aleatorio para rotar el QR
  String _generateDynamicQr() {
    final baseUrl = ApiConfig.eventPublicRegistrationUrl(widget.event.id);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nonce = Random().nextInt(999999).toString().padLeft(6, '0');
    final separator = baseUrl.contains('?') ? '&' : '?';
    return '$baseUrl${separator}t=$timestamp&nonce=$nonce';
  }

  void _startTimers() {
    // 1. Temporizador de cuenta regresiva de 30 segundos
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        _rotateQr(reason: 'Renovado automáticamente por tiempo (30s)');
      }
    });

    // 2. Sondeo en tiempo real cada 1.5 segundos para detectar nuevos registros
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _checkNewAttendees();
    });
  }

  /// Consulta al backend si hay un nuevo asistente registrado al evento
  Future<void> _checkNewAttendees() async {
    if (!mounted) return;
    try {
      final res = await ApiClient.get(ApiConfig.eventById(widget.event.id), requiresAuth: false);
      if (res is Map<String, dynamic> && mounted) {
        int latestCount = 0;
        if (res['attendees_count'] is int) {
          latestCount = res['attendees_count'] as int;
        } else if (res['attendees'] is List) {
          latestCount = (res['attendees'] as List).length;
        }

        // Si se detecta un nuevo registro de participante:
        if (latestCount > _attendeesCount) {
          _attendeesCount = latestCount;
          HapticFeedback.heavyImpact();
          _rotateQr(
            reason: '¡NUEVO REGISTRO CONFIRMADO! Código QR renovado',
            highlight: true,
          );
        }
      }
    } catch (_) {
      // Ignorar errores silenciosos en sondeo de fondo
    }
  }

  /// Rota visualmente el código QR y reinicia el contador de 30s
  void _rotateQr({required String reason, bool highlight = false}) {
    if (!mounted) return;

    _badgeTimer?.cancel();
    setState(() {
      _currentQrData = _generateDynamicQr();
      _secondsRemaining = _rotationSeconds;
      _justRotated = true;
      _rotationReason = reason;
    });

    _badgeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _justRotated = false);
      }
    });

    if (highlight) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Asistencia registrada! Total participantes: $_attendeesCount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    // Tamaño adaptativo del QR para iPad, Tablet, Monitor o Teléfono
    final double qrBoxSize = isWide
        ? 360.0
        : (isTablet ? 320.0 : (size.width < 360 ? 210.0 : 250.0));

    final progressRatio = (_secondsRemaining / _rotationSeconds).clamp(0.0, 1.0);
    final progressColor = _secondsRemaining > 10
        ? const Color(0xFF16A34A)
        : (_secondsRemaining > 5 ? const Color(0xFFEAB308) : const Color(0xFFEF4444));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Código QR del Evento',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: ThemeService.cardBg(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew_rounded),
            tooltip: 'Renovar Código QR ahora',
            onPressed: () {
              HapticFeedback.lightImpact();
              _rotateQr(reason: 'Código renovado manualmente');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
              vertical: isTablet ? 28 : 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 760 : (isTablet ? 600 : 480),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Encabezado del Evento
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isTablet ? 22 : 16),
                    decoration: BoxDecoration(
                      color: ThemeService.cardBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ThemeService.cardBorder(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThemeService.primaryColor(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.event.type.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: ThemeService.primaryColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // Contador en vivo de Asistentes Confirmados
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey(_attendeesCount),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$_attendeesCount Asistentes',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.event.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_outlined, size: 15, color: ThemeService.subtextColor(context)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.event.location,
                                style: TextStyle(fontSize: 13, color: ThemeService.subtextColor(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Banner animado al renovar código por escaneo
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _justRotated
                        ? Container(
                            key: const ValueKey('rotated_banner'),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.autorenew_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _rotationReason.isNotEmpty ? _rotationReason : '¡CÓDIGO QR RENOVADO!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty_banner')),
                  ),

                  // 3. Tarjeta del Código QR Dinámico
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    padding: EdgeInsets.all(isTablet ? 26 : 18),
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
                              ? const Color(0xFF16A34A).withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: _justRotated ? 24 : 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: QrImageView(
                            key: ValueKey(_currentQrData),
                            data: _currentQrData,
                            version: QrVersions.auto,
                            size: qrBoxSize,
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

                        // Badge Oficial IIAP
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 15, color: Color(0xFF16A34A)),
                              SizedBox(width: 6),
                              Text(
                                'CÓDIGO OFICIAL IIAP',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Barra y Contador Regresivo de 30 Segundos
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined, size: 16, color: progressColor),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Renovación en:',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_secondsRemaining}s',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: progressColor,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progressRatio,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Instrucción clara para asistentes
                  Text(
                    'Muestra o proyecta este código en el monitor o pantalla del auditorio.\nEl código se renueva automáticamente cada 30 segundos o al instante tras cada escaneo para máxima seguridad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 13.5 : 12.5,
                      color: ThemeService.subtextColor(context),
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 5. Botones de Acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: ThemeService.primaryColor(context)),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _currentQrData));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enlace oficial copiado al portapapeles'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(Icons.copy_rounded, color: ThemeService.primaryColor(context), size: 18),
                          label: Text(
                            'Copiar Enlace',
                            style: TextStyle(
                              color: ThemeService.primaryColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 14 : 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Cerrar',
                          height: isTablet ? 50 : 45,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
