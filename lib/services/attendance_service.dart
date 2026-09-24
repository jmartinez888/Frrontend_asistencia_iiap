import '../config/api_config.dart';
import '../models/attendance_model.dart';
import '../models/qr_model.dart';
import 'api_client.dart';

class AttendanceService {
  // 1. Generar nuevo QR de asistencia (Admin o Supervisor)
  static Future<QrGeneratedResponse> generateAttendanceQr() async {
    final response = await ApiClient.post(ApiConfig.attendanceGenerateQr);
    return QrGeneratedResponse.fromJson(response as Map<String, dynamic>);
  }

  // 1.1 Obtener o refrescar el QR de asistencia activo
  static Future<QrGeneratedResponse> getActiveAttendanceQr() async {
    final response = await ApiClient.get(ApiConfig.attendanceActiveQr);
    return QrGeneratedResponse.fromJson(response as Map<String, dynamic>);
  }

  // 2. Generar QR para designar Supervisor (Solo ADMIN)
  static Future<QrGeneratedResponse> generateSupervisorQr() async {
    final response = await ApiClient.post(ApiConfig.attendanceGenerateSupervisorQr);
    return QrGeneratedResponse.fromJson(response as Map<String, dynamic>);
  }

  // 3. Escaneo de QR de Asistencia para registrar Entrada o Salida
  static Future<AttendanceScanResult> scanAttendanceQr({
    required String qrCode,
    double? latitude,
    double? longitude,
    String? deviceId,
    AttendanceType? type,
    AttendanceShift? shift,
  }) async {
    final body = <String, dynamic>{
      'qr_code': qrCode.trim(),
    };
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (deviceId != null) body['device_id'] = deviceId;
    if (type != null) body['type'] = type.name;
    if (shift != null) body['shift'] = shift.name;

    final response = await ApiClient.post(ApiConfig.attendanceScanQr, body: body);
    return AttendanceScanResult.fromJson(response as Map<String, dynamic>);
  }

  // 4. Escaneo de QR para ascender a Supervisor
  static Future<Map<String, dynamic>> scanSupervisorQr(String qrCode) async {
    final response = await ApiClient.post(
      ApiConfig.attendanceScanSupervisorQr,
      body: {'qr_code': qrCode.trim()},
    );
    return response as Map<String, dynamic>;
  }

  // 5. Historial de asistencias del usuario conectado
  static Future<List<AttendanceModel>> getMyRecords() async {
    final response = await ApiClient.get(ApiConfig.attendanceMyRecords);
    if (response is List) {
      return response.map((item) => AttendanceModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // 6. Asistencias de hoy del usuario conectado
  static Future<List<AttendanceModel>> getTodayRecords() async {
    final response = await ApiClient.get(ApiConfig.attendanceToday);
    if (response is List) {
      return response.map((item) => AttendanceModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // 7. Todas las asistencias registradas en la institucion (Admin y Supervisores)
  static Future<List<AttendanceModel>> getAllRecords() async {
    final response = await ApiClient.get(ApiConfig.attendanceAll);
    if (response is List) {
      return response.map((item) => AttendanceModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // 7.1 Consultar colaboradores con salidas pendientes o no registradas (Admin y Supervisores)
  static Future<List<Map<String, dynamic>>> getPendingCheckouts() async {
    final response = await ApiClient.get(ApiConfig.attendancePendingCheckouts);
    if (response is List) {
      return response.map((item) => item as Map<String, dynamic>).toList();
    }
    return [];
  }

  // 8. Reinicio semanal del historial de asistencias (Solo ADMIN)
  static Future<Map<String, dynamic>> clearWeeklyHistory() async {
    final response = await ApiClient.delete(ApiConfig.attendanceWeeklyReset);
    return response as Map<String, dynamic>;
  }

  /// Registrar asistencia manual de contingencia (Supervisor o Admin)
  static Future<Map<String, dynamic>> registerManualAttendance({
    String? userId,
    String? dni,
    required String type,
    String? shift,
    required String observation,
  }) async {
    final response = await ApiClient.post(
      '${ApiConfig.baseUrl}/attendance/manual-record',
      body: {
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (dni != null && dni.isNotEmpty) 'dni': dni,
        'type': type,
        if (shift != null && shift.isNotEmpty) 'shift': shift,
        'observation': observation,
      },
    );
    return response as Map<String, dynamic>;
  }
}
