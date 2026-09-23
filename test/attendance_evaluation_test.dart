import 'package:flutter_test/flutter_test.dart';
import 'package:control_asistencia/models/schedule_model.dart';
import 'package:control_asistencia/models/user_model.dart';

void main() {
  group('Pruebas de Roles de Usuario', () {
    test('Roles disponibles son únicamente Admin, Supervisor y User', () {
      expect(UserRole.ADMIN.displayName, 'Admin');
      expect(UserRole.SUPERVISOR.displayName, 'Supervisor');
      expect(UserRole.USER.displayName, 'User');
    });

    test('Compatibilidad con EMPLOYEE mapea a User', () {
      expect(UserRole.fromString('EMPLOYEE'), UserRole.USER);
      expect(UserRole.fromString('USER'), UserRole.USER);
      expect(UserRole.fromString('ADMIN'), UserRole.ADMIN);
      expect(UserRole.fromString('SUPERVISOR'), UserRole.SUPERVISOR);
      expect(UserRole.fromString(null), UserRole.USER);
    });
  });

  group('Pruebas de Evaluación de Asistencias (Entrada 08:00 AM, Tolerancia hasta 08:30 AM)', () {
    final schedule = ScheduleModel.defaultGeneral('test-user-id');

    test('1. Marcación de entrada antes de las 8:00 AM (07:45 AM) debe ser A tiempo', () {
      final time = DateTime(2026, 9, 23, 7, 45, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, true);
      expect(schedule.isPunctual(time), true);
    });

    test('2. Marcación de entrada a las 8:00 AM exacta debe ser A tiempo', () {
      final time = DateTime(2026, 9, 23, 8, 0, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, true);
      expect(schedule.isPunctual(time), true);
    });

    test('3. Marcación de entrada dentro de la tolerancia (08:15 AM) debe ser A tiempo', () {
      final time = DateTime(2026, 9, 23, 8, 15, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, true);
      expect(schedule.isPunctual(time), true);
    });

    test('4. Marcación de entrada en el límite de la tolerancia (08:30 AM) debe ser A tiempo', () {
      final time = DateTime(2026, 9, 23, 8, 30, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, true);
      expect(schedule.isPunctual(time), true);
    });

    test('5. Marcación de entrada superando la tolerancia (08:31 AM) debe ser Tarde', () {
      final time = DateTime(2026, 9, 23, 8, 31, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, false);
      expect(schedule.isPunctual(time), false);
    });

    test('6. Marcación de entrada a las 09:00 AM debe ser Tarde', () {
      final time = DateTime(2026, 9, 23, 9, 0, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, false);
      expect(schedule.isPunctual(time), false);
    });

    test('7. Marcación de entrada entre 8:30 y 1:00 PM (12:30 PM) debe ser Tarde', () {
      final time = DateTime(2026, 9, 23, 12, 30, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, false);
      expect(schedule.isPunctual(time), false);
    });

    test('8. Marcación de entrada a la 1:00 PM (13:00) debe ser Tarde', () {
      final time = DateTime(2026, 9, 23, 13, 0, 0);
      final evaluation = schedule.evaluateAttendance(time, true);

      expect(evaluation.isPunctual, false);
      expect(schedule.isPunctual(time), false);
    });

    test('9. Marcación de salida no tiene tardanza', () {
      final time = DateTime(2026, 9, 23, 17, 0, 0);
      final evaluation = schedule.evaluateAttendance(time, false);

      expect(evaluation.isPunctual, true);
    });
  });
}
