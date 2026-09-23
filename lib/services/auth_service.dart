import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'storage_service.dart';
import 'users_service.dart';

class AuthService {
  static Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post(
      ApiConfig.authLogin,
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      requiresAuth: false,
    );

    final token = response['access_token']?.toString() ?? '';
    final userJson = response['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);

    await StorageService.saveSession(token: token, user: user);
    return user;
  }

  static Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    String? documentNumber,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    if (documentNumber != null && documentNumber.trim().isNotEmpty) {
      body['document_number'] = documentNumber.trim();
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      body['phone_number'] = phoneNumber.trim();
    }

    final response = await ApiClient.post(
      ApiConfig.authRegister,
      body: body,
      requiresAuth: false,
    );

    final token = response['access_token']?.toString() ?? '';
    final userJson = response['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);

    await StorageService.saveSession(token: token, user: user);
    return user;
  }

  static Future<UserModel> getProfile() async {
    final response = await ApiClient.get(ApiConfig.authMe);
    final user = UserModel.fromJson(response as Map<String, dynamic>);
    await StorageService.updateCurrentUser(user);
    return user;
  }

  static Future<void> logout() async {
    await StorageService.clearSession();
  }

  static Future<String> forgotPassword(String email) async {
    final response = await ApiClient.post(
      ApiConfig.authForgotPassword,
      body: {
        'email': email.trim().toLowerCase(),
      },
      requiresAuth: false,
    );
    return response['message']?.toString() ?? 'Código de recuperación enviado a tu correo.';
  }

  static Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await ApiClient.post(
      ApiConfig.authResetPassword,
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'new_password': newPassword,
      },
      requiresAuth: false,
    );
    return response['message']?.toString() ?? 'Contraseña actualizada exitosamente.';
  }

  /// 1. Solicitar código OTP o actualizar directamente el correo
  static Future<Map<String, dynamic>> requestEmailChange(String newEmail) async {
    final cleanEmail = newEmail.trim().toLowerCase();

    // 1. Intentar actualización directa de correo via PATCH /api/users/me
    try {
      final currentUser = StorageService.currentUser;
      final updatedUser = await UsersService.updateProfile({
        'email': cleanEmail,
      });

      // Asegurar que el objeto de sesión refleje el nuevo correo
      final finalUser = updatedUser.email.isNotEmpty
          ? updatedUser
          : (currentUser?.copyWith(email: cleanEmail) ?? updatedUser);
      await StorageService.updateCurrentUser(finalUser);

      return {
        'direct_success': true,
        'user': finalUser,
        'message': 'Correo electrónico actualizado correctamente.',
      };
    } catch (e1) {
      // 2. Si PATCH /users/me no permite email directo, intentar POST /auth/request-email-change
      try {
        final response = await ApiClient.post(
          '${ApiConfig.baseUrl}/auth/request-email-change',
          body: {
            'new_email': cleanEmail,
            'email': cleanEmail,
          },
        );
        return {
          'direct_success': false,
          'message': response['message']?.toString() ?? 'Código de verificación enviado al nuevo correo.',
        };
      } catch (e2) {
        // 3. Intentar POST /api/users/me/email
        try {
          final response = await ApiClient.post(
            '${ApiConfig.baseUrl}/users/me/email',
            body: {
              'email': cleanEmail,
              'new_email': cleanEmail,
            },
          );
          return {
            'direct_success': false,
            'message': response['message']?.toString() ?? 'Código de verificación enviado al nuevo correo.',
          };
        } catch (_) {
          rethrow;
        }
      }
    }
  }

  /// 2. Confirmar cambio de correo electrónico con código de 6 dígitos
  static Future<UserModel> confirmEmailChange({
    required String newEmail,
    required String code,
  }) async {
    final cleanEmail = newEmail.trim().toLowerCase();
    dynamic response;

    try {
      response = await ApiClient.post(
        '${ApiConfig.baseUrl}/auth/confirm-email-change',
        body: {
          'new_email': cleanEmail,
          'email': cleanEmail,
          'code': code.trim(),
        },
      );
    } catch (e1) {
      try {
        response = await ApiClient.post(
          '${ApiConfig.baseUrl}/users/me/email/confirm',
          body: {
            'email': cleanEmail,
            'code': code.trim(),
          },
        );
      } catch (e2) {
        response = await ApiClient.patch(
          ApiConfig.usersMe,
          body: {
            'email': cleanEmail,
            'code': code.trim(),
          },
        );
      }
    }

    final data = response as Map<String, dynamic>;
    final userMap = (data['user'] is Map) ? (data['user'] as Map<String, dynamic>) : data;
    final updatedUser = UserModel.fromJson(userMap);
    final finalUser = updatedUser.email.isNotEmpty ? updatedUser : (StorageService.currentUser?.copyWith(email: cleanEmail) ?? updatedUser);

    if (data['access_token'] != null) {
      await StorageService.saveSession(
        token: data['access_token'].toString(),
        user: finalUser,
      );
    } else {
      await StorageService.updateCurrentUser(finalUser);
    }
    return finalUser;
  }

  /// 3. Eliminar / Desactivar la cuenta propia del usuario
  static Future<String> deleteMyAccount(String password) async {
    final currentUser = StorageService.currentUser;
    final userId = currentUser?.id ?? '';

    dynamic response;
    // 1. Intentar DELETE /api/users/me
    try {
      response = await ApiClient.delete(
        ApiConfig.usersMe,
        body: {
          'password': password,
        },
      );
    } catch (e) {
      // 2. Si /users/me no soporta DELETE, intentar DELETE /api/users/:id con password
      if (userId.isNotEmpty) {
        try {
          response = await ApiClient.delete(
            ApiConfig.userById(userId),
            body: {
              'password': password,
            },
          );
        } catch (_) {
          // 3. Si no acepta body en DELETE /users/:id, intentar DELETE /api/users/:id directo
          response = await ApiClient.delete(ApiConfig.userById(userId));
        }
      } else {
        rethrow;
      }
    }

    await StorageService.clearSession();
    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Tu cuenta ha sido eliminada con éxito.';
    }
    return 'Tu cuenta ha sido eliminada con éxito.';
  }
  /// 4. Cambiar contraseña estando autenticado
  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final body = {
      'current_password': currentPassword,
      'currentPassword': currentPassword,
      'new_password': newPassword,
      'newPassword': newPassword,
      'password': newPassword,
    };

    dynamic response;

    // 1. Intentar PATCH /api/users/me/password
    try {
      response = await ApiClient.patch(
        '${ApiConfig.baseUrl}/users/me/password',
        body: body,
      );
    } catch (e1) {
      // 2. Intentar POST /api/auth/change-password
      try {
        response = await ApiClient.post(
          '${ApiConfig.baseUrl}/auth/change-password',
          body: body,
        );
      } catch (e2) {
        // 3. Intentar PATCH /api/users/me
        try {
          response = await ApiClient.patch(
            ApiConfig.usersMe,
            body: body,
          );
        } catch (e3) {
          // 4. Intentar POST /api/users/me/change-password
          response = await ApiClient.post(
            '${ApiConfig.baseUrl}/users/me/change-password',
            body: body,
          );
        }
      }
    }

    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Contraseña actualizada exitosamente.';
    }
    return 'Contraseña actualizada exitosamente.';
  }
}
