import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserData = 'auth_user_data';
  static const String _keyDeviceId = 'unique_device_id_v1';

  /// Obtiene o genera un identificador único persistente para este celular (Anti-Préstamo)
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rand = (now ^ 0x5DEECE66D).abs().toRadixString(16);
      deviceId = 'device_${now}_$rand';
      await prefs.setString(_keyDeviceId, deviceId);
    }
    return deviceId;
  }

  static UserModel? get currentUser => currentUserNotifier.value;
  static final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);
  static final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final userJson = prefs.getString(_keyUserData);

    if (token != null && token.isNotEmpty && userJson != null) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        currentUserNotifier.value = UserModel.fromJson(map);
        isAuthenticatedNotifier.value = true;
      } catch (e) {
        debugPrint('Error decodificando usuario en caché: $e');
        await clearSession();
      }
    } else {
      currentUserNotifier.value = null;
      isAuthenticatedNotifier.value = false;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> saveSession({required String token, required UserModel user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserData, jsonEncode(user.toJson()));

    currentUserNotifier.value = user;
    isAuthenticatedNotifier.value = true;
  }

  static Future<void> updateCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode(user.toJson()));
    currentUserNotifier.value = user;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserData);

    currentUserNotifier.value = null;
    isAuthenticatedNotifier.value = false;
  }
}

