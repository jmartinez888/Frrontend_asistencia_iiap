import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/event_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

class EventService {
  static const String _localEventsKey = 'local_stored_events_v1';
  static final ValueNotifier<List<EventModel>> eventsNotifier = ValueNotifier<List<EventModel>>([]);

  /// Inicializa los eventos desde el backend o desde SharedPreferences local
  static Future<List<EventModel>> getEvents({bool forceRefresh = false}) async {
    // 1. Intentar obtener desde el backend
    try {
      final response = await ApiClient.get(ApiConfig.eventsAll);
      if (response != null && response is List) {
        final list = response
            .whereType<Map<String, dynamic>>()
            .map((json) => EventModel.fromJson(json))
            .where((e) => !e.id.startsWith('evt_seed_'))
            .toList();
        list.sort((a, b) => b.startDate.compareTo(a.startDate));
        eventsNotifier.value = list;
        await _saveToLocalCache(list);
        return list;
      }
    } catch (e) {
      debugPrint('EventService: backend no disponible o sin endpoint (/api/events). Usando caché local: $e');
    }

    // 2. Fallback a caché local persistente
    final localList = await _loadFromLocalCache();
    // Limpiar cualquier evento de ejemplo previo que haya quedado guardado en memoria del celular
    final cleanList = localList.where((e) => !e.id.startsWith('evt_seed_')).toList();
    if (cleanList.length != localList.length) {
      await _saveToLocalCache(cleanList);
    }

    cleanList.sort((a, b) => b.startDate.compareTo(a.startDate));
    eventsNotifier.value = cleanList;
    return cleanList;
  }

  /// Crea un nuevo evento (Solo Admin o Supervisor)
  static Future<EventModel> createEvent({
    required String title,
    required String description,
    required String location,
    required DateTime startDate,
    required DateTime endDate,
    required EventType type,
    required bool requiresAttendance,
  }) async {
    final currentUser = StorageService.currentUser;
    if (currentUser == null || !currentUser.canManageAttendanceQr) {
      throw ApiException('Solo los Administradores y Supervisores pueden crear eventos.', 403);
    }

    final newId = 'evt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final qrToken = 'IIAP-EVT-$newId-${DateTime.now().millisecondsSinceEpoch}';

    final event = EventModel(
      id: newId,
      title: title.trim(),
      description: description.trim(),
      location: location.trim(),
      startDate: startDate,
      endDate: endDate,
      type: type,
      requiresAttendance: requiresAttendance,
      qrCode: qrToken,
      createdById: currentUser.id,
      createdByName: currentUser.fullName,
      createdByRole: currentUser.role.name,
      createdAt: DateTime.now(),
      status: EventStatus.UPCOMING,
      attendeesCount: 0,
      attendees: [],
    );

    // Intentar guardar en backend
    try {
      final createPayload = {
        'title': title.trim(),
        'description': description.trim(),
        'location': location.trim(),
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'type': type.name,
        'requires_attendance': requiresAttendance,
        'qr_code': qrToken,
      };
      final res = await ApiClient.post(
        ApiConfig.eventsAll,
        body: createPayload,
      );
      if (res is Map<String, dynamic>) {
        final serverEvent = EventModel.fromJson(res);
        final current = List<EventModel>.from(eventsNotifier.value);
        current.insert(0, serverEvent);
        eventsNotifier.value = current;
        await _saveToLocalCache(current);
        return serverEvent;
      }
    } catch (e) {
      debugPrint('EventService: Guardando evento de forma local (fallback backend): $e');
    }

    // Guardado local
    final current = List<EventModel>.from(eventsNotifier.value);
    current.insert(0, event);
    eventsNotifier.value = current;
    await _saveToLocalCache(current);
    return event;
  }

  /// Actualiza un evento
  static Future<EventModel> updateEvent(EventModel event) async {
    try {
      final updatePayload = {
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'start_date': event.startDate.toIso8601String(),
        'end_date': event.endDate.toIso8601String(),
        'type': event.type.name,
        'requires_attendance': event.requiresAttendance,
        'status': event.status.name,
      };
      final res = await ApiClient.patch(
        ApiConfig.eventById(event.id),
        body: updatePayload,
      );
      if (res is Map<String, dynamic>) {
        final updated = EventModel.fromJson(res);
        _updateLocalList(updated);
        return updated;
      }
    } catch (_) {}

    _updateLocalList(event);
    return event;
  }

  static void _updateLocalList(EventModel updated) {
    final list = List<EventModel>.from(eventsNotifier.value);
    final idx = list.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    eventsNotifier.value = list;
    _saveToLocalCache(list);
  }

