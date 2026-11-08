import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/models/maintenance_log.dart';
import 'package:new_my_car_app/models/mileage_reading.dart';
import 'package:new_my_car_app/services/usage_analytics.dart';

MileageReading _reading(double km, DateTime date) => MileageReading(
  userId: 'u1',
  carId: 'c1',
  odometerKm: km,
  readingDate: date,
);

MaintenanceLog _log(double km, DateTime date) => MaintenanceLog(
  userId: 'u1',
  carId: 'c1',
  serviceType: 'oil_change',
  odometerKm: km,
  serviceDate: date,
);

CarTransaction _fuel(
  DateTime date, {
  double? km,
  double? liters,
  double amount = 100000,
}) => CarTransaction(
  userId: 'u1',
  carId: 'c1',
  type: TransactionType.expense,
  category: TransactionCategory.fuel,
  description: 'Gasolina',
  amount: amount,
  date: date,
  odometerKm: km,
  liters: liters,
);

CarTransaction _maint(DateTime date, {double? km, double amount = 200000}) =>
    CarTransaction(
      userId: 'u1',
      carId: 'c1',
      type: TransactionType.expense,
      category: TransactionCategory.maintenance,
      description: 'Taller',
      amount: amount,
      date: date,
      odometerKm: km,
    );

void main() {
  group('collectOdometerPoints', () {
    test('merges readings, logs and fuel/maintenance transactions by date', () {
      final points = UsageAnalytics.collectOdometerPoints(
        readings: [_reading(10000, DateTime(2025, 1, 1))],
        maintenanceLogs: [_log(10500, DateTime(2025, 1, 20))],
        transactions: [
          _fuel(DateTime(2025, 1, 10), km: 10200, liters: 30),
          _maint(DateTime(2025, 2, 1), km: 10800),
        ],
      );

      expect(points.map((p) => p.km), [10000, 10200, 10500, 10800]);
    });

    test('ignores income, other category and transactions without odometer', () {
      final points = UsageAnalytics.collectOdometerPoints(
        readings: const [],
        maintenanceLogs: const [],
        transactions: [
          _fuel(DateTime(2025, 1, 10)),
          CarTransaction(
            userId: 'u1',
            carId: 'c1',
            description: 'Uber',
            amount: 50,
            date: DateTime(2025, 1, 11),
            odometerKm: 9999,
          ),
          CarTransaction(
            userId: 'u1',
            carId: 'c1',
            type: TransactionType.expense,
            category: TransactionCategory.other,
            description: 'Peaje',
            amount: 5,
            date: DateTime(2025, 1, 12),
            odometerKm: 8888,
          ),
        ],
      );

      expect(points, isEmpty);
    });

    test('drops values that go backwards but keeps equal ones', () {
      final points = UsageAnalytics.collectOdometerPoints(
        readings: [
          _reading(1000, DateTime(2025, 1, 1)),
          _reading(900, DateTime(2025, 1, 5)), // typo
          _reading(1000, DateTime(2025, 1, 10)),
          _reading(1100, DateTime(2025, 1, 20)),
        ],
        maintenanceLogs: const [],
        transactions: const [],
      );

      expect(points.map((p) => p.km), [1000, 1000, 1100]);
    });
  });

  group('averageKmPerDay', () {
    test('uses the real span between first and last odometer data', () {
      final points = UsageAnalytics.collectOdometerPoints(
        readings: [
          _reading(10000, DateTime(2025, 1, 1)),
          _reading(11000, DateTime(2025, 1, 31)),
        ],
        maintenanceLogs: const [],
        transactions: const [],
      );

      expect(UsageAnalytics.averageKmPerDay(points), closeTo(1000 / 30, 1e-9));
    });

    test('is null with fewer than 2 points', () {
      expect(UsageAnalytics.averageKmPerDay(const []), isNull);
      expect(
        UsageAnalytics.averageKmPerDay([OdometerPoint(DateTime(2025), 10)]),
        isNull,
      );
    });

    test('is null when the span is too short to be reliable', () {
      final points = [
        OdometerPoint(DateTime(2025, 1, 1), 100),
        OdometerPoint(DateTime(2025, 1, 4), 400),
      ];
      expect(UsageAnalytics.averageKmPerDay(points), isNull);
    });

    test('is null when the car did not move', () {
      final points = [
        OdometerPoint(DateTime(2025, 1, 1), 100),
        OdometerPoint(DateTime(2025, 3, 1), 100),
      ];
      expect(UsageAnalytics.averageKmPerDay(points), isNull);
    });
  });

  group('fuelEfficiency', () {
    test('divides km between consecutive fills by liters of the later fill', () {
      final result = UsageAnalytics.fuelEfficiency([
        _fuel(DateTime(2025, 1, 1), km: 10000, liters: 40),
        _fuel(DateTime(2025, 1, 10), km: 10400, liters: 40), // 400 km / 40 L
        _fuel(DateTime(2025, 1, 20), km: 10700, liters: 20), // 300 km / 20 L
      ]);

      expect(result, isNotNull);
      expect(result!.samples, 2);
      expect(result.totalKm, 700);
      expect(result.totalLiters, 60);
      expect(result.kmPerLiter, closeTo(700 / 60, 1e-9));
    });

    test('is null with a single fill or without odometer/liters', () {
      expect(
        UsageAnalytics.fuelEfficiency([
          _fuel(DateTime(2025, 1, 1), km: 10000, liters: 40),
        ]),
        isNull,
      );
      expect(
        UsageAnalytics.fuelEfficiency([
          _fuel(DateTime(2025, 1, 1), km: 10000),
          _fuel(DateTime(2025, 1, 10), liters: 30),
          _fuel(DateTime(2025, 1, 12), km: 10400),
        ]),
        isNull,
      );
    });

    test('ignores pairs where the odometer does not advance', () {
      final result = UsageAnalytics.fuelEfficiency([
        _fuel(DateTime(2025, 1, 1), km: 10000, liters: 40),
        _fuel(DateTime(2025, 1, 2), km: 10000, liters: 5),
        _fuel(DateTime(2025, 1, 10), km: 10300, liters: 30),
      ]);

      expect(result!.samples, 1);
      expect(result.kmPerLiter, closeTo(300 / 30, 1e-9));
    });
  });

  group('costPerKm', () {
    test('divides fuel+maintenance spent after first data by km driven', () {
      final readings = [
        _reading(10000, DateTime(2025, 1, 1)),
        _reading(11000, DateTime(2025, 2, 1)),
      ];
      final transactions = [
        _fuel(DateTime(2025, 1, 1), amount: 999999), // before span start
        _fuel(DateTime(2025, 1, 10), amount: 100000),
        _maint(DateTime(2025, 1, 20), amount: 200000),
        _fuel(DateTime(2025, 3, 1), amount: 999999), // after span end
      ];
      final points = UsageAnalytics.collectOdometerPoints(
        readings: readings,
        maintenanceLogs: const [],
        transactions: const [],
      );

      expect(
        UsageAnalytics.costPerKm(transactions: transactions, points: points),
        closeTo(300000 / 1000, 1e-9),
      );
    });

    test('is null without km driven or without expenses', () {
      expect(
        UsageAnalytics.costPerKm(
          transactions: [_fuel(DateTime(2025, 1, 10))],
          points: [OdometerPoint(DateTime(2025, 1, 1), 100)],
        ),
        isNull,
      );
      expect(
        UsageAnalytics.costPerKm(
          transactions: const [],
          points: [
            OdometerPoint(DateTime(2025, 1, 1), 100),
            OdometerPoint(DateTime(2025, 2, 1), 200),
          ],
        ),
        isNull,
      );
    });
  });

  group('averageMaintenanceCost', () {
    test('averages maintenance expenses only', () {
      final avg = UsageAnalytics.averageMaintenanceCost([
        _maint(DateTime(2025, 1, 1), amount: 100000),
        _maint(DateTime(2025, 2, 1), amount: 300000),
        _fuel(DateTime(2025, 2, 2), amount: 999999),
      ]);
      expect(avg, 200000);
    });

    test('is null with no maintenance expenses', () {
      expect(
        UsageAnalytics.averageMaintenanceCost([_fuel(DateTime(2025, 1, 1))]),
        isNull,
      );
    });
  });

  group('compute', () {
    test('returns empty-ish insights without data', () {
      final insights = UsageAnalytics.compute(
        readings: const [],
        maintenanceLogs: const [],
        transactions: const [],
      );
      expect(insights.hasAnyData, isFalse);
      expect(insights.currentOdometerKm, isNull);
      expect(insights.kmPerMonth, isNull);
    });

    test('combines everything', () {
      final insights = UsageAnalytics.compute(
        readings: [
          _reading(10000, DateTime(2025, 1, 1)),
          _reading(10600, DateTime(2025, 1, 31)),
        ],
        maintenanceLogs: const [],
        transactions: [
          _fuel(DateTime(2025, 1, 10), km: 10200, liters: 30),
          _fuel(DateTime(2025, 1, 25), km: 10500, liters: 30),
          _maint(DateTime(2025, 1, 20), amount: 150000),
        ],
      );

      expect(insights.currentOdometerKm, 10600);
      expect(insights.kmPerDay, closeTo(20, 1e-9));
      expect(insights.kmPerMonth, closeTo(600, 1e-9));
      expect(insights.fuelEfficiency!.kmPerLiter, closeTo(10, 1e-9));
      expect(insights.maintenanceCount, 1);
      expect(insights.averageMaintenanceCost, 150000);
      expect(insights.costPerKm, closeTo((100000 * 2 + 150000) / 600, 1e-9));
      expect(insights.hasAnyData, isTrue);
    });
  });
}
