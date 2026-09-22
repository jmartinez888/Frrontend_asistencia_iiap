enum ScheduleType {
  flexible,
  voluntarioManana,
  voluntarioTarde,
  practicanteManana,
  practicanteTarde,
  contratado,
  permanente,
  personalizado;

  String get displayName {
    switch (this) {
      case ScheduleType.flexible:
        return 'Turno Dinámico (Mañana / Tarde según asistencia)';
      case ScheduleType.voluntarioManana:
        return 'Voluntario - Mañana (08:00 - 13:00)';
      case ScheduleType.voluntarioTarde:
        return 'Voluntario - Tarde (14:00 - 19:00)';
      case ScheduleType.practicanteManana:
        return 'Practicante - Mañana (08:00 - 13:00)';
      case ScheduleType.practicanteTarde:
        return 'Practicante - Tarde (14:00 - 19:00)';
      case ScheduleType.contratado:
        return 'Contratado (08:00 - 17:00)';
      case ScheduleType.permanente:
        return 'Permanente / CAS (08:00 - 17:00)';
      case ScheduleType.personalizado:
        return 'Horario Personalizado';
    }
  }

  String get categoryName {
    switch (this) {
      case ScheduleType.flexible:
        return 'Personal';
      case ScheduleType.voluntarioManana:
      case ScheduleType.voluntarioTarde:
        return 'Voluntario';
      case ScheduleType.practicanteManana:
      case ScheduleType.practicanteTarde:
        return 'Practicante';
      case ScheduleType.contratado:
        return 'Contratado';
      case ScheduleType.permanente:
        return 'Permanente';
      case ScheduleType.personalizado:
        return 'Personalizado';
    }
  }

  String get shiftName {
    switch (this) {
      case ScheduleType.flexible:
        return 'Dinámico';
      case ScheduleType.voluntarioManana:
      case ScheduleType.practicanteManana:
        return 'Mañana';
      case ScheduleType.voluntarioTarde:
      case ScheduleType.practicanteTarde:
        return 'Tarde';
      case ScheduleType.contratado:
      case ScheduleType.permanente:
        return 'Completo';
      case ScheduleType.personalizado:
        return 'Especial';
    }
  }
}

class ScheduleEvaluation {
  final String shiftLabel;
  final bool isPunctual;
  final int minutesLate;
  final String shiftType; // 'morning', 'afternoon', 'custom'

  const ScheduleEvaluation({
    required this.shiftLabel,
    required this.isPunctual,
    required this.minutesLate,
    required this.shiftType,
  });
}

class ScheduleModel {
  final String userId;
  final ScheduleType type;
  final int checkInHour; // 0-23
  final int checkInMinute; // 0-59
  final int checkOutHour; // 0-23
  final int checkOutMinute; // 0-59
  final int toleranceMinutes; // Por defecto 30 min (mañana y tarde)
  final String? customNotes;
  final DateTime? updatedAt;
  final String? updatedByName;

  const ScheduleModel({
    required this.userId,
    required this.type,
    required this.checkInHour,
    required this.checkInMinute,
    required this.checkOutHour,
    required this.checkOutMinute,
    this.toleranceMinutes = 30,
    this.customNotes,
    this.updatedAt,
    this.updatedByName,
  });

  /// Crea un horario predeterminado según el tipo
  factory ScheduleModel.defaultForType({
    required String userId,
    required ScheduleType type,
    String? updatedByName,
  }) {
    switch (type) {
      case ScheduleType.flexible:
        return ScheduleModel(
          userId: userId,
          type: type,
          checkInHour: 8,
          checkInMinute: 0,
          checkOutHour: 13,
          checkOutMinute: 0,
          toleranceMinutes: 30,
          updatedAt: DateTime.now(),
          updatedByName: updatedByName,
        );
      case ScheduleType.contratado:
      case ScheduleType.permanente:
        return ScheduleModel(
          userId: userId,
          type: type,
          checkInHour: 8,
          checkInMinute: 0,
          checkOutHour: 17,
          checkOutMinute: 0,
          toleranceMinutes: 30,
          updatedAt: DateTime.now(),
          updatedByName: updatedByName,
        );
      case ScheduleType.voluntarioManana:
      case ScheduleType.practicanteManana:
        return ScheduleModel(
          userId: userId,
          type: type,
          checkInHour: 8,
          checkInMinute: 0,
          checkOutHour: 13,
          checkOutMinute: 0,
          toleranceMinutes: 30,
          updatedAt: DateTime.now(),
          updatedByName: updatedByName,
        );
      case ScheduleType.voluntarioTarde:
      case ScheduleType.practicanteTarde:
        return ScheduleModel(
          userId: userId,
          type: type,
          checkInHour: 14,
          checkInMinute: 0,
          checkOutHour: 19,
          checkOutMinute: 0,
          toleranceMinutes: 30,
          updatedAt: DateTime.now(),
          updatedByName: updatedByName,
        );
      case ScheduleType.personalizado:
        return ScheduleModel(
          userId: userId,
          type: type,
          checkInHour: 8,
          checkInMinute: 0,
          checkOutHour: 17,
          checkOutMinute: 0,
          toleranceMinutes: 30,
          updatedAt: DateTime.now(),
          updatedByName: updatedByName,
        );
    }
  }

