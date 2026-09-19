import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/users_service.dart';
import '../../services/theme_service.dart';
import '../../services/api_client.dart';
import '../../widgets/opera_gx_theme_picker.dart';
import '../login_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
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
          content: const Text('Foto de perfil actualizada correctamente.'),
          backgroundColor: ThemeService.primaryColor(context),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFEF4444)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
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
          appBar: AppBar(
            title: const Text(
              'Mi Perfil Institucional',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                // Avatar e información principal
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
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
                          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
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

                const SizedBox(height: 14),

                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // Rol Badge con color dinámico del tema
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
          const SizedBox(height: 14),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(it.icon, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Text(
                      it.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        it.value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
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

  _InfoRow({required this.icon, required this.label, required this.value});
}
