import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/alert.dart';

Alert recurring({
  String type = 'yearly',
  int? value,
  DateTime? date,
  String? id = 'alert-1',
}) => Alert(
  id: id,
  userId: 'u1',
  carId: 'c1',
  title: 'Renovación SOAT',
  description: 'Renovar el SOAT',
  alertDate: date ?? DateTime(2026, 11, 10),
  isRecurring: true,
  recurrenceType: type,
  recurrenceValue: value,
  recurrenceCount: 3,
  templateType: 'soat',
  notificationTime: '08:00',
  notifyDaysBefore: 3,
  isCompleted: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 2, 1),
);

void main() {
  group('Alert.nextOccurrence', () {
    test('es una alerta nueva: sin id ni fechas de creación', () {
      final next = recurring().nextOccurrence()!;

      // Con id repetido el insert chocaba con la clave primaria (alerts_pkey).
      expect(next.id, isNull);
      expect(next.createdAt, isNull);
      expect(next.updatedAt, isNull);
      expect(next.completedAt, isNull);
      expect(next.toMap().containsKey('id'), isFalse);
    });

    test('queda pendiente aunque la original estuviera completada', () {
      final done = recurring().copyWith(
        isCompleted: true,
        completedAt: DateTime(2026, 11, 10),
      );

      final next = done.nextOccurrence()!;

      expect(next.isCompleted, isFalse);
      expect(next.completedAt, isNull);
    });

    test('conserva la configuración de la alerta', () {
      final next = recurring(value: 2).nextOccurrence()!;

      expect(next.userId, 'u1');
      expect(next.carId, 'c1');
      expect(next.title, 'Renovación SOAT');
      expect(next.description, 'Renovar el SOAT');
      expect(next.isRecurring, isTrue);
      expect(next.recurrenceType, 'yearly');
      expect(next.recurrenceValue, 2);
      expect(next.recurrenceCount, 3);
      expect(next.templateType, 'soat');
      expect(next.notificationTime, '08:00');
      expect(next.notifyDaysBefore, 3);
    });

    test('calcula la fecha según el tipo de recurrencia', () {
      final base = DateTime(2026, 11, 10);
      expect(
        recurring(type: 'daily', date: base).nextOccurrence()!.alertDate,
        DateTime(2026, 11, 11),
      );
      expect(
        recurring(type: 'weekly', date: base).nextOccurrence()!.alertDate,
        DateTime(2026, 11, 17),
      );
      expect(
        recurring(type: 'monthly', date: base).nextOccurrence()!.alertDate,
        DateTime(2026, 12, 10),
      );
      expect(
        recurring(type: 'yearly', date: base).nextOccurrence()!.alertDate,
        DateTime(2027, 11, 10),
      );
      expect(
        recurring(
          type: 'custom_days',
          value: 45,
          date: base,
        ).nextOccurrence()!.alertDate,
        DateTime(2026, 12, 25),
      );
    });

    test('una alerta que no es recurrente no tiene siguiente', () {
      final single = Alert(
        id: 'a',
        userId: 'u1',
        carId: 'c1',
        title: 'Cambio de llantas',
        alertDate: DateTime(2026, 11, 10),
      );

      expect(single.nextOccurrence(), isNull);
    });

    test('un tipo de recurrencia desconocido no tiene siguiente', () {
      expect(recurring(type: 'cada_luna').nextOccurrence(), isNull);
      expect(recurring(type: 'custom_days').nextOccurrence(), isNull);
    });

    test('no modifica la alerta original', () {
      final original = recurring();

      original.nextOccurrence();

      expect(original.id, 'alert-1');
      expect(original.alertDate, DateTime(2026, 11, 10));
    });
  });

  test('copyWith(id: null) conserva el id (por eso existe nextOccurrence)', () {
    // Documenta la trampa que causó el error: null no limpia el campo.
    expect(recurring().copyWith(id: null).id, 'alert-1');
  });
}