  /// Horario por defecto estándar si no tiene ninguno asignado (flexible según asistencia)
  factory ScheduleModel.defaultGeneral(String userId) {
    return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.flexible);
  }

  String _formatTime(int hour, int minute) {
    final hStr = hour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  String get checkInTimeFormatted => _formatTime(checkInHour, checkInMinute);
  String get checkOutTimeFormatted => _formatTime(checkOutHour, checkOutMinute);

  String get timeRangeFormatted => '$checkInTimeFormatted - $checkOutTimeFormatted';

  /// Etiqueta completa ej: "Voluntario (Mañana: 08:00 - 13:00)"
  String get fullLabel {
    if (type == ScheduleType.flexible) {
      return 'Turno Dinámico (Mañana / Tarde)';
    }
    if (type == ScheduleType.personalizado) {
      return 'Personalizado ($timeRangeFormatted)';
    }
    return '${type.categoryName} (${type.shiftName}: $timeRangeFormatted)';
  }

  /// Etiqueta corta ej: "08:00 - 13:00 • Voluntario"
  String get shortLabel {
    if (type == ScheduleType.flexible) {
      return 'Dinámico • Personal';
    }
    return '$timeRangeFormatted • ${type.categoryName}';
  }

  /// Evalúa el turno y puntualidad de una marca específica (dinámicamente para horarios flexibles)
  ScheduleEvaluation evaluateAttendance(DateTime timestamp, bool isCheckIn) {
    if (type == ScheduleType.flexible) {
      final local = timestamp.toLocal();
      final isMorning = local.hour < 12;

      if (isMorning) {
        const targetHour = 8;
        const targetMinute = 0;
        final actualMinutes = local.hour * 60 + local.minute;
        const targetMinutes = targetHour * 60 + targetMinute;
        final lateDiff = actualMinutes - (targetMinutes + toleranceMinutes);
        final punctual = !isCheckIn || (lateDiff <= 0);
        final late = (isCheckIn && lateDiff > 0) ? (actualMinutes - targetMinutes) : 0;
        return ScheduleEvaluation(
          shiftLabel: 'Turno Mañana (08:00 - 13:00)',
          isPunctual: punctual,
          minutesLate: late,
          shiftType: 'morning',
        );
      } else {
        const targetHour = 14;
        const targetMinute = 0;
        final actualMinutes = local.hour * 60 + local.minute;
        const targetMinutes = targetHour * 60 + targetMinute;
        final lateDiff = actualMinutes - (targetMinutes + toleranceMinutes);
        final punctual = !isCheckIn || (lateDiff <= 0);
        final late = (isCheckIn && lateDiff > 0) ? (actualMinutes - targetMinutes) : 0;
        return ScheduleEvaluation(
          shiftLabel: 'Turno Tarde (14:00 - 19:00)',
          isPunctual: punctual,
          minutesLate: late,
          shiftType: 'afternoon',
        );
      }
    }

    final punctual = isCheckIn ? isPunctual(timestamp) : true;
    final late = isCheckIn ? minutesLate(timestamp) : 0;
    return ScheduleEvaluation(
      shiftLabel: fullLabel,
      isPunctual: punctual,
      minutesLate: late,
      shiftType: type.name,
    );
  }

  /// Evalúa si una marca de entrada fue a tiempo considerando la tolerancia
    bool isPunctual(DateTime checkInDateTime) {
    final local = checkInDateTime.toLocal();
    final entryMinutes = checkInHour * 60 + checkInMinute;
    final actualMinutes = local.hour * 60 + local.minute;
    return actualMinutes <= (entryMinutes + toleranceMinutes);
  }

  /// Calcula cuántos minutos de tardanza hubo (0 si fue a tiempo)
  int minutesLate(DateTime checkInDateTime) {
    final local = checkInDateTime.toLocal();
    final entryMinutes = checkInHour * 60 + checkInMinute;
    final actualMinutes = local.hour * 60 + local.minute;
    final diff = actualMinutes - (entryMinutes + toleranceMinutes);
    return diff > 0 ? diff : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type.name,
      'check_in_hour': checkInHour,
      'check_in_minute': checkInMinute,
      'check_out_hour': checkOutHour,
      'check_out_minute': checkOutMinute,
      'tolerance_minutes': toleranceMinutes,
      'custom_notes': customNotes,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by_name': updatedByName,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    ScheduleType parsedType;
    try {
      parsedType = ScheduleType.values.byName(json['type']?.toString() ?? 'contratado');
    } catch (_) {
      parsedType = ScheduleType.contratado;
    }

    return ScheduleModel(
      userId: json['user_id']?.toString() ?? '',
      type: parsedType,
      checkInHour: (json['check_in_hour'] as num?)?.toInt() ?? 8,
      checkInMinute: (json['check_in_minute'] as num?)?.toInt() ?? 0,
      checkOutHour: (json['check_out_hour'] as num?)?.toInt() ?? 17,
      checkOutMinute: (json['check_out_minute'] as num?)?.toInt() ?? 0,
      toleranceMinutes: (json['tolerance_minutes'] as num?)?.toInt() ?? 10,
      customNotes: json['custom_notes']?.toString(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedByName: json['updated_by_name']?.toString(),
    );
  }

  /// Cadena compacta legible para sincronizar con el campo position en el backend
  String toCompactPositionString() {
    return '${type.categoryName} (${type.shiftName}: $timeRangeFormatted)';
  }

  /// Reconstruye desde la cadena guardada en el usuario si existe
  static ScheduleModel? tryParseFromPosition(String userId, String? position) {
    if (position == null || position.trim().isEmpty) return null;

    final lower = position.toLowerCase();
    if (lower.contains('voluntario') && lower.contains('tarde')) {
      return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.voluntarioTarde);
    }
    if (lower.contains('voluntario')) {
      return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.voluntarioManana);
    }
    if (lower.contains('practicante') && lower.contains('tarde')) {
      return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.practicanteTarde);
    }
    if (lower.contains('practicante')) {
      return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.practicanteManana);
    }
    if (lower.contains('permanente') || lower.contains('cas')) {
      return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.permanente);
    }
    if (lower.contains('contratado')) {
      return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.contratado);
    }
    return null;
  }
}
