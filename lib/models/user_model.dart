// ignore_for_file: constant_identifier_names

enum UserRole {
  ADMIN,
  SUPERVISOR,
  USER;

  static UserRole fromString(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        return UserRole.ADMIN;
      case 'SUPERVISOR':
        return UserRole.SUPERVISOR;
      case 'USER':
      case 'EMPLOYEE':
      default:
        return UserRole.USER;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.ADMIN:
        return 'Admin';
      case UserRole.SUPERVISOR:
        return 'Supervisor';
      case UserRole.USER:
        return 'User';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? position;
  final String? department;
  final String? documentNumber;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isVerified;
  final bool isActive;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.position,
    this.department,
    this.documentNumber,
    this.phoneNumber,
    this.photoUrl,
    this.isVerified = true,
    this.isActive = true,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.ADMIN;
  bool get isSupervisor => role == UserRole.SUPERVISOR;
  bool get canManageAttendanceQr => isAdmin || isSupervisor;

  /// Oficina asignada al usuario (vacía por defecto si no ha sido configurada)
  String get office {
    if (position == null ||
        position!.trim().isEmpty ||
        position == 'Personal de la Institución' ||
        position == 'Sin cargo asignado') {
      return '';
    }
    return position!.trim();
  }

  /// Área asignada al usuario (vacía por defecto si no ha sido configurada)
  String get area {
    if (department == null ||
        department!.trim().isEmpty ||
        department == 'Área General' ||
        department == 'IIAP Central') {
      return '';
    }
    return department!.trim();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawPos = json['position']?.toString();
    final rawDept = json['department']?.toString();
    // Por defecto vienen vacíos, omitiendo textos genéricos previos del backend
    final cleanPos = (rawPos == 'Personal de la Institución' || rawPos == 'Sin cargo asignado') ? null : rawPos;
    final cleanDept = (rawDept == 'Área General' || rawDept == 'IIAP Central') ? null : rawDept;

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: UserRole.fromString(json['role']?.toString()),
      position: cleanPos,
      department: cleanDept,
      documentNumber: json['document_number']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      isVerified: json['is_verified'] == true,
      isActive: json['is_active'] != false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'position': position,
      'department': department,
      'document_number': documentNumber,
      'phone_number': phoneNumber,
      'photo_url': photoUrl,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? position,
    String? department,
    String? documentNumber,
    String? phoneNumber,
    String? photoUrl,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      position: position ?? this.position,
      department: department ?? this.department,
      documentNumber: documentNumber ?? this.documentNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
