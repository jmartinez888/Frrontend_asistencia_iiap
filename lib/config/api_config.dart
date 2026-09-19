import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _customHostKey = 'custom_backend_host';

  // Obtiene la URL base adecuada según el entorno de ejecución
  static String get defaultBaseUrl {
    return 'https://dev-api-control.iiap.gob.pe/api';
  }

  static const String localWifiUrl = 'http://192.168.1.108:3000/api';
  static const String androidEmulatorUrl = 'http://10.0.2.2:3000/api';


  static String _currentBaseUrl = defaultBaseUrl;

  static String get baseUrl => _currentBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_customHostKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _currentBaseUrl = saved.trim();
    } else {
      _currentBaseUrl = defaultBaseUrl;
    }
  }

  static Future<void> setCustomBaseUrl(String url) async {
    final trimmed = url.trim();
    _currentBaseUrl = trimmed.isEmpty ? defaultBaseUrl : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_customHostKey);
    } else {
      await prefs.setString(_customHostKey, trimmed);
    }
  }

  // Rutas de la API
  static String get authRegister => '$baseUrl/auth/register';
  static String get authLogin => '$baseUrl/auth/login';
  static String get authMe => '$baseUrl/auth/me';
  static String get authForgotPassword => '$baseUrl/auth/forgot-password';
  static String get authResetPassword => '$baseUrl/auth/reset-password';

  static String get usersMe => '$baseUrl/users/me';
  static String get usersAll => '$baseUrl/users';
  static String get usersSupervisors => '$baseUrl/users/supervisors';
  static String userById(String id) => '$baseUrl/users/$id';
  static String userRevokeSupervisor(String id) => '$baseUrl/users/supervisors/$id';
  static String userRole(String id) => '$baseUrl/users/$id/role';
  static String get uploadPhotoBase64 => '$baseUrl/users/me/photo-base64';

  static String get attendanceGenerateQr => '$baseUrl/attendance/generate-qr';
  static String get attendanceActiveQr => '$baseUrl/attendance/active-qr';
  static String get attendanceGenerateSupervisorQr => '$baseUrl/attendance/generate-supervisor-qr';
  static String get attendanceScanQr => '$baseUrl/attendance/scan-qr';
  static String get attendanceScanSupervisorQr => '$baseUrl/attendance/scan-supervisor-qr';
  static String get attendanceMyRecords => '$baseUrl/attendance/my-records';
  static String get attendanceToday => '$baseUrl/attendance/today';
  static String get attendanceAll => '$baseUrl/attendance/all';
  static String get attendanceWeeklyReset => '$baseUrl/attendance/weekly-reset';
}

