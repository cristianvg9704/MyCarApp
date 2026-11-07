import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/maintenance_log.dart';
import 'package:new_my_car_app/models/maintenance_recommendation.dart';
import 'package:new_my_car_app/models/mileage_reading.dart';
import 'package:new_my_car_app/services/maintenance_recommendation_service.dart';

MaintenanceLog _log(String type, double km, DateTime date) => MaintenanceLog(
  userId: 'u1',
  carId: 'c1',
  serviceType: type,
  odometerKm: km,
  serviceDate: date,
);

final _now = DateTime(2025, 6, 1);

List<MaintenanceRecommendation> _build({
  required double km,
  required List<MaintenanceLog> logs,
  double? kmPerDay,
}) => MaintenanceRecommendationService.buildRecommendations(
  currentOdometerKm: km,
  maintenanceLogs: logs,
  now: _now,
  kmPerDay: kmPerDay,
);

void main() {
  group('calculateTrackedKm', () {
    test('sums positive deltas between readings', () {
      final readings = [
        MileageReading(
          userId: 'u1',
          carId: 'c1',
          odometerKm: 10000,
          readingDate: DateTime(2025, 1, 1),
        ),
        MileageReading(
          userId: 'u1',
          carId: 'c1',
          odometerKm: 10500,
          readingDate: DateTime(2025, 2, 1),
        ),
        MileageReading(
          userId: 'u1',
          carId: 'c1',
          odometerKm: 11200,
          readingDate: DateTime(2025, 3, 1),
        ),
      ];

      expect(
        MaintenanceRecommendationService.calculateTrackedKm(readings),
        1200,
      );
    });
  });

  group('median', () {
    test('handles odd, even and empty lists', () {
      expect(MaintenanceRecommendationService.median([]), isNull);
      expect(MaintenanceRecommendationService.median([5]), 5);
      expect(MaintenanceRecommendationService.median([9, 1, 5]), 5);
      expect(MaintenanceRecommendationService.median([4, 1, 3, 2]), 2.5);
    });
  });

  group('labelFor', () {
    test('uses known labels and humanizes unknown types', () {
      expect(
        MaintenanceRecommendationService.labelFor('oil_change'),
        'Cambio de aceite',
      );
      expect(
        MaintenanceRecommendationService.labelFor('wiper_blades'),
        'Wiper blades',
      );
    });
  });

  group('buildRecommendations', () {
    test('does not recommend anything without maintenance history', () {
      expect(_build(km: 50000, logs: const []), isEmpty);
    });

    test('does not recommend service types the owner never logged', () {
      final recs = _build(
        km: 12000,
        logs: [_log('oil_change', 10000, DateTime(2025, 5, 1))],
      );
      expect(recs.map((r) => r.serviceType), ['oil_change']);
    });

    test('one record needs more history: no interval is invented', () {
      final rec = _build(
        km: 12000,
        logs: [_log('oil_change', 10000, DateTime(2025, 5, 2))],
      ).single;

      expect(rec.status, MaintenanceStatus.needsHistory);
      expect(rec.hasInterval, isFalse);
      expect(rec.intervalKm, isNull);
      expect(rec.intervalDays, isNull);
      expect(rec.kmRemaining, isNull);
      expect(rec.estimatedDueDate, isNull);
      expect(rec.progress, isNull);
      expect(rec.recordCount, 1);
      expect(rec.lastServiceKm, 10000);
      expect(rec.kmSinceService, 2000);
      expect(rec.daysSinceService, 30);
    });

    test('derives the interval from the owner median of consecutive services',
        () {
      // Intervals: 4000 km/120 d, 6000 km/180 d, 5000 km/150 d -> median 5000/150.
      DateTime day(int n) => DateTime(2024, 1, 1 + n);
      final logs = [
        _log('oil_change', 10000, day(0)),
        _log('oil_change', 14000, day(120)),
        _log('oil_change', 20000, day(300)),
        _log('oil_change', 25000, day(450)),
      ];
      final rec = _build(km: 26000, logs: logs).single;

      expect(rec.recordCount, 4);
      expect(rec.intervalKm, 5000);
      expect(rec.intervalDays, 150);
      expect(rec.kmSinceService, 1000);
      expect(rec.kmRemaining, 4000);
      expect(rec.status, MaintenanceStatus.ok);
    });

    test('median resists an outlier interval', () {
      final logs = [
        _log('oil_change', 0, DateTime(2024, 1, 1)),
        _log('oil_change', 5000, DateTime(2024, 4, 1)),
        _log('oil_change', 10000, DateTime(2024, 7, 1)),
        _log('oil_change', 40000, DateTime(2025, 1, 1)), // forgot for a long time
      ];
      final rec = _build(km: 40100, logs: logs).single;
      expect(rec.intervalKm, 5000);
    });

    test('marks overdue by km using the owner own interval', () {
      final logs = [
        _log('oil_change', 10000, DateTime(2024, 6, 1)),
        _log('oil_change', 15000, DateTime(2025, 4, 1)),
      ];
      final rec = _build(km: 21000, logs: logs).single;

      expect(rec.intervalKm, 5000);
      expect(rec.kmRemaining, -1000);
      expect(rec.status, MaintenanceStatus.overdue);
      expect(rec.isOverdue, isTrue);
      expect(rec.estimatedDueDate, _now);
    });

    test('marks overdue by days even if km are fine', () {
      final logs = [
        _log('coolant', 10000, DateTime(2024, 1, 1)),
        _log('coolant', 30000, DateTime(2024, 2, 1)), // 31 days
      ];
      final rec = _build(km: 30100, logs: logs).single;

      expect(rec.intervalDays, 31);
      expect(rec.daysSinceService, greaterThan(31));
      expect(rec.status, MaintenanceStatus.overdue);
    });

    test('marks soon when close to the end of the own interval', () {
      final logs = [
        _log('oil_change', 10000, DateTime(2024, 6, 1)),
        _log('oil_change', 15000, DateTime(2025, 4, 1)),
      ];
      // 4500 km since last -> 500 left of 5000 (10%): soon.
      final rec = _build(km: 19500, logs: logs).single;
      expect(rec.status, MaintenanceStatus.soon);
      expect(rec.isSoon, isTrue);
    });

    test('projects due date with real km/day, whichever comes first', () {
      final logs = [
        _log('oil_change', 10000, DateTime(2025, 1, 1)),
        _log('oil_change', 15000, DateTime(2025, 5, 1)), // 120 days
      ];
      // 1000 km since service; 4000 left; 40 km/day -> 100 days by km.
      // days since = 31 -> 89 days left by time. Time comes first.
      var rec = _build(km: 16000, logs: logs, kmPerDay: 40).single;
      expect(rec.daysRemaining, 89);
      expect(rec.estimatedDueDate, _now.add(const Duration(days: 89)));

      // 200 km/day -> 20 days by km: km comes first.
      rec = _build(km: 16000, logs: logs, kmPerDay: 200).single;
      expect(rec.estimatedDueDate, _now.add(const Duration(days: 20)));
    });

    test('without km/day the estimate falls back to the day interval', () {
      final logs = [
        _log('oil_change', 10000, DateTime(2025, 1, 1)),
        _log('oil_change', 15000, DateTime(2025, 5, 1)),
      ];
      final rec = _build(km: 16000, logs: logs).single;
      expect(rec.estimatedDueDate, _now.add(Duration(days: rec.daysRemaining!)));
    });

    test('same-day or non-advancing records are not enough history', () {
      final logs = [
        _log('oil_change', 10000, DateTime(2025, 5, 1)),
        _log('oil_change', 10000, DateTime(2025, 5, 1)),
      ];
      final rec = _build(km: 10500, logs: logs).single;

      expect(rec.recordCount, 2);
      expect(rec.status, MaintenanceStatus.needsHistory);
      expect(rec.hasInterval, isFalse);
    });

    test('uses only the available dimension when the other has no delta', () {
      // Same day (no day delta) but km advanced.
      final logs = [
        _log('air_filter', 10000, DateTime(2025, 5, 1)),
        _log('air_filter', 15000, DateTime(2025, 5, 1)),
      ];
      final rec = _build(km: 16000, logs: logs).single;

      expect(rec.intervalKm, 5000);
      expect(rec.intervalDays, isNull);
      expect(rec.daysRemaining, isNull);
      expect(rec.status, MaintenanceStatus.ok);
      expect(rec.progress, closeTo(0.2, 1e-9));
    });

    test('sorts overdue first, needs-history last', () {
      final logs = [
        _log('air_filter', 10000, DateTime(2025, 5, 1)), // needs history
        _log('oil_change', 10000, DateTime(2025, 1, 1)),
        _log('oil_change', 15000, DateTime(2025, 3, 1)),
        _log('coolant', 10000, DateTime(2024, 1, 1)),
        _log('coolant', 40000, DateTime(2024, 6, 1)),
      ];
      final recs = _build(km: 21000, logs: logs);

      expect(recs.last.serviceType, 'air_filter');
      expect(recs.first.status, MaintenanceStatus.overdue);
    });

    test('statusLabel is exposed for every status', () {
      final labels = [
        for (final s in MaintenanceStatus.values)
          MaintenanceRecommendation(
            serviceType: 't',
            title: 't',
            status: s,
            recordCount: 1,
            lastServiceKm: 0,
            lastServiceDate: _now,
            kmSinceService: 0,
            daysSinceService: 0,
          ).statusLabel,
      ];
      expect(labels.toSet().length, MaintenanceStatus.values.length);
    });
  });
}