  /// Elimina o cancela un evento
  static Future<void> deleteEvent(String eventId) async {
    final currentUser = StorageService.currentUser;
    if (currentUser == null || !currentUser.canManageAttendanceQr) {
      throw ApiException('Solo Administradores y Supervisores pueden eliminar eventos.', 403);
    }

    try {
      await ApiClient.delete(ApiConfig.eventById(eventId));
    } catch (_) {}

    final list = List<EventModel>.from(eventsNotifier.value);
    list.removeWhere((e) => e.id == eventId);
    eventsNotifier.value = list;
    await _saveToLocalCache(list);
  }

  /// Registra la asistencia de un colaborador a un evento
  static Future<EventModel> registerAttendance({
    required String eventId,
    String? qrCode,
  }) async {
    final currentUser = StorageService.currentUser;
    if (currentUser == null) {
      throw ApiException('Debes iniciar sesión para marcar asistencia.', 401);
    }

    // 1. Intentar llamada al backend
    try {
      final body = {
        'user_id': currentUser.id,
        'user_name': currentUser.fullName,
        'user_email': currentUser.email,
        'user_position': currentUser.position ?? '',
        'user_department': currentUser.department ?? '',
        'document_number': currentUser.documentNumber ?? '',
        'phone_number': currentUser.phoneNumber ?? '',
        'is_external': false,
        'qr_code': qrCode,
      };
      final res = await ApiClient.post(
        ApiConfig.eventRegisterAttendance(eventId),
        body: body,
      );
      if (res is Map<String, dynamic>) {
        final updated = EventModel.fromJson(res);
        _updateLocalList(updated);
        return updated;
      }
    } on ApiException catch (e) {
      // Propagar errores de validación de negocio del backend (ej: duplicados, evento cerrado, etc.)
      if (e.statusCode == 400 || e.statusCode == 409 || e.statusCode == 403 || e.statusCode == 404) {
        rethrow;
      }
      debugPrint('EventService: Backend reportó error de red/servidor, evaluando fallback local: $e');
    } catch (e) {
      debugPrint('EventService: Registro de asistencia en backend falló/no existe, procesando local: $e');
    }

    // 2. Fallback de registro local
    var list = List<EventModel>.from(eventsNotifier.value);
    var idx = list.indexWhere((e) => e.id == eventId);
    if (idx == -1) {
      await getEvents(forceRefresh: true);
      list = List<EventModel>.from(eventsNotifier.value);
      idx = list.indexWhere((e) => e.id == eventId);
    }
    if (idx == -1) {
      throw ApiException('El evento seleccionado no existe o ya no está disponible.');
    }

    final targetEvent = list[idx];

    // Verificar si ya registró asistencia
    if (targetEvent.isUserRegistered(currentUser.id)) {
      throw ApiException('Ya registraste tu asistencia para este evento previamente.');
    }

    // Si requiere QR y se suministró un código, validar coincidencia básica
    if (targetEvent.requiresAttendance && qrCode != null && qrCode.isNotEmpty) {
      final matches = targetEvent.qrCode == null ||
          targetEvent.qrCode == qrCode ||
          qrCode.contains(targetEvent.id) ||
          qrCode.contains('id=${targetEvent.id}');
      if (!matches) {
        throw ApiException('El código QR no corresponde a este evento institucional.');
      }
    }

    final newAttendee = EventAttendeeModel(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser.id,
      userName: currentUser.fullName,
      userEmail: currentUser.email,
      userPosition: currentUser.position,
      userDepartment: currentUser.department,
      documentNumber: currentUser.documentNumber,
      phoneNumber: currentUser.phoneNumber,
      isExternal: false,
      registeredAt: DateTime.now(),
      notes: 'Asistencia registrada con éxito',
    );

    final updatedAttendees = List<EventAttendeeModel>.from(targetEvent.attendees)..add(newAttendee);
    final updatedEvent = targetEvent.copyWith(
      attendees: updatedAttendees,
      attendeesCount: updatedAttendees.length,
    );

    list[idx] = updatedEvent;
    eventsNotifier.value = list;
    await _saveToLocalCache(list);
    return updatedEvent;
  }

  // --- Helpers de Caché Local ---

  static Future<void> _saveToLocalCache(List<EventModel> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
      await prefs.setString(_localEventsKey, encoded);
    } catch (e) {
      debugPrint('Error guardando eventos en caché: $e');
    }
  }

  static Future<List<EventModel>> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_localEventsKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((json) => EventModel.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error cargando eventos desde caché: $e');
    }
    return [];
  }
}
