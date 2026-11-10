import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/models/maintenance_recommendation.dart';
import 'package:new_my_car_app/services/maintenance_recommendation_service.dart';

import '../../tool/seed/demo_data_generator.dart';

void main() {
  final now = DateTime(2026, 11, 9, 10);
  const userId = 'user-1';

  DemoData build({int seed = 42}) {
    var n = 0;
    return DemoDataGenerator(
      userId: userId,
      now: now,
      newId: () => 'id-${n++}',
      seed: seed,
    ).generate();
  }

  test('genera los vehículos de demo con sus placas', () {
    final data = build();
    expect(data.cars.map((c) => c.plateNumber), DemoDataGenerator.demoPlates);
    expect(data.cars.every((c) => c.userId == userId), isTrue);
  });

  test('es determinista con el mismo seed y cambia con otro', () {
    final a = build().transactions.map((t) => t.toMap()).toList();
    final b = build().transactions.map((t) => t.toMap()).toList();
    final c = build(seed: 7).transactions.map((t) => t.toMap()).toList();
    expect(a, b);
    expect(a, isNot(c));
  });

  test(
    'todos los ids son únicos y los hijos apuntan a un vehículo existente',
    () {
      final data = build();
      final ids = <String?>[
        ...data.cars.map((e) => e.id),
        ...data.mileageReadings.map((e) => e.id),
        ...data.maintenanceLogs.map((e) => e.id),
        ...data.transactions.map((e) => e.id),
        ...data.trips.map((e) => e.id),
        ...data.alerts.map((e) => e.id),
      ];
      expect(ids.toSet().length, ids.length);

      final carIds = data.cars.map((c) => c.id).toSet();
      final childCarIds = <String>[
        ...data.mileageReadings.map((e) => e.carId),
        ...data.maintenanceLogs.map((e) => e.carId),
        ...data.transactions.map((e) => e.carId),
        ...data.trips.map((e) => e.carId),
        ...data.alerts.map((e) => e.carId),
      ];
      expect(childCarIds.every(carIds.contains), isTrue);
      expect(data.transactions.every((t) => t.userId == userId), isTrue);
    },
  );

  test('el odómetro nunca retrocede en el tiempo, por vehículo', () {
    final data = build();
    for (final car in data.cars) {
      final points =
          <(DateTime, double)>[
            for (final r in data.mileageReadings.where(
              (r) => r.carId == car.id,
            ))
              (r.readingDate, r.odometerKm),
            for (final l in data.maintenanceLogs.where(
              (l) => l.carId == car.id,
            ))
              (l.serviceDate, l.odometerKm),
            for (final t in data.transactions.where(
              (t) => t.carId == car.id && t.odometerKm != null,
            ))
              (t.date, t.odometerKm!),
          ]..sort((a, b) {
            final byDate = a.$1.compareTo(b.$1);
            return byDate != 0 ? byDate : a.$2.compareTo(b.$2);
          });
      for (var i = 1; i < points.length; i++) {
        expect(
          points[i].$2,
          greaterThanOrEqualTo(points[i - 1].$2),
          reason: '${car.plateNumber} retrocede en ${points[i].$1}',
        );
      }
    }
  });

  test('no hay movimientos, lecturas ni servicios en el futuro', () {
    final data = build();
    final limit = now.add(const Duration(days: 1));
    expect(data.transactions.every((t) => t.date.isBefore(limit)), isTrue);
    expect(
      data.mileageReadings.every((r) => r.readingDate.isBefore(limit)),
      isTrue,
    );
    expect(
      data.maintenanceLogs.every((l) => l.serviceDate.isBefore(limit)),
      isTrue,
    );
    expect(data.trips.every((t) => t.endedAt.isBefore(limit.toUtc())), isTrue);
  });

  test('combustible con litros, odómetro y monto positivo', () {
    final fuel = build().transactions
        .where((t) => t.category == TransactionCategory.fuel)
        .toList();
    expect(fuel, isNotEmpty);
    for (final t in fuel) {
      expect(t.isExpense, isTrue);
      expect(t.liters, greaterThan(0));
      expect(t.odometerKm, isNotNull);
      expect(t.amount, greaterThan(0));
    }
  });

  test('los viajes son coherentes (duración y odómetro)', () {
    for (final trip in build().trips) {
      expect(trip.distanceKm, greaterThan(0));
      expect(
        trip.endedAt.difference(trip.startedAt).inSeconds,
        trip.durationSeconds,
      );
      expect(trip.endOdometerKm!, greaterThan(trip.startOdometerKm!));
    }
  });

  test('las alertas incluyen una vencida y una completada', () {
    final alerts = build().alerts;
    final today = DateTime(now.year, now.month, now.day);
    expect(
      alerts.any((a) => !a.isCompleted && a.alertDate.isBefore(today)),
      isTrue,
    );
    expect(alerts.any((a) => a.isCompleted && a.completedAt != null), isTrue);
  });

  test('las recomendaciones cubren los estados al día, próximo, vencido e '
      'historial', () {
    final data = build();
    final statusByPlateAndType = <String, MaintenanceStatus>{};

    for (final car in data.cars) {
      final logs = data.maintenanceLogs
          .where((l) => l.carId == car.id)
          .toList();
      final current = data.mileageReadings
          .where((r) => r.carId == car.id)
          .map((r) => r.odometerKm)
          .reduce((a, b) => a > b ? a : b);
      final recommendations =
          MaintenanceRecommendationService.buildRecommendations(
            currentOdometerKm: current,
            maintenanceLogs: logs,
            now: now,
          );
      for (final r in recommendations) {
        statusByPlateAndType['${car.plateNumber}/${r.serviceType}'] = r.status;
      }
    }

    expect(statusByPlateAndType['MZD321/oil_change'], MaintenanceStatus.ok);
    expect(statusByPlateAndType['MZD321/air_filter'], MaintenanceStatus.soon);
    expect(
      statusByPlateAndType['MZD321/brake_check'],
      MaintenanceStatus.needsHistory,
    );
    expect(
      statusByPlateAndType['SPK918/oil_change'],
      MaintenanceStatus.overdue,
    );
  });
}
