import 'package:flutter_test/flutter_test.dart';
import 'package:control_asistencia/models/schedule_model.dart';
import 'package:control_asistencia/models/user_model.dart';
import 'package:control_asistencia/models/attendance_model.dart';

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

  group('Pruebas de Turnos y Jornadas (ShiftJourneyRecord)', () {
    test('1. Usuario olvida marcar salida el 23/09 y marca entrada el 24/09 (Días independientes)', () {
      final aDay1In = AttendanceModel(
        id: '1',
        userId: 'u1',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 23, 8, 5),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-23',
      );

      final aDay2In = AttendanceModel(
        id: '2',
        userId: 'u1',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 24, 8, 5),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-24',
      );

      final journeys = ShiftJourneyRecord.groupFromRecords([aDay1In, aDay2In]);

      expect(journeys.length, 2);
      expect(journeys[0].workDate, '2026-09-24');
      expect(journeys[0].checkIn != null, true);
      expect(journeys[0].checkOut, isNull);
      expect(journeys[0].isPendingCheckOut, true); // No tiene salida

      expect(journeys[1].workDate, '2026-09-23');
      expect(journeys[1].checkIn != null, true);
      expect(journeys[1].checkOut, isNull);
      expect(journeys[1].isPendingCheckOut, true);
    });

    test('2. Salida después de la hora programada (ej. 13:20 después de las 13:00) se asocia como SALIDA', () {
      final aIn = AttendanceModel(
        id: '1',
        userId: 'u1',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 24, 8, 5),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-24',
      );

      final aOut = AttendanceModel(
        id: '2',
        userId: 'u1',
        type: AttendanceType.CHECK_OUT,
        timestamp: DateTime(2026, 9, 24, 13, 20),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-24',
      );

      final journeys = ShiftJourneyRecord.groupFromRecords([aIn, aOut]);

      expect(journeys.length, 1);
      expect(journeys.first.checkIn != null, true);
      expect(journeys.first.checkOut != null, true);
      expect(journeys.first.checkOut!.timestamp.hour, 13);
      expect(journeys.first.checkOut!.timestamp.minute, 20);
      expect(journeys.first.isCompleted, true);
    });

    test('3. Supervisor con jornada extendida (Entrada 08:05, Salida 19:00)', () {
      final aIn = AttendanceModel(
        id: '1',
        userId: 'sup1',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 24, 8, 5),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-24',
      );

      final aOut = AttendanceModel(
        id: '2',
        userId: 'sup1',
        type: AttendanceType.CHECK_OUT,
        timestamp: DateTime(2026, 9, 24, 19, 0),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-24',
      );

      final journeys = ShiftJourneyRecord.groupFromRecords([aIn, aOut]);

      expect(journeys.length, 1);
      expect(journeys.first.checkIn != null, true);
      expect(journeys.first.checkOut != null, true);
      expect(journeys.first.checkOut!.timestamp.hour, 19);
      expect(journeys.first.isCompleted, true);
    });

    test('4. Usuario A (mañana) y Usuario B (tarde) son completamente independientes', () {
      final userAIn = AttendanceModel(
        id: '1',
        userId: 'user_A',
        userName: 'Usuario A',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 24, 8, 5),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.MORNING,
        workDate: '2026-09-24',
      );

      final userBIn = AttendanceModel(
        id: '2',
        userId: 'user_B',
        userName: 'Usuario B',
        type: AttendanceType.CHECK_IN,
        timestamp: DateTime(2026, 9, 24, 13, 40),
        status: AttendanceStatus.ON_TIME,
        shift: AttendanceShift.AFTERNOON,
        workDate: '2026-09-24',
      );

      final journeys = ShiftJourneyRecord.groupFromRecords([userAIn, userBIn]);

      expect(journeys.length, 2);
      final journeyA = journeys.firstWhere((j) => j.userId == 'user_A');
      final journeyB = journeys.firstWhere((j) => j.userId == 'user_B');

      expect(journeyA.shift, AttendanceShift.MORNING);
      expect(journeyA.checkOut, isNull);

      expect(journeyB.shift, AttendanceShift.AFTERNOON);
      expect(journeyB.checkIn != null, true);
      expect(journeyB.checkOut, isNull);
    });
  });
}
