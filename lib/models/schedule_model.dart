enum ScheduleType {
  institucional,
  personalizado;

  String get displayName {
    switch (this) {
      case ScheduleType.institucional:
        return 'Horario Institucional (08:00 - 17:00)';
      case ScheduleType.personalizado:
        return 'Horario Personalizado';
    }
  }

  String get categoryName {
    switch (this) {
      case ScheduleType.institucional:
        return 'Institucional';
      case ScheduleType.personalizado:
        return 'Personalizado';
    }
  }

  String get shiftName {
    switch (this) {
      case ScheduleType.institucional:
        return 'Regular';
      case ScheduleType.personalizado:
        return 'Especial';
    }
  }
}

class ScheduleEvaluation {
  final String shiftLabel;
  final bool isPunctual;
  final int minutesLate;
  final String shiftType;

  const ScheduleEvaluation({
    required this.shiftLabel,
    required this.isPunctual,
    this.minutesLate = 0,
    required this.shiftType,
  });
}

class ScheduleModel {
  final String userId;
  final ScheduleType type;
  final int checkInHour; // 0-23 (por defecto 8 AM)
  final int checkInMinute; // 0-59 (por defecto 0)
  final int checkOutHour; // 0-23 (por defecto 17 / 5 PM)
  final int checkOutMinute; // 0-59 (por defecto 0)
  final int toleranceMinutes; // Por defecto 30 min (hasta las 08:30 AM)
  final String? customNotes;
  final DateTime? updatedAt;
  final String? updatedByName;

  const ScheduleModel({
    required this.userId,
    this.type = ScheduleType.institucional,
    this.checkInHour = 8,
    this.checkInMinute = 0,
    this.checkOutHour = 17,
    this.checkOutMinute = 0,
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

  /// Horario institucional estándar único
  factory ScheduleModel.defaultGeneral(String userId) {
    return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.institucional);
  }

  String _formatTime(int hour, int minute) {
    final hStr = hour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  String get checkInTimeFormatted => _formatTime(checkInHour, checkInMinute);
  String get checkOutTimeFormatted => _formatTime(checkOutHour, checkOutMinute);

  String get timeRangeFormatted => '$checkInTimeFormatted - $checkOutTimeFormatted';

  /// Etiqueta completa ej: "Horario Institucional (08:00 - 17:00)"
  String get fullLabel {
    if (type == ScheduleType.personalizado) {
      return 'Horario Personalizado ($timeRangeFormatted)';
    }
    return 'Horario Institucional ($timeRangeFormatted)';
  }

  /// Etiqueta corta ej: "08:00 - 17:00 • Institucional"
  String get shortLabel {
    return '$timeRangeFormatted • ${type.categoryName}';
  }

  /// Evalúa la puntualidad de la marca de asistencia
  /// - Hora oficial: 08:00 AM
  /// - Tolerancia: 30 minutos (hasta las 08:30 AM)
  /// - Antes de las 08:00 o entre 08:00 y 08:30 -> A tiempo
  /// - Después de las 08:30 (ej. 08:31 hasta 13:00 o posterior) -> Tarde
  /// - Salida -> Salida
  ScheduleEvaluation evaluateAttendance(DateTime timestamp, bool isCheckIn) {
    if (!isCheckIn) {
      return ScheduleEvaluation(
        shiftLabel: fullLabel,
        isPunctual: true,
        minutesLate: 0,
        shiftType: type.name,
      );
    }

    final local = timestamp.toLocal();
    final actualMinutes = local.hour * 60 + local.minute;
    final entryLimitMinutes = checkInHour * 60 + checkInMinute + toleranceMinutes;

    final punctual = actualMinutes <= entryLimitMinutes;

    return ScheduleEvaluation(
      shiftLabel: fullLabel,
      isPunctual: punctual,
      minutesLate: 0, // Sin contador de minutos
      shiftType: type.name,
    );
  }

  /// Evalúa si una marca de entrada fue a tiempo considerando la tolerancia de 30 min (hasta 08:30)
  bool isPunctual(DateTime checkInDateTime) {
    final local = checkInDateTime.toLocal();
    final entryLimitMinutes = checkInHour * 60 + checkInMinute + toleranceMinutes;
    final actualMinutes = local.hour * 60 + local.minute;
    return actualMinutes <= entryLimitMinutes;
  }

  /// Ya no se manejan minutos de tardanza
  int minutesLate(DateTime checkInDateTime) => 0;

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
      final t = json['type']?.toString().toLowerCase();
      if (t == 'personalizado') {
        parsedType = ScheduleType.personalizado;
      } else {
        parsedType = ScheduleType.institucional;
      }
    } catch (_) {
      parsedType = ScheduleType.institucional;
    }

    return ScheduleModel(
      userId: json['user_id']?.toString() ?? '',
      type: parsedType,
      checkInHour: (json['check_in_hour'] as num?)?.toInt() ?? 8,
      checkInMinute: (json['check_in_minute'] as num?)?.toInt() ?? 0,
      checkOutHour: (json['check_out_hour'] as num?)?.toInt() ?? 17,
      checkOutMinute: (json['check_out_minute'] as num?)?.toInt() ?? 0,
      toleranceMinutes: (json['tolerance_minutes'] as num?)?.toInt() ?? 30,
      customNotes: json['custom_notes']?.toString(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedByName: json['updated_by_name']?.toString(),
    );
  }

  /// Cadena compacta legible para sincronizar con el backend
  String toCompactPositionString() {
    return 'Horario Institucional (08:00 - 17:00)';
  }

  /// Reconstruye el horario institucional
  static ScheduleModel? tryParseFromPosition(String userId, String? position) {
    return ScheduleModel.defaultGeneral(userId);
  }
}
