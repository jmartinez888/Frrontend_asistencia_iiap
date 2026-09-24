import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/photo_viewer_dialog.dart';
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

  bool _isEditingInstitutionalInfo = false;
  late final TextEditingController _officeController;
  late final TextEditingController _areaController;
  late final TextEditingController _documentController;
  late final TextEditingController _phoneController;
  String _documentType = 'DNI';
  bool _isSavingInstitutionalInfo = false;

  @override
  void initState() {
    super.initState();
    final user = StorageService.currentUser;
    _officeController = TextEditingController(text: user?.office ?? '');
    _areaController = TextEditingController(text: user?.area ?? '');
    _documentController = TextEditingController(text: user?.documentNumber ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _documentType = _detectDocumentType(user?.documentNumber);
  }

  @override
  void dispose() {
    _officeController.dispose();
    _areaController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _detectDocumentType(String? doc) {
    if (doc == null || doc.trim().isEmpty) return 'DNI';
    final clean = doc.replaceAll(RegExp(r'''['"\s]'''), '').trim();
    if (RegExp(r'^\d{8}$').hasMatch(clean)) return 'DNI';
    if (RegExp(r'^[a-zA-Z0-9]{9}$').hasMatch(clean)) return 'CE';
    return 'Pasaporte';
  }

  String _getDocumentLabel(String? doc) {
    if (doc == null || doc.trim().isEmpty) return 'Documento';
    final type = _detectDocumentType(doc);
    if (type == 'CE') return 'CE';
    if (type == 'Pasaporte') return 'Pasaporte';
    return 'DNI';
  }

  void _startEditingInstitutionalInfo(UserModel user) {
    setState(() {
      _officeController.text = user.office;
      _areaController.text = user.area;
      _documentController.text = user.documentNumber ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _documentType = _detectDocumentType(user.documentNumber);
      _isEditingInstitutionalInfo = true;
    });
  }

  Future<void> _saveInstitutionalInfo(UserModel user) async {
    final newOffice = _officeController.text.trim();
    final newArea = _areaController.text.trim();
    final newDoc = _documentController.text.replaceAll(RegExp(r'''['"\s]'''), '').trim();
    final newPhone = _phoneController.text.replaceAll(RegExp(r'''['"\s]'''), '').trim();

    // Validar formato de documento si fue ingresado
    if (newDoc.isNotEmpty) {
      if (_documentType == 'DNI' && (!RegExp(r'^\d{8}$').hasMatch(newDoc))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El DNI debe tener exactamente 8 dígitos numéricos.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      } else if (_documentType == 'CE' && (!RegExp(r'^[a-zA-Z0-9]{9}$').hasMatch(newDoc))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El Carné de Extranjería (CE) debe tener exactamente 9 caracteres.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      } else if (_documentType == 'Pasaporte' && (newDoc.length < 6 || newDoc.length > 12)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El Pasaporte debe tener entre 6 y 12 caracteres.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    setState(() => _isSavingInstitutionalInfo = true);

    try {
      final updatedUser = user.copyWith(
        position: newOffice.isEmpty ? null : newOffice,
        department: newArea.isEmpty ? null : newArea,
        documentNumber: newDoc.isEmpty ? null : newDoc,
        phoneNumber: newPhone.isEmpty ? null : newPhone,
      );

      // 1. Guardar y refrescar de inmediato en el almacenamiento y sesión local
      await StorageService.updateCurrentUser(updatedUser);

      // 2. Sincronizar en backend y base de datos
      try {
        final profileData = <String, dynamic>{
          'position': newOffice,
          'department': newArea,
          'document_number': newDoc.isEmpty ? null : newDoc,
          'phone_number': newPhone.isEmpty ? null : newPhone,
        };
        final updatedFromApi = await UsersService.updateProfile(profileData);
        await StorageService.updateCurrentUser(updatedFromApi);
      } catch (err) {
        debugPrint('Error sincronizando perfil con backend: $err');
        final errStr = err.toString();
        if (errStr.contains('ya está registrado') || errStr.contains('documento')) {
          if (!mounted) return;
          setState(() => _isSavingInstitutionalInfo = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('El número de documento ya está registrado por otro usuario.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _isEditingInstitutionalInfo = false;
        _isSavingInstitutionalInfo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Información actualizada'),
            ],
          ),
          backgroundColor: ThemeService.primaryColor(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingInstitutionalInfo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openPhotoViewer(UserModel user) {
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      PhotoViewerDialog.show(
        context,
        photoUrl: user.photoUrl!,
        userName: user.fullName,
        subtitle: user.role.displayName,
      );
    } else {
      _showPhotoOptions();
    }
  }

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
              Text('Foto actualizada'),
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



  // --- DIÁLOGO PARA CAMBIAR CONTRASEÑA CON CÓDIGO AL CORREO (MISMO FLUJO QUE OLVIDASTE CONTRASEÑA) ---
  Future<void> _showChangePasswordDialog(UserModel user) async {
    final codeController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    int step = 1; // 1: Solicitar código al correo, 2: Ingresar código y nueva contraseña
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
                    color: (step == 1 ? primaryColor : Colors.green).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    step == 1 ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
                    color: step == 1 ? primaryColor : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step == 1 ? 'Cambiar Contraseña' : 'Verificar y Cambiar',
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
                      'Por seguridad de tu cuenta, te enviaremos un código de verificación de recuperación a tu correo institucional registrado:',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tarjeta de Correo Destino (Solo lectura)
                    const Text('Correo de confirmación:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined, size: 20, color: primaryColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.verified_user_rounded, size: 18, color: Colors.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.vpn_key_outlined, size: 16),
                        label: const Text('¿Ya recibiste un código? Ingresar aquí', style: TextStyle(fontSize: 12)),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setModalState(() {
                                  step = 2;
                                  errorMessage = null;
                                });
                              },
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Ingresa el código de seguridad enviado a:\n${user.email}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Código de Seguridad
                    const Text('Código de Verificación *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Ingresa el código recibido en tu correo',
                        prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 15),
                        label: const Text('Reenviar código al correo', style: TextStyle(fontSize: 11.5)),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  final msg = await AuthService.forgotPassword(user.email);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg), backgroundColor: Colors.green),
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
                    const SizedBox(height: 10),

                    // Nueva Contraseña
                    const Text('Nueva Contraseña Fuerte *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newPwController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        hintText: 'Mínimo 8 caract. con símbolos o guiones (- _)',
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
                  ],

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
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (step == 2) {
                          setModalState(() {
                            step = 1;
                            errorMessage = null;
                          });
                        } else {
                          Navigator.of(ctx).pop();
                        }
                      },
                child: Text(step == 2 ? 'Atrás' : 'Cancelar'),
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
                        if (step == 1) {
                          // PASO 1: Enviar código al correo usando el endpoint que funciona al 100%
                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final msg = await AuthService.forgotPassword(user.email);
                            setModalState(() {
                              step = 2;
                              isSubmitting = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(msg)),
                                    ],
                                  ),
                                  backgroundColor: ThemeService.primaryColor(context),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              errorMessage = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        } else {
                          // PASO 2: Confirmar código y aplicar nueva contraseña usando resetPassword
                          final code = codeController.text.trim();
                          final newPw = newPwController.text.trim();
                          final confirmPw = confirmPwController.text.trim();

                          if (code.isEmpty) {
                            setModalState(() => errorMessage = 'Ingresa el código que te enviamos al correo.');
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
                            setModalState(() => errorMessage = 'Debe incluir al menos un símbolo especial (!@#\$%- o _).');
                            return;
                          }
                          if (newPw != confirmPw) {
                            setModalState(() => errorMessage = 'Las nuevas contraseñas no coinciden.');
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final msg = await AuthService.resetPassword(
                              email: user.email.trim().toLowerCase(),
                              code: code,
                              newPassword: newPw,
                            );

                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              await StorageService.clearSession();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text('$msg Inicia sesión con tu nueva contraseña.')),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              errorMessage = e.toString().replaceAll('Exception: ', '');
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
                    : Text(step == 1 ? 'Enviar Código al Correo' : 'Actualizar Contraseña'),
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
                        hintText: 'Ingresa tu nuevo correo electrónico',
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
                          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(newEmail)) {
                            setModalState(() => currentError = 'Ingresa un correo electrónico válido.');
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
                            final res = await AuthService.requestEmailChange(newEmail);
                            if (res['direct_success'] == true) {
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('¡Correo actualizado con éxito a $newEmail!'),
                                    backgroundColor: ThemeService.primaryColor(context),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              setModalState(() {
                                step = 2;
                                isSubmitting = false;
                              });
                            }
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
    bool obscurePassword = true;
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
                    '¿Estás seguro de que deseas eliminar tu cuenta de ${user.fullName}?\n\nEsta acción borrará tu acceso y liberará tu correo y DNI para que puedas registrarte nuevamente cuando lo desees.',
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
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Tu contraseña actual',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                      ),
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
                          final msg = await AuthService.deleteMyAccount(pw);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text('$msg Puedes registrarte nuevamente cuando lo desees.')),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
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
                const SizedBox(height: 18),

                // Avatar con Botón de Cámara (Cámara / Galería)
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _openPhotoViewer(user),
                        child: Hero(
                          tag: user.photoUrl != null && user.photoUrl!.isNotEmpty
                              ? 'profile_photo_${user.photoUrl}'
                              : 'profile_avatar_placeholder',
                          child: CircleAvatar(
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
                        ),
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

                // Tarjeta de Información Institucional (Oficina, Área, DNI, Teléfono)
                _buildInstitutionalInfoCard(context, user),

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

  Widget _buildInstitutionalInfoCard(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = ThemeService.primaryColor(context);

    final docType = _detectDocumentType(user.documentNumber);
    final docLabel = _getDocumentLabel(user.documentNumber);

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
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState: _isEditingInstitutionalInfo ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Información Institucional',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _startEditingInstitutionalInfo(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 13, color: primary),
                        const SizedBox(width: 4),
                        Text(
                          'Editar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fila Oficina (Sin desbordamiento / overflow protegido)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _startEditingInstitutionalInfo(user),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.apartment_rounded, size: 20, color: primary),
                    const SizedBox(width: 12),
                    Text(
                      'Oficina',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.office.isNotEmpty ? user.office : 'Sin asignar',
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: user.office.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          fontStyle: user.office.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                          color: user.office.isNotEmpty
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Fila Área (Sin desbordamiento / overflow protegido)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _startEditingInstitutionalInfo(user),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.grid_view_rounded, size: 20, color: primary),
                    const SizedBox(width: 12),
                    Text(
                      'Área',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.area.isNotEmpty ? user.area : 'Sin asignar',
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: user.area.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          fontStyle: user.area.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                          color: user.area.isNotEmpty
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Fila Documento dinámica (DNI / CE / Pasaporte según corresponda)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _startEditingInstitutionalInfo(user),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      docType == 'CE'
                          ? Icons.credit_card_outlined
                          : (docType == 'Pasaporte'
                              ? Icons.menu_book_outlined
                              : Icons.badge_outlined),
                      size: 20,
                      color: primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      docLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.documentNumber?.isNotEmpty == true ? user.documentNumber! : 'No registrado',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: user.documentNumber?.isNotEmpty == true ? FontWeight.w600 : FontWeight.normal,
                          fontStyle: user.documentNumber?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                          color: user.documentNumber?.isNotEmpty == true
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Fila Teléfono
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _startEditingInstitutionalInfo(user),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_outlined, size: 20, color: primary),
                    const SizedBox(width: 12),
                    Text(
                      'Teléfono',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.phoneNumber?.isNotEmpty == true ? user.phoneNumber! : 'No registrado',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: user.phoneNumber?.isNotEmpty == true ? FontWeight.w600 : FontWeight.normal,
                          fontStyle: user.phoneNumber?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                          color: user.phoneNumber?.isNotEmpty == true
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        secondChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Editar Información',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _isEditingInstitutionalInfo = false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Actualiza tus datos laborales y de identificación:',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),

            // Campo Oficina
            TextField(
              controller: _officeController,
              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Oficina',
                hintText: 'Ej. Presidencia, Sede Central, Logística...',
                prefixIcon: Icon(Icons.apartment_rounded, size: 20, color: primary),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Campo Área
            TextField(
              controller: _areaController,
              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Área',
                hintText: 'Ej. Tecnologías de la Información, Recursos Humanos...',
                prefixIcon: Icon(Icons.grid_view_rounded, size: 20, color: primary),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Selector Tipo de Documento
            Text(
              'Tipo de Documento',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDocTypeChip('DNI', Icons.badge_outlined, primary, isDark),
                const SizedBox(width: 8),
                _buildDocTypeChip('CE', Icons.credit_card_outlined, primary, isDark),
                const SizedBox(width: 8),
                _buildDocTypeChip('Pasaporte', Icons.menu_book_outlined, primary, isDark),
              ],
            ),
            const SizedBox(height: 12),

            // Campo Número de Documento
            TextField(
              controller: _documentController,
              keyboardType: _documentType == 'DNI' ? TextInputType.number : TextInputType.text,
              maxLength: _documentType == 'DNI' ? 8 : (_documentType == 'CE' ? 9 : 12),
              inputFormatters: [
                if (_documentType == 'DNI') FilteringTextInputFormatter.digitsOnly,
                if (_documentType != 'DNI') FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Nº de $_documentType',
                hintText: _documentType == 'DNI'
                    ? '8 dígitos numéricos'
                    : (_documentType == 'CE' ? '9 caracteres alfanuméricos' : '6 a 12 caracteres'),
                prefixIcon: Icon(
                  _documentType == 'CE'
                      ? Icons.credit_card_outlined
                      : (_documentType == 'Pasaporte' ? Icons.menu_book_outlined : Icons.badge_outlined),
                  size: 20,
                  color: primary,
                ),
                counterText: '',
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Campo Teléfono
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              ],
              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Teléfono',
                hintText: 'Ej. 900972970',
                prefixIcon: Icon(Icons.phone_outlined, size: 20, color: primary),
                counterText: '',
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Botones Cancelar / Guardar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => setState(() => _isEditingInstitutionalInfo = false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSavingInstitutionalInfo ? null : () => _saveInstitutionalInfo(user),
                    icon: _isSavingInstitutionalInfo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSavingInstitutionalInfo ? 'Guardando...' : 'Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocTypeChip(String type, IconData icon, Color primary, bool isDark) {
    final isSelected = _documentType == type;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_documentType != type) {
            setState(() {
              _documentType = type;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? primary
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? primary : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

