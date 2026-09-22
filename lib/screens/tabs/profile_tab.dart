import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/users_service.dart';
import '../../services/theme_service.dart';
import '../../services/wallpaper_service.dart';
import '../../services/api_client.dart';
import '../../widgets/opera_gx_theme_picker.dart';
import '../wallpaper_screen.dart';
import '../login_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await UsersService.uploadPhotoBase64(base64Image);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Foto de perfil actualizada correctamente.'),
            ],
          ),
          backgroundColor: ThemeService.primaryColor(context),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir foto: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13111C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: ThemeService.cardBorder(ctx),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'FOTO DE PERFIL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: ThemeService.primaryColor(ctx),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeService.containerColor(ctx),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: ThemeService.primaryColor(ctx),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Tomar Foto con la Cámara',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Usa la cámara de tu teléfono móvil',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeService.containerColor(ctx),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: ThemeService.primaryColor(ctx),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Elegir de la Galería',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Selecciona una imagen de tu galería',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  // --- DIÁLOGO PARA CAMBIAR CONTRASEÑA CON REQUISITOS FUERTES Y SÍMBOLOS ---
  Future<void> _showChangePasswordDialog(UserModel user) async {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = ThemeService.primaryColor(context);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: ThemeService.cardBg(context),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lock_reset_rounded, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cambiar Contraseña',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'La nueva contraseña debe ser fuerte e incluir al menos una mayúscula, minúscula, número y un símbolo especial (!@#\$%).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contraseña Actual
                  const Text('Contraseña Actual *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: currentPwController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      hintText: 'Tu contraseña actual',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nueva Contraseña
                  const Text('Nueva Contraseña Fuerte *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPwController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      hintText: 'Mínimo 8 caract. con símbolos',
                      prefixIcon: const Icon(Icons.security_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Confirmar Nueva Contraseña
                  const Text('Confirmar Nueva Contraseña *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPwController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      hintText: 'Repite la nueva contraseña',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final currentPw = currentPwController.text.trim();
                        final newPw = newPwController.text.trim();
                        final confirmPw = confirmPwController.text.trim();

                        if (currentPw.isEmpty) {
                          setModalState(() => errorMessage = 'Ingresa tu contraseña actual.');
                          return;
                        }
                        if (newPw.length < 8) {
                          setModalState(() => errorMessage = 'La nueva contraseña debe tener al menos 8 caracteres.');
                          return;
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(newPw)) {
                          setModalState(() => errorMessage = 'Debe incluir al menos una letra mayúscula (A-Z).');
                          return;
                        }
                        if (!RegExp(r'[a-z]').hasMatch(newPw)) {
                          setModalState(() => errorMessage = 'Debe incluir al menos una letra minúscula (a-z).');
                          return;
                        }
                        if (!RegExp(r'\d').hasMatch(newPw)) {
                          setModalState(() => errorMessage = 'Debe incluir al menos un número (0-9).');
                          return;
                        }
                        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/;~`]').hasMatch(newPw)) {
                          setModalState(() => errorMessage = 'Debe incluir al menos un símbolo especial (!@#\$%).');
                          return;
                        }
                        if (newPw != confirmPw) {
                          setModalState(() => errorMessage = 'Las nuevas contraseñas no coinciden.');
                          return;
                        }
                        if (newPw == currentPw) {
                          setModalState(() => errorMessage = 'La nueva contraseña no puede ser igual a la actual.');
                          return;
                        }

                        setModalState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        try {
                          final msg = await AuthService.changePassword(
                            currentPassword: currentPw,
                            newPassword: newPw,
                          );

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isSubmitting = false;
                            errorMessage = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Actualizar Contraseña'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DIÁLOGO DE CAMBIO DE CORREO ELECTRÓNICO (PASO 1: ENVIAR OTP -> PASO 2: CONFIRMAR) ---
  Future<void> _showChangeEmailDialog(UserModel user) async {
    final newEmailController = TextEditingController();
    final otpController = TextEditingController();
    int step = 1;
    bool isSubmitting = false;
    String? currentError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = ThemeService.primaryColor(context);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: ThemeService.cardBg(context),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: step == 1
                        ? primaryColor.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    step == 1 ? Icons.mark_email_read_outlined : Icons.lock_clock_rounded,
                    color: step == 1 ? primaryColor : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step == 1 ? 'Cambiar Correo' : 'Verificar Código',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step == 1) ...[
                    Text(
                      'Se conservarán todas tus asistencias, fotos y permisos. Solo cambiará tu correo de acceso.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Correo Actual (Solo lectura)
                    const Text('Correo actual:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nuevo Correo
                    const Text('Nuevo correo electrónico *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Ingresa tu nuevo correo (@...com)',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Te enviaremos un código de seguridad de 6 dígitos a este nuevo correo.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Ingresa el código de 6 dígitos enviado a:\n${newEmailController.text.trim().toLowerCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Campo Código OTP
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            counterText: '',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('Reenviar código', style: TextStyle(fontSize: 12)),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final email = newEmailController.text.trim().toLowerCase();
                                setModalState(() => isSubmitting = true);
                                try {
                                  await AuthService.requestEmailChange(email);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Código reenviado exitosamente.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isSubmitting = false);
                                }
                              },
                      ),
                    ),
                  ],

                  if (currentError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              currentError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: step == 1 ? primaryColor : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newEmail = newEmailController.text.trim().toLowerCase();

                        if (step == 1) {
                          // Validaciones Paso 1
                          if (newEmail.isEmpty) {
                            setModalState(() => currentError = 'Ingresa el nuevo correo electrónico.');
                            return;
                          }
                          if (!newEmail.contains('@') || !newEmail.endsWith('.com')) {
                            setModalState(() => currentError = 'El correo debe ser válido y terminar en .com');
                            return;
                          }
                          if (newEmail == user.email.toLowerCase()) {
                            setModalState(() => currentError = 'El nuevo correo no puede ser igual al actual.');
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            currentError = null;
                          });

                          try {
                            await AuthService.requestEmailChange(newEmail);
                            setModalState(() {
                              step = 2;
                              isSubmitting = false;
                            });
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              currentError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        } else {
                          // Validaciones Paso 2
                          final code = otpController.text.trim();
                          if (code.length != 6) {
                            setModalState(() => currentError = 'El código debe tener exactamente 6 dígitos.');
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            currentError = null;
                          });

                          try {
                            final updated = await AuthService.confirmEmailChange(
                              newEmail: newEmail,
                              code: code,
                            );

                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('¡Correo actualizado con éxito a ${updated.email}!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              currentError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(step == 1 ? 'Enviar Código' : 'Confirmar Cambio'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DIÁLOGO PARA ELIMINAR / DESACTIVAR CUENTA PROPIA ---
  Future<void> _showDeleteAccountDialog(UserModel user) async {
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: ThemeService.cardBg(context),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Eliminar Cuenta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Estás seguro de que deseas eliminar tu cuenta de ${user.fullName}?\n\nEsta acción desactivará permanentemente tu acceso al Sistema de Asistencias del IIAP.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ingresa tu contraseña para confirmar *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Tu contraseña actual',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pw = passwordController.text.trim();
                        if (pw.isEmpty) {
                          setModalState(() => errorMessage = 'Debes ingresar tu contraseña actual.');
                          return;
                        }

                        setModalState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        try {
                          await AuthService.deleteMyAccount(pw);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isSubmitting = false;
                            errorMessage = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Eliminar Definitivamente'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout();
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Responsive.constrained(
              context,
              maxTabletWidth: 780,
              child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Mi Perfil Institucional',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Avatar con Botón de Cámara (Cámara / Galería)
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: Responsive.isTablet(context) ? 72 : 54,
                        backgroundColor: isDark ? ThemeService.cardBorder(context) : const Color(0xFFE2E8F0),
                        backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null || user.photoUrl!.isEmpty
                            ? Text(
                                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : ThemeService.primaryColor(context),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThemeService.primaryColor(context),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2.5,
                              ),
                            ),
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),

                // Badge de Rol
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: ThemeService.containerColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeService.primaryColor(context).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    user.role.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ThemeService.primaryColor(context),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tarjeta de Datos Laborales
                _buildInfoCard(
                  context,
                  title: 'Información Institucional',
                  items: [
                    _InfoRow(icon: Icons.work_outline_rounded, label: 'Cargo', value: user.position ?? 'Sin cargo asignado'),
                    _InfoRow(icon: Icons.account_tree_outlined, label: 'Área / Depto', value: user.department ?? 'IIAP Central'),
                    _InfoRow(icon: Icons.badge_outlined, label: 'DNI / Doc', value: user.documentNumber ?? 'No registrado'),
                    _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: user.phoneNumber ?? 'No registrado'),
                  ],
                ),

                const SizedBox(height: 16),

                // Tarjeta de Personalización Estilo Opera GX
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ThemeService.cardBg(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeService.cardBorder(context),
                      width: 1.2,
                    ),
                  ),
                  child: const OperaGxThemePicker(),
                ),

                const SizedBox(height: 16),

                // Tarjeta Acceso a Fondo de Pantalla Personalizado (Estilo Opera GX)
                ValueListenableBuilder<WallpaperItem>(
                  valueListenable: WallpaperService.wallpaperNotifier,
                  builder: (context, wallpaper, _) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WallpaperScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: ThemeService.cardBg(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ThemeService.cardBorder(context),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ThemeService.containerColor(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.wallpaper_rounded,
                                color: ThemeService.primaryColor(context),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FONDO DE PANTALLA',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    wallpaper.hasWallpaper
                                        ? 'Activo: ${wallpaper.title}'
                                        : 'Color sólido predeterminado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: ThemeService.primaryColor(context).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Cambiar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: ThemeService.primaryColor(context),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: ThemeService.primaryColor(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                
                // Tarjeta de Seguridad y Gestión de Cuenta (Cambiar Correo y Borrar Cuenta)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ThemeService.cardBg(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeService.cardBorder(context),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security_outlined,
                            size: 18,
                            color: ThemeService.primaryColor(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SEGURIDAD Y CUENTA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Opción: Cambiar Correo Electrónico
                      // Opción: Cambiar Contraseña
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThemeService.containerColor(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            color: ThemeService.primaryColor(context),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Cambiar Contraseña',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          'Mínimo 8 caract., mayúscula, número y símbolos',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: ThemeService.primaryColor(context),
                        ),
                        onTap: () => _showChangePasswordDialog(user),
                      ),

                      Divider(color: isDark ? Colors.white12 : Colors.black12, height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThemeService.containerColor(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            color: ThemeService.primaryColor(context),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Cambiar Correo Electrónico',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          'Actualiza tu correo sin perder asistencias ni rol',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: ThemeService.primaryColor(context),
                        ),
                        onTap: () => _showChangeEmailDialog(user),
                      ),

                      Divider(color: isDark ? Colors.white12 : Colors.black12, height: 16),

                      // Opción: Eliminar Mi Cuenta
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Eliminar Mi Cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        subtitle: Text(
                          'Desactiva tu acceso permanentemente',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFEF4444),
                        ),
                        onTap: () => _showDeleteAccountDialog(user),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Botón Cerrar Sesión
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Cerrar Sesión',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required List<_InfoRow> items}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ThemeService.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThemeService.cardBorder(context),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(it.icon, size: 20, color: ThemeService.primaryColor(context)),
                    const SizedBox(width: 12),
                    Text(
                      it.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      it.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
}
