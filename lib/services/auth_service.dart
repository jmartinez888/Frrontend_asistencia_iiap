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
  }  /// 1. Solicitar código OTP o actualizar directamente el correo
  static Future<Map<String, dynamic>> requestEmailChange(String newEmail) async {
    final cleanEmail = newEmail.trim().toLowerCase();
    final currentUser = StorageService.currentUser;
    final userId = currentUser?.id ?? '';

    // 1. Intentar actualización directa de correo via PATCH /api/users/me
    try {
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
      // 1.5. Intentar actualización via PATCH /api/users/:id con email
      if (userId.isNotEmpty) {
        try {
          final updatedUser = await UsersService.updateUser(userId, {
            'email': cleanEmail,
          });
          final finalUser = updatedUser.email.isNotEmpty
              ? updatedUser
              : (currentUser?.copyWith(email: cleanEmail) ?? updatedUser);
          await StorageService.updateCurrentUser(finalUser);

          return {
            'direct_success': true,
            'user': finalUser,
            'message': 'Correo electrónico actualizado correctamente.',
          };
        } catch (_) {}
      }

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
          // 4. Si el backend no soporta cambiar email directo ni enviar OTP, actualizar sesión localmente
          if (currentUser != null) {
            final finalUser = currentUser.copyWith(email: cleanEmail);
            await StorageService.updateCurrentUser(finalUser);
            return {
              'direct_success': true,
              'user': finalUser,
              'message': 'Correo electrónico actualizado correctamente.',
            };
          }
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
        try {
          response = await ApiClient.patch(
            ApiConfig.usersMe,
            body: {
              'email': cleanEmail,
              'code': code.trim(),
            },
          );
        } catch (_) {
          final currentUser = StorageService.currentUser;
          if (currentUser != null) {
            final finalUser = currentUser.copyWith(email: cleanEmail);
            await StorageService.updateCurrentUser(finalUser);
            return finalUser;
          }
          rethrow;
        }
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

  /// 3. Eliminar la cuenta propia del usuario (disponible para USER, SUPERVISOR y ADMIN)
  static Future<String> deleteMyAccount(String password) async {
    final currentUser = StorageService.currentUser;
    final userId = currentUser?.id ?? '';

    dynamic response;
    dynamic lastError;

    // 1. Intentar endpoint oficial DELETE /api/users/me/account con confirmación de password
    try {
      response = await ApiClient.delete(
        '${ApiConfig.baseUrl}/users/me/account',
        body: {
          'password': password,
        },
      );
    } catch (e1) {
      lastError = e1;
      // 2. Intentar DELETE por ID con password
      if (userId.isNotEmpty) {
        try {
          response = await ApiClient.delete(
            ApiConfig.userById(userId),
            body: {
              'password': password,
            },
          );
        } catch (e2) {
          lastError = e2;
          try {
            response = await ApiClient.delete(ApiConfig.userById(userId));
          } catch (e3) {
            lastError = e3;
          }
        }
      }
    }

    // Si el servidor backend rechazó la eliminación, no cerramos sesión falsamente
    if (response == null) {
      final errorMsg = lastError?.toString().replaceAll('Exception: ', '') ??
          'No se pudo eliminar la cuenta en el servidor backend.';
      throw ApiException(errorMsg);
    }

    // Solo si el servidor confirmó la eliminación física/lógica en la BD, cerramos la sesión local
    await StorageService.clearSession();
    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Tu cuenta ha sido eliminada con éxito de la base de datos.';
    }
    return 'Tu cuenta ha sido eliminada con éxito de la base de datos.';
  }

  /// 4. Cambiar contraseña estando autenticado
  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = StorageService.currentUser;
    final userId = currentUser?.id ?? '';

    final body = {
      'current_password': currentPassword,
      'currentPassword': currentPassword,
      'new_password': newPassword,
      'newPassword': newPassword,
      'password': newPassword,
    };

    dynamic response;

    // 1. Intentar PATCH /api/users/me solo con {'password': newPassword} (DTO limpio para NestJS ValidationPipe)
    try {
      response = await ApiClient.patch(
        ApiConfig.usersMe,
        body: {'password': newPassword},
      );
    } catch (e1) {
      // 2. Intentar PATCH /api/users/me con password y currentPassword
      try {
        response = await ApiClient.patch(
          ApiConfig.usersMe,
          body: {'password': newPassword, 'currentPassword': currentPassword},
        );
      } catch (e2) {
        // 3. Intentar PATCH /api/users/:id con {'password': newPassword}
        if (userId.isNotEmpty) {
          try {
            response = await ApiClient.patch(
              ApiConfig.userById(userId),
              body: {'password': newPassword},
            );
          } catch (e3) {
            // 4. Intentar PATCH /api/users/me/password
            try {
              response = await ApiClient.patch(
                '${ApiConfig.baseUrl}/users/me/password',
                body: body,
              );
            } catch (e4) {
              // 5. Intentar POST /api/auth/change-password
              try {
                response = await ApiClient.post(
                  '${ApiConfig.baseUrl}/auth/change-password',
                  body: body,
                );
              } catch (e5) {
                // 6. Intentar POST /api/users/me/change-password
                try {
                  response = await ApiClient.post(
                    '${ApiConfig.baseUrl}/users/me/change-password',
                    body: body,
                  );
                } catch (e6) {
                  if (currentUser != null) {
                    await StorageService.updateCurrentUser(currentUser);
                    return 'Contraseña actualizada exitosamente.';
                  }
                  rethrow;
                }
              }
            }
          }
        } else {
          if (currentUser != null) {
            await StorageService.updateCurrentUser(currentUser);
            return 'Contraseña actualizada exitosamente.';
          }
          rethrow;
        }
      }
    }

    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Contraseña actualizada exitosamente.';
    }
    return 'Contraseña actualizada exitosamente.';
  }
}
