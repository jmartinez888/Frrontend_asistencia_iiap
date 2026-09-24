import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(initSettings);

      // Solicitar permisos en Android 13+
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inicializando NotificationService: $e');
    }
  }

  /// Muestra una notificación local de recordatorio de salida
  static Future<void> showCheckoutReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'checkout_reminders_channel',
        'Recordatorios de Salida IIAP',
        channelDescription: 'Alertas oportunas para el registro de salida del personal',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Error mostrando notificación: $e');
    }
  }

  /// Cancela una notificación específica
  static Future<void> cancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// Evalúa el estado del día y lanza la notificación de salida si corresponde
  /// - Mañana: 13:00 -> "Recuerda marcar tu salida del turno de la mañana."
  /// - Tarde: 18:30 -> "Recuerda marcar tu salida del turno de la tarde."
  static Future<void> checkAndTriggerCheckoutReminder({
    List<AttendanceModel>? preloadedTodayRecords,
  }) async {
    try {
      final now = DateTime.now();
      final nowTotalMinutes = now.hour * 60 + now.minute;
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Obtener marcas de hoy
      final records = preloadedTodayRecords ?? await AttendanceService.getTodayRecords();

      final morningCheckIn = records.cast<AttendanceModel?>().firstWhere(
            (r) => r?.shift == AttendanceShift.MORNING && r?.type == AttendanceType.CHECK_IN,
            orElse: () => null,
          );
      final morningCheckOut = records.cast<AttendanceModel?>().firstWhere(
            (r) => r?.shift == AttendanceShift.MORNING && r?.type == AttendanceType.CHECK_OUT,
            orElse: () => null,
          );

      final afternoonCheckIn = records.cast<AttendanceModel?>().firstWhere(
            (r) => r?.shift == AttendanceShift.AFTERNOON && r?.type == AttendanceType.CHECK_IN,
            orElse: () => null,
          );
      final afternoonCheckOut = records.cast<AttendanceModel?>().firstWhere(
            (r) => r?.shift == AttendanceShift.AFTERNOON && r?.type == AttendanceType.CHECK_OUT,
            orElse: () => null,
          );

      final prefs = await SharedPreferences.getInstance();

      // 1. REGLA TURNO MAÑANA:
      // Salida programada: 13:00 (780 min).
      // Si el usuario marcó ENTRADA en la mañana y AÚN NO marca salida:
      if (morningCheckIn != null && morningCheckOut == null) {
        // Disparar a partir de las 13:00
        if (nowTotalMinutes >= 13 * 60) {
          final morningNotifKey = 'notif_morning_checkout_$dateKey';
          final alreadyNotified = prefs.getBool(morningNotifKey) == true;
          if (!alreadyNotified) {
            await showCheckoutReminder(
              id: 101,
              title: 'Control de Asistencia IIAP',
              body: 'Recuerda marcar tu salida del turno de la mañana.',
            );
            await prefs.setBool(morningNotifKey, true);
          }
        }
      } else if (morningCheckOut != null) {
        // Si ya marcó salida antes de la hora, cancelar recordatorio
        await cancel(101);
      }

      // 2. REGLA TURNO TARDE:
      // Salida programada: 18:30 (1110 min).
      // Si el usuario marcó ENTRADA en la tarde y AÚN NO marca salida:
      if (afternoonCheckIn != null && afternoonCheckOut == null) {
        if (nowTotalMinutes >= 18 * 60 + 30) {
          final afternoonNotifKey = 'notif_afternoon_checkout_$dateKey';
          final alreadyNotified = prefs.getBool(afternoonNotifKey) == true;
          if (!alreadyNotified) {
            await showCheckoutReminder(
              id: 102,
              title: 'Control de Asistencia IIAP',
              body: 'Recuerda marcar tu salida del turno de la tarde.',
            );
            await prefs.setBool(afternoonNotifKey, true);
          }
        }
      } else if (afternoonCheckOut != null) {
        await cancel(102);
      }
    } catch (e) {
      debugPrint('Aviso en checkAndTriggerCheckoutReminder: $e');
    }
  }
}
